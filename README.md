# ACME Payroll

Web-based salary management for ACME's HR team — 10,000 employees across India and the
US. Replaces the spreadsheets and answers *"how does the org pay people?"*.

Rails 8 + SQLite backend, React + TypeScript SPA, RSpec-tested. Built as an Incubyte
technical assessment.

## Live demo

- **Deployed:** https://acme-payroll.onrender.com/
- **Sign in:** `hr@acme.example` / `password123`
- **Demo video:** _(add link)_
- Health check: https://acme-payroll.onrender.com/api/v1/health

> On the free tier the app sleeps when idle, so the first request after a quiet period
> takes a few seconds to wake (and re-seed). Everything after that is fast.

## What it does

- **Manage employees** — create, view, edit, delete, search, filter (department/country/
  status), paginate.
- **Manage salaries** — record effective-dated salary changes; history is kept, and the
  current salary is always the latest record (nothing is overwritten).
- **CTC breakdown** — itemized **earnings** and **deductions**, seeded **per country**
  (India: Basic / HRA / Special Allowance + Provident Fund / Professional Tax / Income Tax;
  US: Base / Bonus + 401(k) / Federal Income Tax / State Tax). Gross = sum of earnings,
  **net = gross − deductions**. HR can edit the breakdown and the total recalculates.
- **Answer "how we pay"** — dashboard with headcount, payroll per currency, average &
  **median** by department and country, a salary distribution histogram, and top earners.
- **Export** — one-click CSV of the full payroll.
- **HR login** — email + password; the API is token-protected.

---

## How this was built (Implementation Details)

### Test-Driven Development

TDD is the backbone of this project. Every feature was developed **spec-first**: write a
failing spec (red) → implement the minimal code to pass (green) → refactor. The spec
suites mirror that:

| Spec | Covers |
|---|---|
| `spec/models/` | Validations, `current_salary`, `annualized_amount` |
| `spec/services/` | `PayrollStats` math with **exact expected numbers**; seed behavior |
| `spec/requests/` | Every endpoint: success + error + pagination + filters + an **N+1 query-count guard** |
| `spec/system/` | One Capybara test through the real SPA → API → DB |

