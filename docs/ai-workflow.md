# AI Workflow & Prompts

This assessment requires *intentional* use of AI tools. This document records how I used
AI, what I asked it to do, and — critically — **how I reviewed its output**. AI is used to
accelerate, not to decide. Every decision in `decisions.md` was made by me.

## Principles

1. **I write the specs first.** Tests and requirements are authored/approved by me before
   code is generated. AI generates code *against* an already-decided contract.
2. **AI never makes architecture decisions.** It implements the design in
   `docs/architecture.md`. When it proposes alternatives, I evaluate and record in
   `decisions.md`.
3. **Every AI-generated change is reviewed as if written by a junior engineer**: read the
   diff, run the tests, check for hidden assumptions (e.g., silently adding a gem,
   skipping a validation, N+1 queries).
4. **Prompts are committed** so reviewers can see how I used the tool.

## Prompt template I use per feature (WHY → design → flow → code → tests)

```
You are my Ruby on Rails pairing partner. Implement the feature described below.
Do NOT make product or architecture decisions — follow the plan exactly.

Feature: <name>
Why:      <product reason>
Contract: <exact behavior — inputs, outputs, edge cases>
Files:    <which files to create/change>
Tests:    <write these specs first; they must fail before implementation (red)>
Constraints:
  - Rails 8, SQLite, RSpec, FactoryBot
  - No new gems unless listed
  - Follow existing code style in this repo
  - No comments in code unless asked
After implementing, run: bin/rspec <files> and show me the output.
```

## Prompt log

### Phase 0 — Planning
- Prompt: *"Review this Incubyte assessment. List ambiguous requirements, propose a simple
  architecture, and flag scope risks. Do not write code."*
- Review: I overrode the model's suggestion to add a `departments` table and an auth stub —
  recorded as ADR-002 and ADR-007 with my reasoning.

### Phase 2 — Data model
- Prompt: *"Write RSpec model specs for Employee and SalaryRecord per docs/architecture.md and
  docs/decisions.md. Then implement the models and migrations to make them pass."*
- Review: The spec I wrote first caught a real defect — `SalaryRecord#currency` was missing
  `presence: true`, so an empty string was accepted as long as the format regex "passed".
  Fixed in the model. This is the TDD loop working: **specs first, they drove the fix**.

### Phase 4 — API (json 3.0 incompatibility)
- Prompt: *"Implement Api::V1::EmployeesController per the request specs in
  spec/requests/api/v1/employees_spec.rb. Use thin controllers, serializers, and eager loading."*
- Review: The very first `POST` spec failed with `ArgumentError: wrong number of arguments
  (given 2, expected 1)`. Root cause: Bundler resolved **json 3.0.2**, whose `JSON.parse`
  drops the options argument — breaking `ActiveSupport::JSON.decode` and therefore **every
  JSON request body in the app**. Fixed by pinning `json ~> 2.9` (ADR-011). A request spec
  caught an environment-level breakage before it reached production.

### Phase 5 — PayrollStats
- Prompt: *"Aggregate 'current salary per employee' and summary stats in SQL only, grouped
  by currency, per the PayrollStats spec. Use a portable ROW_NUMBER window for current salary."*
- Review: Rails 8's "dangerous query method" guard rejected raw SQL strings in `pluck` —
  wrapped in `Arel.sql` (correct, since our fragments are static constants, not user input).
  Profiled each metric. Later, when the project moved to SQLite (ADR-012), the
  Postgres-only `PERCENTILE_CONT`/`WIDTH_BUCKET` were replaced with a portable `ROW_NUMBER`
  window plus Ruby math, and the summary now runs in ~52ms of service time.

### Phase 7-9 — React SPA
- Prompt: *"Build a minimal React + TS SPA (Vite) with 4 pages against the /api/v1 contract
  in src/api/types.ts. Plain fetch, no state library, Recharts on the dashboard."*
- Review: Caught that `useLocation()` was called outside a `<Router>` (missing BrowserRouter
  in main.tsx) and that `render file:` returns an empty body in API mode — switched the SPA
  fallback to `send_file`. Recharts (~500kB) is lazy-loaded so the initial bundle is 84kB gzip.

## Review checklist applied to every AI response

- [ ] Does the diff match the agreed contract (no scope creep)?
- [ ] Tests were written first and they actually assert behavior (not just "responds 200")?
- [ ] No new dependencies unless I approved them?
- [ ] Query count sane (no N+1; `includes`/aggregation used where promised)?
- [ ] Validations/edge cases from the requirements covered?
- [ ] Code style matches the rest of the repo (Ruby/Rails idioms, no unnecessary comments)?
- [ ] `bin/rspec` green, `bin/rubocop` clean before commit?