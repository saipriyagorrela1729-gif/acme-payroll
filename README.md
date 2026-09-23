# ACME Payroll

Web-based salary management for ACME's HR team — 10,000 employees across India and
the US. Replace the spreadsheets; answer "how does the org pay people".

Rails 8 + SQLite backend, React + TypeScript SPA, RSpec-tested. Built as an
Incubyte technical assessment.

## The thinking behind it lives in `docs/`

| File | Purpose |
|---|---|
| `docs/requirements.md` | One-page requirements (goal, scope, out-of-scope, assumptions) |
| `docs/architecture.md` | System design + rationale (see also `architecture.png`) |
| `docs/decisions.md` | ADR-style decision log — why every choice was made |
| `docs/ai-workflow.md` | How AI tools were used, and how their output was reviewed |
| `docs/performance.md` | Indexing, SQL aggregation, measured seed + dashboard timings |

## Tech stack

- **Backend:** Ruby on Rails 8 (API + serves the SPA), SQLite
- **Frontend:** React + TypeScript + Vite, Recharts (dashboard), react-router
- **Testing:** RSpec + FactoryBot + shoulda-matchers (+ Capybara system spec)
- **Deploy:** Render — one unit: Rails serves the compiled SPA from `public/`

## Local setup

```bash
# 1. Backend (Ruby 3.4, SQLite — no database server needed)
bundle install
bin/rails db:create db:migrate

# 2. Seed 10,000 employees + salary history (~3.5s)
bin/rails db:seed                  # or: bin/rails seed:benchmark

# 3. Tests (67 examples, all fast & deterministic)
bin/rspec

# 4. Backend server
bin/rails server                   # http://localhost:3000

# 5. Frontend (optional, dev mode with HMR)
cd frontend && npm install && npm run dev   # http://localhost:5173 → proxies /api to :3000
```

> The system spec (`spec/system`) requires the SPA to be built: `cd frontend && npm run build`.

## Production build (one deployable unit)

```bash
cd frontend && npm ci && npm run build   # outputs to ../public/
cd .. && bin/rails server
```

## API overview

```
GET   /api/v1/employees?page=&per_page=&q=&department=&country=&status=
POST  /api/v1/employees
GET   /api/v1/employees/:id
PATCH /api/v1/employees/:id
DELETE /api/v1/employees/:id
POST  /api/v1/employees/:id/salary_records
GET   /api/v1/employees/export.csv
GET   /api/v1/departments
GET   /api/v1/countries
GET   /api/v1/summary
GET   /api/v1/health
```

## Deployment (Render)

The repo includes a `render.yaml` blueprint. Steps:

1. Push this repo to GitHub (commits already tell the evolution story).
2. In Render: **New → Blueprint** and point at the repo (or create the resources manually).
3. Set env var `RAILS_MASTER_KEY` to the contents of `config/master.key`.
4. After first deploy, seed once from the Render shell:
   ```bash
   bin/rails db:seed
   ```
5. Open the service URL. Health check: `/api/v1/health`.

**SQLite note:** the database is a file, so the blueprint mounts a persistent disk at
`/var/data` and sets `DATABASE_PATH=/var/data/production.sqlite3`. Without a disk the
database would be wiped on every deploy.

## Demo

Deployed at: _(add Render URL after deploy)_
Demo video: _(add link — walk the dashboard, search/filter, open an employee, record a salary change, export CSV)_