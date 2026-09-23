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

## Deployment

SQLite is a file, so production needs a host with a **persistent disk**. The recommended
free option is an **Oracle Cloud Always Free VM** running Docker Compose (Rails + Caddy +
SQLite volume). Full step-by-step runbook: **[`docs/deploy-oracle.md`](docs/deploy-oracle.md)**.

```bash
# on the VM, after cloning the repo
cp .env.example .env          # set SECRET_KEY_BASE and DOMAIN
docker compose up -d --build
docker compose exec app bin/rails db:seed
```

A `render.yaml` blueprint is also included as an alternative, but Render persistent disks
require a paid instance (~$7/mo); its free tier has an ephemeral filesystem, which wipes a
SQLite database on every deploy.

## Demo

Deployed at: _(add the URL after deploy)_
Demo video: _(add link — walk the dashboard, search/filter, open an employee, record a salary change, export CSV)_