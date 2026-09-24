# Design Decisions (ADR-style log)

Each decision is recorded with **context → decision → trade-off**. These are the
discussion points I expect to defend in the technical interview.

---

## ADR-001 — Monolith, not microservices

**Context:** Single HR domain, one HR-manager user, 10k rows, modest reporting needs.

**Decision:** One Rails 8 application (API + serves the built React SPA).

**Why:** There is no service-boundary complexity here to buy with microservices. A monolith
keeps one deploy unit, one codebase to reason about, and trivial local development. Queueing,
eventing, and horizontal scaling are all YAGNI at this scale.

**Trade-off:** We give up independent scaling of frontend/backend. At 10k employees that
cost is zero in practice.

---

## ADR-002 — Department is a string, not a table

**Context:** Employees belong to a department; reporting groups by it.

**Decision:** Store `department` as an indexed string column on `employees`.

**Why:** A `departments` table would add a join for zero payoff — we have no department
attributes (manager, budget, location). Grouping/filtering on an indexed string is
instant at 10k rows.

**Trade-off:** Renames/typos in department names propagate to the string. Migration path if
needed: add a `departments` table and replace the column with an FK.

---

## ADR-003 — Salary history as effective-dated records

**Context:** "Manage salary data" — raises, tenure, "how does the org pay."

**Decision:** `salary_records` table, one-to-many with `employees`. Each record has
`amount, currency, frequency, effective_date`. Current salary = latest by `effective_date`
(a scope, not a stored column).

**Why:** A single "current salary" column throws away all history and cannot answer
"what did we pay in 2024" or "median raise". History is barely more work and is the
product-correct model for salary management.

**Trade-off:** Slightly more complex reads (must pick "latest"). Mitigated by a
`current_salary` association/scope on the model.

---

## ADR-004 — Store local currency; report per currency (no FX)

**Context:** Employees in India and the US, paid in INR and USD respectively.

**Decision:** Salaries store `amount` in the employee's local `currency`. Reporting groups
by currency. Annualized amounts are computed for comparison **within** a currency only.

**Why:** Currency conversion requires exchange rates. Inventing a static table produces
numbers that are confidently wrong; a live-FX API adds an external dependency to a demo.
Per-currency reporting is honest and correct.

**Trade-off:** We cannot answer "total payroll in USD across all countries." That is a
feature we deliberately defer.

---

## ADR-005 — Store amount + frequency; normalize for reporting

**Context:** Countries use different salary conventions (annual vs monthly).

**Decision:** `salary_records.amount` is stored as-is with a `frequency`
(annual/monthly/hourly). An `annualized_amount` is **computed** in the stats service.

**Why:** Storing a pre-normalized number would destroy ground truth and go stale if rules
change. Deriving at read time keeps one source of truth.

**Trade-off:** A tiny per-read computation cost (negligible; done in SQL).

---

## ADR-006 — Controllers thin; stats in a service object

**Context:** The dashboard needs several aggregate numbers.

**Decision:** `PayrollStats` service object computes all summary metrics via SQL
aggregations; controllers delegate to it.

**Why:** Testable in isolation, no SQL leaking into controllers/views, one place to reason
about reporting. 10k rows aggregated in SQL is milliseconds — no Ruby-side row loading.

**Trade-off:** An extra layer. But it's the layer where the real product logic lives.

---

## ADR-007 — Basic HR authentication (superseded)

**Context:** Persona is a single HR Manager; the app manages real (synthetic) salary data.

**Decision (updated):** Add a **single HR login** — email + password (`has_secure_password`)
issuing a bearer token that the API requires on every request. Roles, SSO, and audit logs
remain out of scope.

**Why:** A salary system with no gate at all is hard to defend; a single-user token login
covers the persona with minimal surface. The token is rotated on logout.

**Trade-off:** No roles/multi-user permissions. Tokens live in `localStorage` on the SPA,
which is acceptable for a demo but would move to httpOnly cookies + CSRF in production.

---

## ADR-008 — React kept deliberately simple (no Redux, plain fetch)

**Context:** 4 screens, server-backed CRUD + a dashboard; my strength is backend.

**Decision:** React + TS + Vite, react-router-dom, plain `fetch` hooks, Recharts for charts.
No state-management library.

