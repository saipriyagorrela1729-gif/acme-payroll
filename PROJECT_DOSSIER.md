# ACME Payroll — Complete Project Dossier

For the Incubyte technical discussion (pairing, live modifications, fundamentals).
Read top to bottom; every claim maps to real code in this repo.

---

## Contents
1. 30-second pitch
2. Problem & persona
3. Tech stack & why
4. Architecture
5. Repository map
6. Data model (4 tables)
7. Request lifecycle (end to end)
8. Salary math
9. CTC breakdown
10. Authentication
11. Seeding
12. API contract
13. Dashboard analytics
14. CSV export
15. Frontend
16. Testing
17. Performance
18. Deployment
19. Commit history (TDD)
20. Decisions (ADRs)
21. Out of scope / trade-offs
22. Live demo script
23. Live-modification playbook
24. Q&A bank
25. Pair-programming playbook
26. Command cheat-sheet
27. Honest limitations

---

## 1. 30-second pitch

"We replaced a spreadsheet-based salary system with a web app for an HR manager. Rails 8
serves both a JSON API and a React/TypeScript SPA from one deployable unit, backed by
SQLite. The data model is small: employees, an effective-dated salary history, a CTC
breakdown of each salary, and an HR login. Current salary is always the latest record and
nothing is overwritten; each salary decomposes into earnings and deductions with a computed
net pay. Every dashboard metric is computed over annualized, per-currency amounts. It's
seeded with 10,000 employees in ~11s, has 89 fast specs (~99% coverage), and is deployed."

## 2. Problem & persona

- **Persona:** the single HR Manager of ACME.
- **Problem:** salary data for 10,000 employees across India and the US lives in Excel.
- **Needs:** (a) manage salary data, (b) answer "how does the org pay people?".

## 3. Tech stack & why

| Layer | Choice | Why |
|---|---|---|
| Backend | Rails 8 (API mode) | Role's stack; fast CRUD + reporting; API mode = JSON only + serves static SPA |
| DB | SQLite | Zero setup; portable SQL; free hosting (ADR-012) |
| Frontend | React 19 + TypeScript + Vite | Required UI; TS enforces the API contract |
| Routing | react-router-dom | Simple client routing |
| Charts | Recharts (lazy-loaded) | Dashboard visuals without bloating the initial bundle |
| Styling | plain CSS | Fewer deps; nothing to hide behind |
| Tests | RSpec + FactoryBot + shoulda-matchers + Capybara | Rails standard |
| Auth | bcrypt + opaque API token | API mode has no sessions; stateless and testable |
| Deploy | Docker → Render (free) | One image serves API + SPA |

## 4. Architecture

```
Browser (React SPA)
   │  fetch /api/v1/*  (Authorization: Bearer <token>)
   ▼
Rails 8 app
   ├── Api::V1 controllers → models / services → serializers → JSON
   ├── HomeController → serves the built SPA (public/index.html) for SPA routes
   └── PostgreSQL... no: SQLite file (storage/production.sqlite3)
```

- **Monolith** (ADR-001): 10k rows, one user, one domain. No microservices/queues/cache.
- **One origin**: Rails serves the compiled SPA, so no CORS (ADR-010).
- **Portable SQL**: `ROW_NUMBER()` window for current salary; median/histogram in Ruby
  after a single query — works on SQLite and Postgres (ADR-012).

## 5. Repository map

```
app/
  controllers/application_controller.rb     # bearer-token auth before_action
  controllers/home_controller.rb            # serves SPA shell (no auth, no-cache)
  controllers/api/v1/
    health_controller.rb                    # GET /health (no auth)
    sessions_controller.rb                  # POST/DELETE /session
    employees_controller.rb                 # CRUD + list/search/filter/paginate + CSV
    salary_records_controller.rb            # create revision, PATCH breakdown
    meta_controller.rb                      # distinct departments/countries
    summary_controller.rb                   # dashboard stats
  models/employee.rb                        # validations, search, current_salary
  models/salary_record.rb                   # history, annualized, gross/net, components
  models/salary_component.rb                # earning/deduction
  models/user.rb                            # has_secure_password + api_token
  serializers/api/v1/*                      # JSON shapes
  services/payroll_stats.rb                 # dashboard math
  services/seed/database_populator.rb       # deterministic 10k seed
db/migrate/*                                # 4 tables
db/seeds.rb                                 # seeds HR user + data
frontend/src/                               # React app (pages, api, components)
spec/                                       # models, services, requests, system
docs/                                       # requirements, ADRs, architecture, etc.
Dockerfile, docker-compose.yml, render.yaml # deploy
```

