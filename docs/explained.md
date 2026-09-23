# ACME Payroll — Explained From Zero

> This document assumes you know **nothing** about this project. By the end you should be
> able to explain every file, every decision, and every number in it — as if you built it
> yourself. It is written to be read top-to-bottom, like a tutorial.

---

## 1. What is this project?

**In one sentence:** A web application for the HR team of a fictional company ("ACME") to
manage the salaries of its **10,000 employees across India and the US**, replacing a
spreadsheet mess — and to answer questions like *"how does the org pay people?"*.

**Where did it come from?** It was built as a take-home **technical assessment** for
Incubyte. The assessment asked us to:
- build a full salary-management web app (backend + UI),
- seed it with 10,000 employees,
- write a requirements document first,
- use AI tools but keep engineering judgment,
- commit incrementally so reviewers can see how the solution evolved,
- deploy it, and produce artifacts (diagrams, trade-offs, performance notes).

So everything you see — the `docs/` folder, the commit history, the ADR-style decision
log — exists because **the process is part of the deliverable**, not just the code.

**The people judging this will read our thinking.** That's why there are documents
explaining *why* we chose monolith-over-microservices, a string-over-a-table, etc.

---

## 2. The tech stack (and why each choice)

| Layer | Choice | Why |
|---|---|---|
| Backend framework | **Ruby on Rails 8** (API mode) | The role is a Rails backend developer; Rails is the strongest default for CRUD + reporting |
| Database | **SQLite** | Relational, zero setup — no database server to run (see ADR-012) |
| Frontend | **React + TypeScript** (Vite) | The assessment asked for React; TypeScript keeps the frontend type-safe even though our strength is backend |
| Charts | **Recharts** | Simple React chart library |
| Testing | **RSpec + FactoryBot + shoulda-matchers + Capybara** | The Rails testing standard |
| Data seeding | **Faker** (deterministic) | Realistic fake names/job titles |
| Deployment | **Render** | One-click Rails hosting; SQLite file on a mounted disk |

**Why Rails `--api` mode?** API mode strips out views, helpers, and Turbo. Our React app
does all the rendering; Rails only returns JSON. But API mode still serves static files —
which is exactly how Rails ends up serving the compiled React app in production (one
origin, no CORS).

---

## 3. How to run it (so you can follow along)

```bash
# backend
bundle install
bin/rails db:create db:migrate
bin/rails db:seed                 # ~7s, creates 10,000 employees
bin/rails server                  # http://localhost:3000

# tests
bin/rspec

# frontend (only if you want dev-mode with hot reload)
cd frontend && npm install && npm run dev   # http://localhost:5173
```

If the frontend is *built* (`cd frontend && npm run build`), the compiled app lands in
`public/` and **Rails serves it at localhost:3000** — that's the single-origin setup.

---

## 4. The directory map (read this like a treasure map)

```
acme_payroll/
├── Gemfile                 Ruby dependencies
├── render.yaml             Render deploy blueprint (infra-as-code)
├── README.md               quick start
├── config/
│   ├── routes.rb           THE router — every URL -> controller mapping
│   └── database.yml        SQLite connection config
├── db/
│   ├── migrate/            schema migrations (how the DB is built)
│   ├── schema.rb           current DB schema (generated)
│   └── seeds.rb            entry point that calls the seed service
├── app/
│   ├── models/
│   │   ├── employee.rb         business rules for a person
│   │   └── salary_record.rb    business rules for one salary entry
│   ├── controllers/
│   │   └── api/v1/             the HTTP layer (thin!)
│   ├── serializers/api/v1/     shapes JSON for the frontend
│   └── services/
│       ├── payroll_stats.rb         dashboard math (SQL-heavy)
│       └── seed/database_populator.rb  creates 10k employees
├── frontend/
│   └── src/
│       ├── api/        TypeScript types + fetch wrappers
│       ├── pages/      Dashboard, Employees list, Detail, Form
│       └── App.tsx     routing + navigation
├── spec/                ALL tests (models, services, requests, system)
└── docs/                the "thinking" artifacts (requirements, ADRs, etc.)
```

The key mental model for the backend:
**URL → Route → Controller → Model/Service → Serializer → JSON → React.**

---

## 5. The request flow — trace one click through the whole stack

Let's trace what happens when you type "priya" in the search box and hit Search.

1. **React** (`frontend/src/pages/EmployeesPage.tsx`) builds a URL:
   `/api/v1/employees?q=priya&page=1&per_page=20` and calls `fetch`.
2. **Vite dev** proxies `/api` to `localhost:3000`. In production there's no proxy — the
   browser hits Rails directly.
3. **Rails router** (`config/routes.rb`) matches `GET /api/v1/employees` →
   `Api::V1::EmployeesController#index`.
