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
  - Rails 8, PostgreSQL, RSpec, FactoryBot
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

### Phase 2 — Data model (to be recorded here as I go)
- Each migration/model/factory is generated against the schema in `architecture.md`, then
  reviewed against the SQL and the `db/schema.rb` diff.

## Review checklist applied to every AI response

- [ ] Does the diff match the agreed contract (no scope creep)?
- [ ] Tests were written first and they actually assert behavior (not just "responds 200")?
- [ ] No new dependencies unless I approved them?
- [ ] Query count sane (no N+1; `includes`/aggregation used where promised)?
- [ ] Validations/edge cases from the requirements covered?
- [ ] Code style matches the rest of the repo (Ruby/Rails idioms, no unnecessary comments)?
- [ ] `bin/rspec` green, `bin/rubocop` clean before commit?