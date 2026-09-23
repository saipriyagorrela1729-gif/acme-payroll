# Assessment Submission Checklist

Every expectation in the brief, and exactly where this repo satisfies it.

## Deliverables

| Requirement | Where |
|---|---|
| One-page requirements doc, written before building | [`docs/requirements.md`](requirements.md) (committed in the **first** commit) |
| Backend (Rails) end-to-end | `app/` — models, controllers, services, serializers |
| UI (React) end-to-end | `frontend/src/` — dashboard, employee list, detail, forms |
| Relational database | SQLite (portable SQL; see ADR-012) |
| Seed script with 10,000 employees | `app/services/seed/database_populator.rb`, `db/seeds.rb`, `bin/rails seed:benchmark` |
| Fully functional deployed software | https://acme-payroll.onrender.com/ (also `docs/deploy-oracle.md`) |
| Video demo | _(add link — script in `docs/demo-script.md`)_ |

## Code quality & tests

| Requirement | Where |
|---|---|
| Meaningful unit tests covering core functionality | `spec/models`, `spec/services`, `spec/requests` (67 examples) |
| Tests fast & deterministic | full suite ~4s; no network, tiny fixtures |
| Tests validate behavior, not implementation | e.g. `spec/services/payroll_stats_spec.rb` asserts exact business numbers |
| Good structure / readability / maintainability | thin controllers, service object, serializers, ADR log |
| Incremental commits showing evolution | `git log` — docs → scaffold → models → seed → API → analytics → CSV → SPA → tests → deploy |

## Artifacts

| Artifact | Where |
|---|---|
| Requirements document | `docs/requirements.md` |
| Planning / design notes | `docs/architecture.md`, `docs/decisions.md` (12 ADRs) |
| Architecture diagram | `docs/architecture.png` (+ editable `docs/architecture.excalidraw`) |
| Prompts / instructions used with AI | `docs/ai-workflow.md` + README "AI usage" section |
| Trade-off explanations | `docs/decisions.md` (context → decision → trade-off) |
| Performance considerations | `docs/performance.md` (measured) |

## Product thinking

| Signal | Where |
|---|---|
| Scope cut deliberately, with reasons | `docs/requirements.md` "Out of scope" + ADR-007 (no auth) |
| Median over mean; per-currency reporting | `PayrollStats`, ADR-004 |
| Salary history (not overwrite) | ADR-003 |
| One-click CSV export (they came from Excel) | `GET /api/v1/employees/export.csv` |
| Loading states for a deployed/slow network | `frontend/src/components/Spinner.tsx` |

## Intentional AI use

| Requirement | Where |
|---|---|
| Transparent AI usage | README "AI usage", `docs/ai-workflow.md` |
| AI accelerates, human decides | ADRs record every architectural decision; prompt template documented |
| Reviewed output, not blind trust | `docs/ai-workflow.md` review checklist + the two bugs TDD caught |