4. The **controller** (`employees_controller.rb`) asks the `Employee` model:
   `Employee.includes(:salary_records).search("priya").order(:name)`, adds pagination,
   counts the total, and passes the 20 results to the serializer.
5. The **serializer** turns each `Employee` into the exact JSON shape the frontend expects
   (including `current_salary`, computed by picking the latest `salary_record`).
6. **Rails** returns `{ "data": [...20 employees...], "meta": { page, total_count, ... } }`.
7. **React** stores it in state and re-renders the table.

Every feature follows this same 7-step loop. Get comfortable walking any of them.

---

## 6. The data model — two tables, and why that's a feature

### `employees`
One row per person:
`name, email (unique), job_title, department, country, currency, hire_date, status`.

`status` is `active` or `terminated`. `currency` is an ISO 4217 code like `USD`/`INR`.

### `salary_records`
One row per *salary payment arrangement over time* — this is the history:

`employee_id, amount, currency, frequency, effective_date`.

**The big idea:** salary is a **timeline, not a single number**. When someone gets a raise,
we *insert a new record* with a new `effective_date`. We never overwrite the old one.
This lets us answer "what was the org paying in 2023?" and "what did this person earn
before their raise?".

**"Current salary"** is not stored — it's derived: the record with the latest
`effective_date`. See `Employee#current_salary` and the `SalaryRecord.current` scope.

### Why only two tables? (interview favorite)

- **`department` is a plain string, not a table.** We have zero department metadata
  (no budget, no manager). An indexed string filters and groups instantly at 10k rows.
  A `departments` table would add a join for nothing. If we ever need department
  attributes, the migration is trivial.
- **`currency` lives on both tables** (denormalized on the salary record) so that a
  historical record is self-contained even if the employee's country/currency changed.

---

## 7. Salary math — the two rules everything obeys

### Rule 1: annualize everything for comparison (`ANNUALIZED_SQL`)

Countries pay differently: US pays an **annual** salary, India pays **monthly**, some
jobs are **hourly**. You cannot average a monthly INR salary against an annual USD salary
without a common unit. So we define one SQL expression in `app/models/salary_record.rb`:

```sql
CASE salary_records.frequency
  WHEN 'annual'  THEN salary_records.amount
  WHEN 'monthly' THEN salary_records.amount * 12
  WHEN 'hourly'  THEN salary_records.amount * 2080   -- 40h/wk * 52wk
END
```

Every single report (payroll totals, averages, medians, histograms, top earners) uses
**this same expression**. One source of truth, provably consistent.

### Rule 2: never mix currencies (ADR-004)

There is **no exchange-rate conversion** in this app. Why? Because inventing a static FX
rate produces numbers that are *confidently wrong*, and calling a live FX API adds an
external dependency to a demo for no product value. So every aggregation is grouped **by
currency** — and the UI has a currency selector. The honest answer to "what's the average
salary?" is "which currency do you mean?"

---

## 8. The seed — how 10,000 employees appear in ~7 seconds

`app/services/seed/database_populator.rb`. Open it — it's ~150 lines and worth reading.

1. **Deterministic** — `Random.new(12_345)` is the seed for all randomness (including
   Faker). Run it twice, same data. That's why our specs can assert exact numbers and why
   your demo is reproducible.
2. **Realistic** — a `COUNTRY_CONFIG` hash maps each country to its currency, its
   pay convention, and a sensible local-currency salary range. So India gets `INR` in
   lakhs, Japan gets `JPY` in millions, US gets `USD` in tens of thousands.
3. **Salary history** — each employee gets 1–3 records; the latest record is the current
   salary and earlier ones are ~65%→85%→100% of it. History always grows.
4. **Fast** — uses `insert_all` (bulk insert) in batches of 1,000, not 10,000
   individual `create!` calls. Measured: **1.2s for employees + 2.5s for salary records**.
5. **A safety guard** — it refuses to run if `employees` already has rows. (We discovered
   Rails' `insert_all` *silently skips* rows that violate a unique constraint instead of
   erroring — so a second seed would have quietly corrupted history. The guard prevents it.)

Run it with `bin/rails db:seed` or watch timings with `bin/rails seed:benchmark`.

---

## 9. The API — the full contract

All endpoints live under `/api/v1` (versioned, so future breaking changes don't affect
existing clients).

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

**List endpoint behavior** (the most-used one):
- **Pagination**: `page` (default 1) and `per_page` (default 20, capped at 100).
  Response includes `meta: { page, per_page, total_count, total_pages }`. We never dump
  10k rows at once.
- **Search** (`q`): case-insensitive substring match on name or email.
- **Filters**: exact match on `department`, `country`, `status`, combinable.
- **No N+1**: the controller does `Employee.includes(:salary_records)` so one page of 20
  employees costs ~2 SQL queries, not 21. There's even a **spec that asserts the query
  count** so this can't regress silently.