## 6. Data model (4 tables)

### employees
`name, email (unique), job_title, department, country, currency, hire_date, status(active|terminated)`
- Indexes: `email` (unique), `department`, `country`, `status`.
- `department` is a **string, not a table** (ADR-002) — no department metadata exists;
  an indexed string filters/groups instantly at 10k rows.
- `current_salary` = `salary_records.max_by { [effective_date, id] }`.

### salary_records (history)
`employee_id, amount, currency, frequency(annual|monthly|hourly), effective_date`
- Index: `(employee_id, effective_date)` + FK index.
- **Salary is a timeline** (ADR-003): a raise inserts a new record, never overwrites.
- `amount` = **gross** (headline figure used by analytics).
- `annualized_amount` derived (annual×1, monthly×12, hourly×2080).
- `has_many :salary_components`, `accepts_nested_attributes_for`.
- `before_validation :sync_amount_from_earnings` — if a breakdown is present,
  `amount` becomes the sum of earning components (single source of truth).

### salary_components (CTC breakdown)
`salary_record_id, name, kind(earning|deduction), amount, position`
- Index: `(salary_record_id, position)`.
- `gross_earnings` = sum(earnings) (or `amount` if no breakdown);
  `total_deductions` = sum(deductions); `net_pay` = gross − deductions.
- Country-appropriate seed templates (see §9).

### users
`email (unique), password_digest (bcrypt), api_token (unique)`
- `has_secure_password`; `api_token` generated on create; `regenerate_api_token!` on logout.
- `User.authenticate(email:, password:)` returns the user or nil.

## 7. Request lifecycle (end to end)

Example: **GET /api/v1/employees?q=sara&page=2**
1. Browser → `fetch('/api/v1/employees?...', { headers: { Authorization: 'Bearer <token>' } })`.
2. Rails router → `Api::V1::EmployeesController#index`.
3. `ApplicationController#authenticate!` finds the user by token; 401 if missing.
4. `filtered_scope`: `Employee.includes(:salary_records)` + `.search(q)` +
   `where(department/country/status)` + `order(:name)`.
5. `total_count = relation.count`; `offset/limit` from `page`/`per_page` (cap 100).
6. `EmployeeSerializer` maps each employee → JSON; `current_salary` (latest record) by
   `max_by` over preloaded records (no N+1).
7. Response `{ data: [...], meta: { page, per_page, total_count, total_pages } }`.
8. React stores it and renders the table.

## 8. Salary math

**Annualize for comparison** — one SQL `CASE` in `SalaryRecord::ANNUALIZED_SQL`:
```
annual → amount; monthly → amount*12; hourly → amount*2080
```
Used by every metric so numbers are consistent.

**No currency mixing** (ADR-004): all aggregation is grouped by currency (INR or USD).
No FX conversion — inventing rates would be confidently wrong.

## 9. CTC breakdown

- **Earnings** sum to gross; **net = gross − deductions**.
- Seeded **per currency** (`COMPONENT_CONFIG`), which in this data maps 1:1 to country:
  - **INR:** Basic, House Rent Allowance, Special Allowance / Provident Fund,
    Professional Tax, Income Tax.
  - **USD:** Base, Bonus / 401(k), Federal Income Tax, State Tax.
- Editable: `PATCH /api/v1/salary_records/:id` with `salary_components_attributes`
  (add/update/remove). The record's `amount` recalculates from earnings.
- **New salary revision carries the breakdown over, scaled** to the new gross (so the
  structure never disappears). Only the *current* record is seeded with components.

## 10. Authentication