**Why:** Server state is fetched per page; there is no client-side domain worth a global
store. Fewer libraries = fewer decisions to defend and less code.

**Trade-off:** Some duplicate fetch logic across pages; a shared `api/` module mitigates it.

---

## ADR-009 — Derived values never stored

**Context:** Dashboard needs annualized amounts, medians, distributions.

**Decision:** All derived metrics are computed at request time from `salary_records`.

**Why:** Stored aggregates go stale and invite "which number is real?" confusion. At 10k
rows, SQL aggregation is fast enough that caching is unnecessary.

**Trade-off:** Slightly slower than a precomputed rollup; acceptable and provably consistent.

---

## ADR-010 — Single deploy unit (Rails serves the built SPA)

**Context:** "Fully functional deployed software."

**Decision:** Production build of the SPA lands in `public/`, served by Rails on one origin.

**Why:** No CORS, no separate static host, one health check, one place to debug.

**Trade-off:** No CDN-fronted static assets; irrelevant at this scale.

---

## ADR-011 — Pin `json` gem below 3.0 (environment incompatibility)

**Context:** The very first `POST /api/v1/employees` request spec failed with
`ArgumentError: wrong number of arguments (given 2, expected 1)`.

**Cause:** Bundler resolved **json 3.0.2**, whose `JSON.parse` was rewritten to accept only
the source string. Rails' `ActiveSupport::JSON.decode` calls `::JSON.parse(json, options)`,
so **every JSON request body in the app would have failed to parse** — the API would have
been completely broken.

**Decision:** Pin `gem "json", "~> 2.9"`.

**Why:** One line fixes the whole app; the failing spec caught it on the first request test
instead of in production. This is TDD earning its keep at the environment level.

**Trade-off:** None meaningful for this app. Revisit when Rails itself supports json 3.
---

## ADR-012 — SQLite instead of PostgreSQL

**Context:** The assessment allows "a relational database of your choice, like SQLite".
The original build used PostgreSQL to exploit `DISTINCT ON`, `PERCENTILE_CONT`,
`WIDTH_BUCKET`, and `ILIKE` for the analytics.

**Decision:** Use **SQLite**. The Postgres-only SQL was ported to portable SQL
(`ROW_NUMBER()` window functions for "latest salary per employee" and the median) and the
histogram is bucketed in Ruby. Search uses `LOWER(...) LIKE`.

**Why:** SQLite needs no database server — `bin/rails db:create` just works, and the whole
app is a single file plus a process. For 10,000 rows the performance is comparable
(~230ms for the full dashboard summary, vs ~176ms on Postgres).

**Trade-off:** We lose Postgres-specific aggregate functions (median/histogram are now
computed in Ruby), and production persistence requires a mounted disk on the host. In
exchange, local setup and deployment are dramatically simpler. The SQL is written to be
portable, so moving back to Postgres is a `database.yml` + Gemfile change.

---

## ADR-013 — CTC breakdown as components (earnings/deductions), gross stays the headline

**Context:** HR wants to see and edit how a salary is broken down (Basic, HRA, allowances,
PF, tax) and have the total reflect the edits.

**Decision:** Add a `salary_components` table (`name`, `kind` = earning/deduction, `amount`,
`position`) belonging to a `salary_record`. The record's `amount` remains the **gross**
(sum of earning components, synced on save); `net_pay = gross − deductions`.

**Why:** Keeping `amount` as gross means every existing analytic (payroll, median,
distribution) keeps working unchanged, while the breakdown adds detail. A generic
components table (rather than fixed columns) lets HR add any earning/deduction without a
migration.

**Trade-off:** Editing an earning changes the record's total (intended). Deductions don't
affect analytics (which use gross) — documented and deliberate.

---

## ADR-014 — Token auth over session cookies for an API + SPA

**Context:** The app is an API-only Rails app serving a React SPA from the same origin.

**Decision:** Email/password login returns an opaque `api_token`; the SPA stores it and
sends `Authorization: Bearer <token>`. Logout rotates the token.

**Why:** API mode has no session middleware by default; token auth is stateless, trivial to
test in request specs, and needs no CSRF plumbing.

**Trade-off:** `localStorage` is vulnerable to XSS; a production build would prefer
httpOnly cookies + CSRF or short-lived JWTs with refresh.
