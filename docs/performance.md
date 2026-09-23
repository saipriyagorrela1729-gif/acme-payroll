# Performance Considerations

The dataset is 10,000 employees — small. The goal is to be **correct and fast enough
without adding infrastructure**. These notes record the reasoning and the measured numbers.

## 1. Indexes (the whole list)

| Table | Column(s) | Why |
|---|---|---|
| `employees` | `email` | unique constraint + lookup |
| `employees` | `department` | filter + group-by in dashboard |
| `employees` | `country` | filter + group-by in dashboard |
| `employees` | `status` | headcount by status filter |
| `salary_records` | `employee_id` | every read of an employee's history |
| `salary_records` | `effective_date` | ordering to pick "current" salary |

A composite index on `salary_records(employee_id, effective_date)` covers the "latest
salary per employee" window query without a full sort.

## 2. List endpoints

- **Pagination** (page/per_page) is mandatory — never return 10k rows in one response.
- Search uses `LOWER(name) LIKE ?` (portable; SQLite's `LIKE` is already case-insensitive
  for ASCII, `LOWER` keeps it correct everywhere) — single-digit ms at 10k rows.
- `includes(:salary_records)` avoids N+1 when serializing the list; a request spec asserts
  the query count so it cannot regress.

## 3. Dashboard aggregation

- The **current (latest) salary per employee** is fetched in a single query using a
  portable `ROW_NUMBER() OVER (PARTITION BY employee_id ...)` window function (one row per
  employee, even when effective dates tie).
- All statistics (payroll totals, average, **median**, histogram, top earners) are then
  computed in Ruby from that one result set. SQLite has no `PERCENTILE_CONT`/`WIDTH_BUCKET`,
  so this keeps the code portable and avoids re-running the window query per metric.
- **Median over mean**: mean is skewed by a few top earners; median is the honest
  "typical salary". We expose both.
- Reports always read live data — no cache invalidation bugs possible.
- Annualized amounts use a single shared `CASE` expression (`SalaryRecord::ANNUALIZED_SQL`),
  so every metric uses the same convention.

**Measured on the 10k dataset (SQLite, development):**

| Metric | Time |
|---|---|
| Summary endpoint, warm | **~230ms** |
| `PayrollStats#call` (service only, warm) | ~52ms |

> PostgreSQL did the same work in ~176ms using `DISTINCT ON`/`PERCENTILE_CONT`/
> `WIDTH_BUCKET`; SQLite is a little slower but removes the database server entirely
> (see ADR-012). Both are comfortably interactive.

## 4. Seeding 10,000 employees

- Bulk insert via `ActiveRecord::InsertAll` (`insert_all`) in batches of 1,000 instead of
  per-row `create!`.
- Deterministic RNG seed so the dataset is reproducible between runs.
- `bin/rails seed:benchmark` prints row counts and elapsed time.
- A guard raises if the `employees` table already has rows, preventing a silent second
  seed from duplicating salary history.

**Measured (SQLite):**

| Step | Time |
|---|---|
| Insert 10,000 employees | ~2–3s |
| Insert ~24,000 salary records | ~4–5s |
| **Total** | **~7s** (target < 30s) ✓ |

## 5. What we are deliberately NOT doing

- No Redis/memcached caching — aggregation is already fast; caching adds staleness risk.
- No background jobs for the seed — it completes in one command run.
- No Elasticsearch — `LIKE` + indexed filters are sufficient at 10k rows.
- No read replicas, sharding, or partitioning.

## 6. Measured targets

| Operation | Target | Measured |
|---|---|---|
| Employees list (page of 20, with search/filter) | < 100ms | ✓ (single-digit ms, indexed) |
| Dashboard summary on 10k employees | < 300ms | ✓ ~230ms |
| Seed 10k employees + salary history | < 30s | ✓ ~7s |
| Full RSpec suite | < 60s | ✓ ~9s (67 examples, incl. coverage) |

## 7. Frontend bundle

- Initial JS bundle **~85 kB gzip** — Recharts is lazy-loaded per-route (loaded only when
  the dashboard is opened), keeping the employee screens light.
- The SPA is served by Rails from `public/` in production (single origin, no CORS).
- CSV export of all 10,000 employees: ~590 kB.
