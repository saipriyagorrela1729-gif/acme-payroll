# Assessment Submission Checklist

Every expectation in the brief, and exactly where this repo satisfies it.

## Deliverables

| Requirement | Where |
|---|---|
| One-page requirements doc, written before building | [`docs/requirements.md`](requirements.md) (committed in the **first** commit) |
| Backend (Rails) end-to-end | `app/` — models, controllers, services, serializers |
| UI (React) end-to-end | `frontend/src/` — login, dashboard, employee list, detail, forms |
| Relational database | SQLite (portable SQL; see ADR-012) |
| Seed script with 10,000 employees | `app/services/seed/database_populator.rb`, `db/seeds.rb`, `bin/rails seed:benchmark` |
| Fully functional deployed software | https://acme-payroll.onrender.com/ (also `docs/deploy-oracle.md`) |
| Video demo | _(add link — script in `docs/demo-script.md`)_ |

## Features (product thinking)

| Feature | Where |
|---|---|
| Manage employees (CRUD, search, filter, paginate) | `Api::V1::EmployeesController` |
| Effective-dated salary history | `SalaryRecord`, ADR-003 |
| **CTC breakdown** (country-aware earnings/deductions, editable, net pay) | `SalaryComponent`, ADR-013 |
| **HR login** (token-protected API) | `User`, `SessionsController`, ADR-014 |
| "How the org pays" dashboard (median, distribution, top earners, per currency) | `PayrollStats`, ADR-004 |
| CSV export | `GET /api/v1/employees/export.csv` |
| Loading states for a slow/deployed network | `frontend/src/components/Spinner.tsx` |

## Code quality & tests

| Requirement | Where |
|---|---|
| Meaningful tests covering core functionality | `spec/models`, `spec/services`, `spec/requests`, `spec/system` (**89 examples, 98.9% line coverage**) |
| Tests fast & deterministic | full suite ~9s (incl. coverage); no network, tiny fixtures |
| Tests validate behavior, not implementation | e.g. `spec/services/payroll_stats_spec.rb` asserts exact business numbers |
| Good structure / readability / maintainability | thin controllers, service object, serializers, ADR log |
| Incremental commits showing evolution | `git log` — docs → scaffold → models → seed → API → analytics → SPA → deploy, with **red→green** commits per feature |

## Artifacts

| Artifact | Where |
|---|---|
| Requirements document | `docs/requirements.md` |
| Planning / design notes | `docs/architecture.md`, `docs/decisions.md` (**14 ADRs**) |
| Architecture diagram | `docs/architecture.png` (+ editable `docs/architecture.excalidraw`) |
| Prompts / instructions used with AI | `docs/ai-workflow.md` + README "AI usage" section |
| Trade-off explanations | `docs/decisions.md` (context → decision → trade-off) |
| Performance considerations | `docs/performance.md` (measured) |
| End-to-end verification + principles audit | `docs/verification.md` |
| Free deploy runbook | `docs/deploy-oracle.md` |
| Demo video script | `docs/demo-script.md` |

## Intentional AI use

| Requirement | Where |
|---|---|
| Transparent AI usage | README "AI usage", `docs/ai-workflow.md` |
| AI accelerates, human decides | ADRs record every architectural decision; prompt template documented |
| Reviewed output, not blind trust | `docs/ai-workflow.md` review checklist + the bugs TDD caught |

## Scope note (be ready to defend)

The brief listed auth and deductions as *not* explicitly required. We added a **basic HR
login** and a **country-aware CTC breakdown** as deliberate **product thinking** — both are
real HR needs, cleanly modeled and TDD'd, with no over-engineering (no microservices,
queues, or external services). See ADR-007 / ADR-013 / ADR-014.