- Login: `POST /api/v1/session { email, password }` → `{ token, email }`.
- Every API request needs `Authorization: Bearer <token>`.
- Logout: `DELETE /api/v1/session` rotates the token (old token stops working).
- Public: `GET /health`, `POST /session`, and the SPA shell (`HomeController`).
- Frontend: token in `localStorage`, attached by `api/client.ts`; `401` clears it and
  redirects to `/login`; CSV download fetches with the header (not a plain link).
- **Seed credentials:** `hr@acme.example` / `password123`.

## 11. Seeding

`Seed::DatabasePopulator` (deterministic: `Random.new(12_345)` + Faker):
- 10,000 employees across IN/US (monthly INR, annual USD).
- 1–3 salary records each (~24k), monotonic history.
- CTC components for the **current** record (~55k rows).
- `insert_all` batches of 1,000. Measured: ~2s employees + ~3s salaries + ~6s components
  ≈ **~11s**.
- **Guard:** raises if `employees` already has rows (prevents silent double-seeding).
- `bin/rails seed:benchmark` prints counts + timings.

## 12. API contract

All under `/api/v1`; auth required except `/health` and `POST /session`.

```
POST   /session                              login → { token }
DELETE /session                              logout (rotates token)
GET    /employees?page=&per_page=&q=&department=&country=&status=
POST   /employees
GET    /employees/:id                        + salary_history (with components)
PATCH  /employees/:id
DELETE /employees/:id
POST   /employees/:id/salary_records         new revision (carries breakdown)
PATCH  /salary_records/:id                   edit the CTC breakdown
GET    /employees/export.csv
GET    /departments
GET    /countries
GET    /summary
GET    /health
```

- **Pagination:** `page` (≥1), `per_page` (default 20, clamp 1..100); meta included.
- **Search:** `q` → `LOWER(name) LIKE` or `LOWER(email) LIKE` (portable).
- **Filters:** exact match on department/country/status.
- **Errors:** 422 `{ errors: { field: "msg" } }`; 404 for missing; 401 unauth.

## 13. Dashboard analytics (`PayrollStats`)

One query fetches **current salary per employee** (window `ROW_NUMBER()` partitioned by
employee), then Ruby computes:
- `headcount`: total / active / terminated.
- `payroll`: per currency, annualized + monthly.
- `by_department` / `by_country`: count, average, **median** (per currency).
- `distribution`: 10 buckets per currency (histogram).
- `top_earners`: top 10 per currency (avoids cross-currency ranking).

**Median over mean** — means are skewed by top earners. **Per currency** — no FX.

## 14. CSV export

