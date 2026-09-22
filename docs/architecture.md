# Architecture

## 1. System overview

A **single Ruby on Rails 8 monolith** that exposes a JSON API and **serves the compiled
React + TypeScript single-page application** from its `public/` directory. One repository,
one deployable unit. PostgreSQL is the only datastore.

```
                         Browser (HR Manager)
                                │
                                ▼
              ┌────────────────────────────────────────────┐
              │  Rails 8 (single deploy unit on Render)    │
              │                                            │
              │  ┌────────────────┐   ┌─────────────────┐  │
              │  │  React SPA      │   │  Rails API       │  │
              │  │  (Vite + TS)    │   │  /api/v1/*  JSON │  │
              │  │  prod build →   │   │  Controllers     │  │
              │  │  public/        │   │  Service: PayrollStats │
              │  └────────────────┘   └────────┬────────┘  │
              │                                 │          │
              │  ┌──────────────────────────────▼────────┐ │
              │  │  PostgreSQL 16                        │ │
              │  │  employees, salary_records            │ │
              │  └───────────────────────────────────────┘ │
              └────────────────────────────────────────────┘
```

- **Dev:** Vite dev server proxies `/api/*` to the Rails server (port 3000) for HMR.
- **Prod:** `npm run build` compiles React into `public/`, served by Rails. One origin, no CORS.

## 2. Why this shape

- **Monolith, not microservices**: a single HR domain at 10k rows has no service-boundary
  complexity worth paying for. One codebase = one mental model, trivial to deploy.
- **Rails serves the SPA**: one origin in production avoids CORS, static hosting, and
  multi-deploy coordination. Keep-it-simple; the SPA/API split stays clean for dev.
- **No background jobs, queues, or cache layers**: nothing in this workload (10k rows,
  single user, SQL aggregations) is slow enough to justify them. YAGNI.

## 3. Backend layers (Rails)

```
routes            → /api/v1/* REST routes
controllers       → thin; params → service/model → JSON
models            → Employee, SalaryRecord (validations, associations, scopes)
services          → PayrollStats (SQL aggregation for the dashboard)
serializers       → JSON::Serializer style presenters for API responses
seeds/rake        → seeds 10k employees + salary history (insert_all)
specs             → RSpec: model + request + service + system
```

Rule: **controllers stay thin**, derived metrics live in a **service object** (testable in
isolation), models enforce invariants.

## 4. Frontend layers (React + TypeScript)

```
src/
  api/        → fetch wrappers + TypeScript types (Employee, SalaryRecord, Summary)
  pages/      → Dashboard, EmployeesList, EmployeeDetail, EmployeeForm
  components/ → Pagination, Filters, SalaryHistory, StatCard, Charts
  router      → react-router-dom
```

Plain `fetch` + hooks. **No Redux/state library** — server state is fetched per page.
Charts via **Recharts**. Styling via a small component library (kept minimal).

## 5. Data flow (example: salary change)

1. HR opens employee detail, fills "new salary" form.
2. React `POST /api/v1/employees/:id/salary_records` with `{amount, currency, frequency, effective_date}`.
3. Controller validates → creates `SalaryRecord` (previous records untouched).
4. Response returns the new record; UI re-fetches the employee's salary history.
5. The dashboard's next request reflects the change (SQL aggregation over the same table).

No write-through cache — reports always read live data. This keeps reporting **provably
consistent** with the records, which is what the tests assert.

## 6. Deployment (Render)

- Web service: Rails (Puma). Build command runs `npm ci && npm run build` before Rails boots.
- Managed PostgreSQL instance (free tier).
- `GET /api/v1/health` is the health check.
- Seed run once via a release/console task after first deploy.