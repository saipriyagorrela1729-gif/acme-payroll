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

- All summary metrics computed in **SQL** (`GROUP BY`, `percentile_cont` for medians),
  not by loading rows into Ruby. 10k rows aggregating in PostgreSQL is single-digit ms.
- **Median over mean**: mean is skewed by a few top earners; median is the honest
  "typical salary". We expose both.
- Reports always read live data — no cache invalidation bugs possible.

## 4. Seeding 10,000 employees

- Bulk insert via `ActiveRecord::InsertAll` (`insert_all`) in batches (e.g., 1,000/batch)
  instead of per-row `create!`. Expect **seconds, not minutes**.
- Deterministic RNG seed so the dataset is reproducible between runs.
- A `bin/rails seed:benchmark` task prints row counts and elapsed time, committed as
  evidence in this doc.

## 5. What we are deliberately NOT doing

- No Redis/memcached caching — aggregation is already fast; caching adds staleness risk.
- No background jobs for the seed — it completes in one request/command run.
- No Elasticsearch — SQL `ILIKE` + filters are sufficient.
- No read replicas, sharding, or partitioning.

## 6. Measured targets

| Operation | Target |
|---|---|
| Employees list (page of 20, with search/filter) | < 100ms |
| Dashboard summary on 10k employees | < 200ms |
| Seed 10k employees + salary history | < 30s |
| Full RSpec suite | < 60s |