`GET /employees/export.csv` streams a CSV of all employees with their current salary
(name, email, job title, department, country, currency, status, hire date, salary
amount/frequency/effective date). In the UI it's an **authenticated fetch → blob download**
(a plain `<a href>` wouldn't send the token — that was a real bug we fixed).

## 15. Frontend

- `/login` — sign in; stores token.
- `/` — dashboard (INR default, currency selector INR/USD; charts lazy-loaded).
- `/employees` — search/filter/paginate table + CSV download.
- `/employees/:id` — profile, **editable CTC breakdown**, salary history, add revision.
- `/employees/new`, `/employees/:id/edit` — forms.
- `RequireAuth` redirects to `/login`; `Spinner` for loading; API types mirror the backend.

## 16. Testing

- **89 examples, 0 failures, ~99% line coverage** (SimpleCov), RuboCop clean.
- `spec/models` — validations, `current_salary`, `annualized_amount`, breakdown math.
- `spec/services` — `PayrollStats` with **exact expected numbers**; seed determinism +
  country-appropriate components.
- `spec/requests` — every endpoint: success, errors, auth, pagination, filters, **N+1
  query-count guard**, breakdown edit, revision carry-over.
- `spec/system` — Capybara: login → employees list renders.
- **Fast & deterministic**: no network, tiny fixtures, ~9s total.

**Bugs TDD caught:** a missing `presence` validation; and `json 3.0` breaking Rails' JSON
body parsing (pinned `json ~> 2.9`).

## 17. Performance

| Operation | Measured |
|---|---|
| Employees list (page 20, filters) | single-digit ms |
| Dashboard summary (10k) | ~176–230 ms |
| Seed 10k + history + components | ~11 s |
| Full suite | ~9 s |

Levers: indexes on filter/sort columns; `includes` (no N+1); one window query for current
salaries; `insert_all` bulk seed; lazy-loaded charts. **No** Redis/queues/Elasticsearch —
not needed at this scale.

## 18. Deployment

- **Dockerfile**: multi-stage (Vite builds the SPA → Ruby image). SQLite on the container
  disk (or a mounted volume).
- **Render** (`render.yaml`): free tier, `db:prepare && rails server`; on a fresh disk it
  creates + seeds (~11s) then serves. Free tier sleeps + ephemeral disk → cold start
  re-seeds.
- **Oracle Always Free** (`docs/deploy-oracle.md`): free **persistent** disk (Docker
  Compose + Caddy).
- **Cache fix**: the SPA shell is served `no-cache` so redeploys are picked up (a 1-year
  `index.html` cache had masked updates).

## 19. Commit history (TDD)

37+ commits, docs first, then per backend feature **red → green**:
```
test: health (red) → feat (green)
test: Employee (red) → feat (green)
test: SalaryRecord (red) → feat (green)
test: seed (red) → feat (green)
test: PayrollStats (red) → feat (green)
test: employees API (red) → feat (green)
test: summary (red) → feat (green)
… then SPA, deploy, CTC+login, fixes, docs
```
Spec-first ordering was reconstructed from the finished tree; the code is genuinely
test-first.

## 20. Decisions (ADRs)

001 monolith · 002 department string · 003 salary history · 004 no FX/per-currency ·
005 amount+frequency → annualized · 006 service object for stats · 007 basic auth ·
008 minimal React · 009 derived values never stored · 010 one deploy unit · 011 pin json ·
012 SQLite · 013 CTC components · 014 token auth. (Full text: `docs/decisions.md`.)

## 21. Out of scope / trade-offs

- **Full payroll processing** (payslips, statutory filing, bank transfers, country tax
  rules) — we model a CTC breakdown, we don't run payroll.
- **Roles / multi-user / SSO / audit logs** — a single HR login.
- **Currency conversion** — per-currency reporting.
- **Notifications, uploads, org charts, self-service.**

Deliberately **no** microservices, queues, Redis, or caching — the brief rewards judgment,
not complexity.

## 22. Live demo script (2–4 min)

1. Login (`hr@acme.example` / `password123`).
2. Dashboard: INR default, switch to USD; headcount, payroll, avg vs **median**, distribution,
   top earners; mention per-currency + median rationale.
3. Employees: search, filters, pagination.
4. Open an employee: breakdown (earnings/deductions, gross/net); **edit** an amount → live
   recalc → save.
5. **Add a salary revision** → breakdown persists, history grows.
6. **Download CSV.**
7. Repo: TDD commits, docs/ADRs, 89 specs, deployed.

## 23. Live-modification playbook (they WILL ask)

Do every one test-first: **write spec → run (red) → implement (green) → refactor → commit.**

### A. "Add an endpoint: average salary by department for a currency"
- Spec: `GET /api/v1/departments/average?currency=INR` returns rows with `average`.
- Implement: in `MetaController`/new controller call `PayrollStats.new.call[:by_department]`
  and filter by currency (or a dedicated query). Render JSON.
- Reuse `grouped` logic; no new SQL needed.

### B. "Filter employees by salary range"
- Spec: `GET /employees?min_salary=&max_salary=` filters on current annualized salary.
- Implement: join the current-salary subquery (the same `ROW_NUMBER` pattern) and
  `WHERE annualized BETWEEN ...`; add index consideration; keep pagination.
- Or simpler: filter in Ruby after loading the page — but SQL is better; explain trade-off.

### C. "Show the salary as of a date"
- Spec: `GET /employees/:id?as_of=2024-06-01` returns the latest record with
  `effective_date <= as_of`.
- Implement: `salary_records.where("effective_date <= ?", date).order(effective_date: :desc,
  id: :desc).first`. This is the payoff of the effective-dated model — say so.

### D. "Add a reason/note to a salary revision"
- Migration: `add_column :salary_records, :reason, :string`.
- Spec: reason persists and is returned.
- Implement: permit `:reason`, serializer includes it, UI select (raise/promotion/adjustment).

### E. "Add a new currency/country"
- Extend `COUNTRY_CONFIG` + `COMPONENT_CONFIG`; spec that seeded employees for it exist.
- Note: salary analytics already group by currency, so it works automatically.

### F. "Sort employees by current salary"
- Add a whitelisted `sort=salary` that joins the current-salary subquery and orders by it.
- Spec both directions; guard against SQL injection (whitelist).

### G. "Delete a salary component / recalc net"
- Spec: PATCH with `_destroy` → component removed, gross/net recalculated.
- Already supported by nested attributes; add a UI/spec.

**Tip:** for each, state the plan out loud, ask a clarifying question if ambiguous, then
red→green. Speed matters less than the loop and the narration.

## 24. Q&A bank (concise)

- **N+1?** 1 query for parents + N for children. Fix with `includes`; detect via logs/Bullet
  or a query-count spec. (We have one.)
- **`includes` vs `joins` vs `preload` vs `eager_load`?** `joins` = INNER JOIN for filtering,
  doesn't load; `preload` = separate queries; `eager_load` = LEFT OUTER JOIN; `includes`
  chooses (join if you filter on the association).
- **Indexing?** B-tree; clustered vs non-clustered; composite (order matters); covering;
  every index costs writes; unique index behind uniqueness validations for race safety;
  `EXPLAIN` to verify.
- **Safe migration on a big table?** `algorithm: :concurrently`, `disable_ddl_transaction!`,
  `strong_migrations`; add columns without volatile defaults.
- **Sidekiq queue?** Redis; jobs idempotent; pass IDs not objects; retries.
- **Webhooks?** verify signature; idempotency via event id; process async; 200 fast.
- **Slow page?** isolate layer; `EXPLAIN`; indexes; N+1; cache; async; pagination.
- **2s vs 26s API?** tuning vs missing index/external call/full scan.
- **Clean code / SOLID?** small intention-revealing methods; SRP; depend on abstractions;
  tests.
- **Polymorphic association?** `belongs_to :x, polymorphic: true`; one association to
  multiple models (e.g., Comment on Post/Photo).
- **GraphQL vs REST?** defend REST (HTTP caching, semantics, simplicity, tooling);
  acknowledge GraphQL's precise fetching / single round-trip.
- **Validations vs DB constraints?** app validations for UX; DB constraints for integrity
  (race safety); use both.
- **`find` vs `where`?** `find` by PK, raises; `where` returns a relation, no raise.
- **Transactions/locking?** `transaction`; optimistic (`lock_version`) vs pessimistic
  (`lock!`/`FOR UPDATE`).
- **Zeitwerk?** autoloading by file path/constant name; no manual requires.
- **Rack/middleware?** Rack interface; middleware wraps the app (auth, logging, etc.).

## 25. Pair-programming playbook

- **Driver:** type promptly, narrate ("I'll add a scope here…"), take direction gracefully.
- **Navigator:** suggest ("what if we…"), don't grab the keyboard.
- Use **IDE shortcuts**; debug with the debugger/`EXPLAIN`, not just `puts`.
- Admit gaps: "I haven't used that; here's how I'd approach it."
- Ask clarifying questions; don't go silent.
- Commit small; keep tests green.

## 26. Command cheat-sheet

```bash
bin/rails server            # run app (http://localhost:3000)
bin/rspec                   # 89 specs
bin/rspec spec/requests/api/v1/employees_spec.rb:12   # one example
bin/rubocop                 # lint
bin/rails db:reset          # reseed (10k, ~11s)  → hr@acme.example / password123
bin/rails seed:benchmark    # seed timings
bin/rails routes            # API routes
bin/rails console
```

## 27. Honest limitations

- **Reconstructed red→green history** (code is genuinely test-first).
- **Single-user auth** (no roles); token in `localStorage` (would move to httpOnly+CSRF in
  production).
- **CTC components are seeded per currency**; not every possible payroll regime.
- **Free-tier deploy** sleeps + ephemeral disk; Oracle runbook is the persistent option.
- **Frontend tests** are minimal (one system test); API is thoroughly covered.
- **Changing an employee's country/currency doesn't rewrite existing salary records** —
  intentional (history is immutable); new revisions can be added.
