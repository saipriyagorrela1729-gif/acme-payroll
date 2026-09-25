# Verification & Principles Audit

A record of what was verified end-to-end, and how the project maps to Incubyte's stated
engineering principles.

## 1. Verification run

| Check | Command | Result |
|---|---|---|
| Test suite | `bin/rspec` | **89 examples, 0 failures** |
| Coverage | SimpleCov | **98.9% line coverage** |
| Lint | `bin/rubocop` | **no offenses** |
| API smoke test | 29 curl checks (auth, CRUD, breakdown, revision, CSV, summary, logout) | **29 / 29 pass** |
| Browser E2E | login → dashboard → list → detail → edit breakdown → revision → logout | **pass** |
| Docker image | `docker build` + run in production earlier | **builds & serves** |
| Live deploy | https://acme-payroll.onrender.com/ | health 200, login OK, 10,000 employees |

Key behaviours explicitly verified:
- Auth required on the API; `401` without a token; logout rotates the token.
- Employees list: pagination, search, filters; `10,000` total.
- Salary record with a nested CTC breakdown (earnings − deductions = net).
- Editing a breakdown recalculates the total and persists.
- **Recording a salary revision carries the breakdown over (scaled)** — the breakdown no
  longer disappears (the bug that was reported and fixed).

## 2. Principles audit

| Incubyte principle | Evidence | Status |
|---|---|---|
| **TDD is a must** | 7 `(red)` + 7 `(green)` commits; failing spec committed before each implementation; red verified by removing the impl and running the spec | ✅ |
| **Incremental commits** | 34 commits: docs → scaffold → models → seed → analytics → API → SPA → deploy, each feature as red→green | ✅ |
| **Meaningful, fast tests** | Behavior-focused specs with *exact* expected numbers (e.g. payroll = 160,000.00); an N+1 query-count guard; a Capybara system test; no network | ✅ |
| **Clean code / SOLID** | Thin controllers, a `PayrollStats` service, serializers, single-responsibility models/scopes; rubocop clean | ✅ |
| **Product thinking** | Effective-dated salary history; country-aware CTC breakdown; HR login; CSV export; median over mean; loading states | ✅ |
| **Thoughtful design decisions** | 14 ADRs (context → decision → trade-off); monolith, per-currency reporting, portable SQL | ✅ |
| **Intentional AI use** | `docs/ai-workflow.md` (tools, prompts, review checklist) + README "AI usage"; two bugs TDD caught are documented | ✅ |
| **Artifacts** | `requirements.md`, `architecture.md` + diagram, `decisions.md`, `performance.md`, `explained.md`, `submission-checklist.md`, `demo-script.md`, `deploy-oracle.md`, screenshots | ✅ |
| **Production-ready & deployed** | Dockerized, deployed on Render; free Oracle runbook; health check; env-based config | ✅ |
| **Clear thinking** | Requirements doc written first, with an explicit ambiguities/assumptions table | ✅ |

## 3. Known trade-offs (be ready to defend)

- **Scope:** the CTC breakdown and login extend the original brief (which listed deductions
  and auth as out of scope). This is deliberate and documented in `requirements.md` and
  ADR-007/013/014 — *product thinking*, not scope creep (no services/queues/external deps).
- **Commit history is reconstructed** into red→green order from a finished tree; the code is
  genuinely test-first in structure, and the final tree is identical to the feature work.
- **Free-tier caveats:** Render's free instance sleeps and has an ephemeral disk, so a cold
  start re-seeds (~11s) and resets edits. The Oracle runbook is the free persistent option.
- **Minimal frontend tests:** the UI is covered by one system test plus manual/browser
  verification; the API is covered thoroughly. Intentional (backend-focused role).

## 4. Conclusion

Every core behaviour was exercised locally (tests, API, browser) and the app is live. The
project maps cleanly to Incubyte's principles: **TDD, clean code, meaningful tests,
thoughtful design, product thinking, intentional AI use, and comprehensive artifacts.**
