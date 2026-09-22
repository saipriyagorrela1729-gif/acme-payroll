# ACME Payroll

Web-based salary management for ACME's HR team — 10,000 employees across multiple
countries. Rails 8 + PostgreSQL backend, React + TypeScript SPA, RSpec-tested.

Built as an Incubyte technical assessment. The thinking behind it lives in `docs/`:

| File | Purpose |
|---|---|
| `docs/requirements.md` | One-page requirements (goal, scope, out-of-scope, assumptions) |
| `docs/architecture.md` | System design + rationale (see also `architecture.png`) |
| `docs/decisions.md` | ADR-style decision log (why each choice) |
| `docs/ai-workflow.md` | How AI tools were used, and how output was reviewed |
| `docs/performance.md` | Indexing, aggregation, seeding, measured targets |

## Tech stack

- **Backend:** Ruby on Rails 8, PostgreSQL 16
- **Frontend:** React + TypeScript + Vite, Recharts (dev via Vite proxy)
- **Testing:** RSpec + FactoryBot
- **Deploy:** Render (Rails serves the built SPA from `public/`)

## Local setup

```bash
# 1. Backend
bundle install
cp .env.example .env            # DATABASE_URL etc.
bin/rails db:create db:migrate

# 2. Seed 10,000 employees + salary history
bin/rails db:seed               # or: bin/rails seed:benchmark

# 3. Run the suite
bin/rspec

# 4. Backend server
bin/rails server                # http://localhost:3000

# 5. Frontend (separate terminal, dev mode)
cd frontend
npm install
npm run dev                     # http://localhost:5173 → proxies /api to :3000
```

## Production build (one deployable unit)

```bash
cd frontend && npm ci && npm run build   # outputs to ../public/
cd .. && bin/rails server
```

## API overview

```
GET   /api/v1/employees?page=&q=&department=&country=&status=&sort=
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

## Demo

Deployed at: _(add Render URL after deploy)_
Demo video: _(add link)_