The suite is **fast, deterministic, and behavior-focused** — **67 examples, ~99.6% line
coverage** (SimpleCov) — and specs assert *user behavior and business logic* (e.g. "USD
payroll equals 160,000.00"), not implementation details. **TDD paid off twice in this
project:**

- a model spec caught a missing `presence` validation on `SalaryRecord#currency`;
- a request spec caught that **json 3.0 breaks Rails' JSON body parsing** — a bug that
  would have taken down every write endpoint (see ADR-011).

### AI usage (tools, prompts, and how output was reviewed)

AI was used as an **accelerating pair**, never as the decision-maker. The full log lives
in [`docs/ai-workflow.md`](docs/ai-workflow.md); the essentials:

- **Tools:** an AI coding assistant (OpenCode/Claude-class) for scaffolding, specs, and
  docs; Recharts/Vite for the frontend.
- **Where AI helped:** generating boilerplate (migrations, controllers, React pages),
  drafting test cases, and producing the first pass of documentation.
- **What I decided myself:** every architectural choice — monolith vs services, the
  2-table model, per-currency reporting, no FX, no auth, the analytics approach. These are
  recorded as **ADRs in [`docs/decisions.md`](docs/decisions.md)**.
- **How I reviewed AI output:** treated it like a junior engineer's PR — read every diff,
  ran the tests, checked for hidden dependencies, N+1s, and scope creep. I rejected
  AI suggestions to add a `departments` table and an auth stub, and documented why.
- **Guardrails given to the AI:** "follow the plan; Rails 8 + SQLite + RSpec; write the
  spec first; no new gems without approval; run the tests and show the output."

### Architecture & key decisions

A single Rails 8 app serves both the JSON API **and** the compiled React SPA (one origin,
no CORS, one deploy). Two tables only — `employees` and an effective-dated
`salary_records` history. All dashboard metrics are grouped **by currency** (no fake FX),
and derived values are never stored. Rationale and trade-offs: `docs/architecture.md` and
`docs/decisions.md` (12 ADRs).

### Performance

Measured, not guessed (`docs/performance.md`): employee list single-digit ms; dashboard
summary ~230 ms over 10k employees; seed 10k in ~7s; suite ~4s. Levers: indexes on every
filter/sort column, `includes` to kill N+1, a single window query for current salaries,
and `insert_all` bulk seeding.

---

## Artifacts

| File | Purpose |
|---|---|
| `docs/requirements.md` | One-page requirements (goal, scope, out-of-scope, assumptions) |
| `docs/architecture.md` + `docs/architecture.png` | System design + diagram |
| `docs/decisions.md` | ADR-style decision log — why every choice was made |
| `docs/ai-workflow.md` | How AI tools were used, and how their output was reviewed |
| `docs/performance.md` | Indexing, aggregation, measured seed + dashboard timings |
| `docs/explained.md` | A from-zero walkthrough of the whole project |
| `docs/submission-checklist.md` | Maps each assessment expectation → where it's satisfied |
| `docs/deploy-oracle.md` | Free production deploy runbook |
| `docs/screenshots/` | Dashboard, employee list, employee detail |

## Tech stack

- **Backend:** Ruby on Rails 8 (API + serves the SPA), SQLite
- **Frontend:** React + TypeScript + Vite, Recharts (dashboard), react-router
- **Testing:** RSpec + FactoryBot + shoulda-matchers (+ Capybara system spec)
- **Deploy:** Render (Docker) / Oracle Cloud Always Free (Docker Compose)

## Local setup

```bash
# 1. Backend (Ruby 3.4, SQLite — no database server needed)
bundle install
bin/rails db:create db:migrate

# 2. Seed 10,000 employees + salary history (~7s)
bin/rails db:seed                  # or: bin/rails seed:benchmark

# 3. Tests (67 examples, 99.6% line coverage, fast & deterministic)
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
POST  /api/v1/session                        # login -> { token }
DELETE /api/v1/session                       # logout (rotates the token)
GET   /api/v1/employees?page=&per_page=&q=&department=&country=&status=
POST  /api/v1/employees
GET   /api/v1/employees/:id
PATCH /api/v1/employees/:id
DELETE /api/v1/employees/:id
POST  /api/v1/employees/:id/salary_records
PATCH /api/v1/salary_records/:id             # edit the CTC breakdown
GET   /api/v1/employees/export.csv
GET   /api/v1/departments
GET   /api/v1/countries
GET   /api/v1/summary
GET   /api/v1/health
```

All endpoints except `/health` and `POST /session` require `Authorization: Bearer <token>`.

## Deployment

The repo ships a **Dockerfile** and a **docker-compose.yml** (Rails + Caddy + a SQLite
volume), plus a `render.yaml` blueprint.

- **Free (data persists):** Oracle Cloud Always Free VM — see
  [`docs/deploy-oracle.md`](docs/deploy-oracle.md).
- **Render (free, ephemeral):** deploy the Docker image via `render.yaml`; the container's
  `db:prepare` re-creates and re-seeds the SQLite DB on boot.

```bash
# Oracle VM / any Docker host
cp .env.example .env          # set SECRET_KEY_BASE and DOMAIN
docker compose up -d --build  # first boot creates and seeds the SQLite DB automatically
```

## Commit history

The history is **incremental and TDD-ordered**: docs first, then scaffold, and for every
backend feature the **failing spec is committed first (`… (red)`)** followed by the
**implementation (`… (green)`)** — models, seed, `PayrollStats`, the employees/summary
APIs, and CSV export. After that: the React SPA, the system test, and deployment. Read
`git log --oneline` top-to-bottom to see the solution evolve.
