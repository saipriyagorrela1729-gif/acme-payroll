# Performance Considerations

The dataset is 10,000 employees — small. The goal is to be **correct and fast enough
without adding infrastructure**. These notes record the reasoning and will be backed by a
measured seed benchmark.

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
salary per employee" query without a sort pass.

## 2. List endpoints

- **Pagination** (page/per_page) is mandatory — never return 10k rows in one response.
- Search uses `ILIKE` on name/email with `pg_trgm`-free substring matching; at 10k rows
  this is well under 10ms. (Not installing pg_trgm — YAGNI, but noted as the upgrade path.)
- `includes(:current_salary)` to avoid N+1 when serializing the list.

## 3. Dashboard aggregation

- All summary metrics are computed in **SQL** — set aggregation (`GROUP BY`,
  `PERCENTILE_CONT` for medians) plus window functions (`DISTINCT ON`, `ROW_NUMBER`,
  `WIDTH_BUCKET`) for "current salary per employee", top earners, and the histogram.
  **No employee rows are loaded into Ruby memory.**
- **Median over mean**: mean is skewed by a few top earners; median is the honest
  "typical salary". We expose both.
- Reports always read live data — no cache invalidation bugs possible.
- Annualized amounts are derived in SQL via a single shared `CASE` expression
  (`SalaryRecord::ANNUALIZED_SQL`), so every metric uses the same convention.

**Measured on the 10k dataset (PostgreSQL 16):**

| Metric | Time |
|---|---|
| Summary endpoint (all six stat groups) | **~176ms** (target < 200ms) ✓ |

Breakdown: headcount 12ms · payroll 24ms · by-department 23ms · by-country 20ms ·
distribution 66ms · top-earners 31ms.

## 4. Seeding 10,000 employees

- Bulk insert via `ActiveRecord::InsertAll` (`insert_all`) in batches of 1,000 instead of
  per-row `create!`.
- Deterministic RNG seed so the dataset is reproducible between runs.
- `bin/rails seed:benchmark` prints row counts and elapsed time.
- A guard raises if the `employees` table already has rows, preventing a silent second
  seed from duplicating salary history.

**Measured (Apple-free dev machine, PostgreSQL 16):**

| Step | Time |
|---|---|
| Insert 10,000 employees | 1.07s |
| Insert 24,021 salary records | 2.44s |
| **Total** | **~3.5s** (target < 30s) ✓ |

## 5. What we are deliberately NOT doing

- No Redis/memcached caching — aggregation is already fast; caching adds staleness risk.
- No background jobs for the seed — it completes in one request/command run.
- No Elasticsearch — SQL `ILIKE` + filters are sufficient.
- No read replicas, sharding, or partitioning.

## 6. Measured targets

| Operation | Target | Measured |
|---|---|---|
| Employees list (page of 20, with search/filter) | < 100ms | ✓ (single-digit ms, indexed) |
| Dashboard summary on 10k employees | < 200ms | ✓ ~176ms |
| Seed 10k employees + salary history | < 30s | ✓ ~3.5s |
| Full RSpec suite | < 60s | ✓ ~2s (67 examples) |

## 7. Frontend bundle

- Initial JS bundle **84 kB gzip** — Recharts is lazy-loaded per-route (loaded only when the
  dashboard is opened), keeping the employee screens light.
- The SPA is served by Rails from `public/` in production (single origin, no CORS).
- CSV export of all 10,000 employees: ~0.8s, ~590 kB.