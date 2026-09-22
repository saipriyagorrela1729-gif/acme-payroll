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

**Context:** Employees across multiple countries with different currencies.

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

## ADR-007 — No authentication

**Context:** Persona is a single HR Manager; demo submission.

**Decision:** No auth. Single-user app, documented as a known limitation.

**Why:** Authentication (login, sessions, roles, CSRF) is a full security surface with zero
demo value for this persona. A real deployment would gate it behind VPN/proxy or add
`has_secure_password` + sessions.

**Trade-off:** Anyone who reaches the URL can view/edit data. Acceptable for a demo with
synthetic data.

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