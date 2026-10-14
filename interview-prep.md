# Incubyte Round 1 — Prep (Software Craftsperson ROR)

## Mindset
This is a craft conversation + pairing, not an algorithms gauntlet. They assess:
1) can you explain your own work, 2) fundamentals via your projects, 3) do you think
test-first and take feedback, 4) are you honest and curious. Narration > perfection.

---

## A. Your 2-minute answer to "tell me about yourself"
"I'm a backend-focused engineer with ~3 years on Rails. At Imaginnovate/FleetEnable I built
billing, dispatch and order-management for multi-warehouse logistics — Stripe webhooks,
Sidekiq jobs, PDF invoices, and I did performance work (took p99 query latency from 1.2s to
480ms) and fixed a tricky production timezone bug. I work TDD with RSpec and use AI
tools deliberately to move faster without skipping tests. Recently I built and deployed a
salary-management app end-to-end to sharpen my craft — Rails API + React/TS, SQLite, TDD."

Then STOP. Let them drive.

---

## B. The salary app — be ready to explain (they WILL open it)

**Architecture:** one Rails 8 app serves the JSON API **and** the compiled React/TS SPA
(one origin, no CORS). SQLite. Four tables: `employees`, `salary_records` (effective-dated
history), `salary_components` (CTC breakdown), `users` (HR login).

**Why those decisions (ADRs in docs/decisions.md):**
- Salary as history, not a column → nothing is overwritten; "current" = latest record.
- Per-currency reporting, no FX → honest numbers (ADR-004).
- Median over mean → a few top earners skew the average (PayrollStats).
- CTC breakdown keyed by **currency** (country-appropriate), gross = sum(earnings),
  net = gross − deductions; new revision **carries the breakdown over, scaled**.
- Token auth (bcrypt) over cookies → API mode, stateless, easy to test.

**TDD story:** every backend feature is red→green in the commit history; 89 specs, ~99%
coverage; specs assert exact business numbers; an N+1 query-count guard.

**Two bugs TDD caught (great story):** a missing `presence` validation, and a `json 3.0`
gem incompatibility that broke Rails' JSON body parsing for *every* request.

---

## C. Resume cross-questions (your résumé bullets — prepare scripted answers)

- **"1.2s → 480ms — exactly what did you do?"**
  "It was a listing endpoint with an N+1 plus a missing index. I used `EXPLAIN ANALYZE`
  and the query log to confirm a sequential scan and repeated association loads. I added a
  composite index matching the filter + sort, eager-loaded the associations with
  `includes`, selected only needed columns, and paginated. I measured p99 before/after and
  kept the numbers."
- **"N+1 — how do you detect it?"** logs/Bullet, or count queries in a spec (I have a spec
  that asserts the query count).
- **"Stripe webhooks — what matters?"** verify the signature; **idempotency** (store event
  id, skip duplicates — Stripe retries); process **async** (Sidekiq), return 200 fast;
  order by event timestamp.
- **"Sidekiq queue?"** **Redis.** Retries, idempotent jobs, avoid heavy work in the request.
- **"Timezone bug?"** store/compute in **UTC**, convert at the boundary; reproduce with a
  fixed zone; add a regression test; add monitoring so it can't silently recur.
- **"Service objects vs concerns?"** services = multi-step domain logic (billing);
  concerns = shared model behavior. SRP.

---

## D. Fundamentals rapid-fire (expected)

- **Indexing:** B-tree; clustered (physical order, one per table) vs non-clustered;
  composite (left-to-right); covering index; when an index *won't* help (low selectivity,
  `LIKE '%x'`, functions on the column).
- **N+1:** 1 query for parents + N for children → fix with `includes`/`preload`.
- **Polymorphic association:** `belongs_to :commentable, polymorphic: true` — one
  association to multiple models; explain with an example (e.g., Comment on Post/Photo).
- **REST vs GraphQL:** be able to **defend REST** (caching, HTTP semantics, simplicity,
  tooling) and acknowledge GraphQL's wins (fetch exactly what you need, one round-trip).
- **Clean code / SOLID:** small, intention-revealing methods/classes; SRP; depend on
  abstractions. Give a concrete example from your work.
- **Slow page (30s):** isolate the layer — network/DNS, frontend render, API time, DB time.
  Then `EXPLAIN`, indexes, N+1, caching, async. "2s vs 26s" → 2s is tuning, 26s usually a
  missing index / external call / full scan.
- **Production bug process:** reproduce → root-cause → fix → **regression test** → monitor.
- **DBMS:** normalization (1NF/2NF/3NF), joins (inner/left), group by/having,
  transactions & locks.
- **Light DSA:** frequency count (hash map), find missing element (sum/n XOR), top-k.

---

## E. The live task — add a feature to YOUR app, test-first

Do EXACTLY this, narrating:
1. "Let me write a failing test first." (red — run it, show it fails)
2. "Now the minimal code to pass." (green)
3. "I'll refactor." (keep it clean)
4. Micro-commit. Repeat.

**Features they might ask + your plan:**
- **Avg salary by department (per currency):** reuse `PayrollStats.grouped` / an endpoint.
- **Filter by salary range:** a scope + index; add a request spec.
- **"Salary as of a date":** use the effective-dated model — pick the latest record ≤ date.
- **Add a currency/country:** extend `COUNTRY_CONFIG` + `COMPONENT_CONFIG`, add a spec.
- **Add a reason to a salary revision:** migration + validation + serializer + UI.
- **Sort/paginate something:** reuse the existing pattern.

If you get stuck, say what you'd do and ask a clarifying question — that scores.

---

## F. Pairing behavior
- Driver: type promptly, **talk out loud**, take direction gracefully.
- Navigator: ask "what if we…", suggest, don't grab the keyboard.
- Use **IDE shortcuts**; debug with the debugger/`EXPLAIN`, not just `puts`.
- Admit gaps honestly: "I haven't used that, here's how I'd approach it."

## G. Red flags to avoid
Copy-pasting · unprepared project · no tests · bulk commits · video off · evasive answers ·
can't admit unfamiliarity · no questions.

## H. Setup before the call
Laptop · camera ON · good Wi-Fi · app running (`bin/rails server`, signed in) · editor +
terminal arranged · `bin/rspec` + `bin/rubocop` ready · docs/ open · water · quiet room.

## I. Questions YOU should ask them
"How does a typical day/team work?" · "How do you use AI in the SDLC?" · "What does a
first 90 days look like?" · "How do reviews/pairing happen?" (shows company research.)