**JSON shape** (from `app/serializers/api/v1/employee_serializer.rb`):
```json
{
  "id": 1,
  "name": "...",
  "email": "...",
  "department": "Engineering",
  "country": "US",
  "currency": "USD",
  "status": "active",
  "hire_date": "2019-04-01",
  "current_salary": { "amount": "120000.0", "currency": "USD",
                      "frequency": "annual", "annualized_amount": "120000.0" }
}
```
The detail endpoint adds a `salary_history` array (newest first).

**Errors**: validation failures → HTTP 422 with `{ "errors": { "email": "has already been
taken" } }`. Missing records → 404. These are what the React form turns into red text.

---

## 10. The dashboard — "how the org pays people" (`PayrollStats`)

`app/services/payroll_stats.rb` is the product's brain. It returns six stat groups,
computed over the **current salary of every employee**:

| Stat | What it answers | How it's computed |
|---|---|---|
| `headcount` | How many people, active vs terminated | 3 indexed `COUNT`s |
| `payroll` | Total annual + monthly pay, per currency | `SUM(annualized)` grouped by currency |
| `by_department` | Avg & median salary per dept (per currency) | average + median in Ruby |
| `by_country` | Avg & median salary per country | same |
| `distribution` | How salaries are spread (histogram) | 10 equal bands bucketed in Ruby |
| `top_earners` | Top 10 highest-paid, per currency | sort per currency, take 10 |

Three things to be able to say out loud:

1. **"We report the median, not just the mean."** Mean is skewed by a few top earners;
   median is the honest "typical salary". We show both.
2. **"We fetch the current salaries once and compute every stat from that."** The only
   query is the "latest salary per employee" window query; everything else is arithmetic
   over that result set. That's why 10k rows aggregate in **~52ms of service time**.
3. **"Everything is live."** No precomputed/cached totals to go stale. What the dashboard
   shows is exactly what's in the database — which is what the tests assert.

### The clever query: "latest record per employee"

The hardest part is "each employee's current salary". A portable window function does it
in one shot — exactly one row per employee, even when effective dates tie:
```sql
SELECT ... FROM (
  SELECT salary_records.*,
         ROW_NUMBER() OVER (
           PARTITION BY employee_id
           ORDER BY effective_date DESC, id DESC
         ) AS row_num
  FROM salary_records
) WHERE row_num = 1
```
`row_num = 1` keeps only the newest record per person. (On PostgreSQL the same result came
from `DISTINCT ON (employee_id)`, but `ROW_NUMBER` is portable to SQLite — see ADR-012.)

---

## 11. The frontend — React, deliberately kept simple

The whole SPA is 4 screens + a nav bar:

- **`/` Dashboard** — stat cards + charts. A currency selector drives all the
  per-currency charts (because of Rule 2 above).
- **`/employees`** — searchable/filterable/paginated table + CSV download.
- **`/employees/:id`** — profile + salary history + "record a salary change" form.
- **`/employees/new` and `/employees/:id/edit`** — create/edit form.

Architecture choices to defend:
- **No state library (no Redux).** "Server state is fetched per page; there's no
  client-side domain that needs a global store." One `api/client.ts` wraps `fetch`; pages
  call it and hold local state.
- **Types mirror the API** (`src/api/types.ts`). If the backend changes a field, the
  frontend won't compile until it's updated — the contract is enforced by TypeScript.
- **Recharts is lazy-loaded** — the dashboard chunk (~390 kB) is fetched only when you
  open it, keeping the initial bundle at ~84 kB gzipped.

### "Record a salary change" — the money feature

On the employee detail page you type an amount and hit Save. That `POST`s a new
`salary_record`. The old records are untouched — so the detail page now shows **two**
history rows, and the new one becomes the current salary. The dashboard's next load
reflects it. This is salary management done right: nothing is ever overwritten.

---

## 12. Testing — 67 specs, ~2 seconds

```
spec/
├── models/    validations + current_salary + annualized_amount
├── services/  PayrollStats math with EXACT expected numbers; seed behavior
├── requests/  every endpoint: success + error + pagination + filters + N+1 guard
└── system/    one Capybara test through the real SPA + API + DB
```

The rules we followed (all stated in the assessment):
- **Fast** — the whole suite runs in ~2 seconds.
- **Deterministic** — no network, no huge seeds in tests; tiny fixtures with known values.
- **Meaningful** — the `PayrollStats` spec asserts *exact numbers* (e.g. USD payroll =
  `160_000.0`), so a wrong formula fails loudly.

**One true story the tests tell (ADR-011):** our very first `POST /employees` test failed
with `ArgumentError: wrong number of arguments (given 2, expected 1)`. Root cause: Bundler
had resolved **json 3.0.2**, whose `JSON.parse` was rewritten to accept only one argument —
breaking Rails' JSON body parser for **every** request in the app. One line in the Gemfile
(`gem "json", "~> 2.9"`) fixed the entire app. The test caught an environment-level bug
*before* it reached production. This is exactly why we write tests first.

---

## 13. Performance — every number is measured, not guessed

Documented in `docs/performance.md`:

| Operation | Target | Actual |
|---|---|---|
| Employee list (search/filter/paginate) | < 100 ms | single-digit ms |
| Dashboard summary over 10k employees | < 300 ms | **~230 ms** |
| Seed 10k employees + 24k salary records | < 30 s | **~7 s** |
| Full test suite | < 60 s | **~4 s** |
| CSV export of all 10k employees | — | ~590 kB |

The levers: **indexes** on every filter/sort column; **`includes`** to avoid N+1;
a **single window query** for current salaries; **`insert_all`** bulk seeding;
**lazy-loaded** charts on the frontend.

What we deliberately did **not** add (and can defend): no Redis/memcached (230 ms doesn't
need caching), no background jobs (the seed is ~7 s), no Elasticsearch (`LIKE` is plenty
at 10k rows).

---

## 14. The decisions — an ADR-style log (`docs/decisions.md`)

The file that will get you the most interview credit. Each entry is
**context → decision → trade-off**. The highlights:

| ADR | Decision | One-line justification |
|---|---|---|
| 001 | Monolith, not microservices | No service boundary to buy here; one mental model |
| 002 | `department` is a string, not a table | No department metadata; string + index is instant |
| 003 | Salary stored as history | Raises are new records; the past stays answerable |
| 004 | No FX conversion; report per currency | Fake rates are confidently wrong; no external dep |
| 005 | Store amount + frequency; derive annualized | Ground truth in; comparisons derived at read time |
| 006 | Stats in a service object, SQL-only | Testable, one place, no row loading |
| 007 | No authentication | Single HR-manager persona; documented future work |
| 008 | React kept minimal (no Redux) | No client-side domain worth a global store |
| 009 | Derived values never stored | No stale aggregates; reports provably live |
| 010 | One deploy unit (Rails serves SPA) | No CORS, one health check |
| 011 | Pin `json` gem below 3.0 | Spec caught a gem incompatibility that broke all JSON |

---

## 15. What's deliberately OUT of scope (and why)

From `docs/requirements.md` — you must be able to say these without hesitation:

- **Auth / roles** — the persona is a single HR Manager; auth is a full security surface
  with zero demo value. Documented as the first thing we'd add for real.
- **Payroll processing** (payslips, taxes, provident fund, bank transfers) — that's a
  *different product*. We manage *salary records*, we don't run payroll.
- **Currency conversion** — ADR-004.
- **Notifications, document uploads, org charts, employee self-service.**

The pattern: **every exclusion has a reason**, and nothing is excluded by accident.

---

## 16. Deployment — how it goes live

- `render.yaml` describes the whole thing: a Ruby web service with a mounted disk holding
  the SQLite file.
- Build step runs `npm ci && npm run build` in `frontend/` (compiling the SPA into Rails'
  `public/`), then `bundle install`.
- Start command: `bin/rails server`. Health check: `/api/v1/health`.
- **One manual step** after deploy: run `bin/rails db:seed` once in the Render shell.
- Production config comes from ENV: `SECRET_KEY_BASE` (Render generates it) and
  `DATABASE_PATH`. There is no credentials file — this API app uses no cookies or sessions.
- The production config reads the database path from the `DATABASE_PATH` env var (pointing
  at the mounted disk), so the SQLite file survives deploys.

The local production smoke test already passed: booting with `RAILS_ENV=production` against
a production database, seeding 10k employees, and hitting `/api/v1/health`, `/`, and
`/api/v1/summary` all returned 200.

---

## 17. The elevator pitch (30 seconds)

> "We replaced a spreadsheet-based salary system with a web app for an HR manager. Rails 8
> serves both a JSON API and a React SPA from one deployable unit on Render, backed by
> SQLite. The data model is deliberately just two tables — employees and an effective-dated
> salary history — so current salary is always the latest record and nothing is ever
> overwritten. Every report on the dashboard is computed over annualized, per-currency
> (INR and USD) amounts: payroll totals, average and median by department and country, a
> salary distribution histogram, and top earners per currency. It's seeded deterministically
> with 10,000 realistic employees in about seven seconds, the full dashboard responds in
> about 230 milliseconds, and 67 fast, deterministic specs cover the models, the stats math,
> every endpoint, and one end-to-end system test. The requirements document, architecture
> diagram, and an ADR-style decision log explain every trade-off, including what we
> deliberately left out: authentication, payroll processing, and currency conversion."

Read that out loud until it's yours. Then read the files it references — every claim
above is backed by real code in this repo.