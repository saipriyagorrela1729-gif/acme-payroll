# Demo Video Script (~3–4 minutes)

Record at **https://acme-payroll.onrender.com/** (or `localhost:3000`). Keep it tight;
narrate what you're doing and *why*.

## 0. Intro (15s)
> "This is ACME Payroll — a web app that replaces the HR team's spreadsheets for 10,000
> employees. Rails 8 backend, React + TypeScript frontend, SQLite, fully TDD'd and
> deployed. Let me show the two jobs it does: managing salaries and answering how the org
> pays people."

## 1. Dashboard — "how does the org pay people?" (60s)
- Open the dashboard (defaults to **INR**; note the currency selector is INR/USD only).
- Point out: **total headcount**, **active vs terminated**, **annual + monthly payroll**.
- Scroll to the charts:
  - **Average vs median by department** — *"we show the median, not just the mean, because
    a few top earners skew the average."*
  - **Salary distribution** histogram — *"the shape of pay."*
  - **Top earners** per currency.
- Switch the currency to **USD** to show per-currency reporting — *"we never mix currencies
  or fake exchange rates."*

## 2. Manage employees (60s)
- Go to **Employees**. Show the **search** (type "sara"), **filters** (department, country,
  status), and **pagination** ("Page 1 of 500").
- Note the **loading spinner** while it fetches.
- Open one employee → show profile + **salary history**.

## 3. Record a salary change (45s)
- On the employee page, enter a new amount and **Save salary**.
- Show the **salary history** now has two rows and the **current salary** updated.
- *"Salary changes are effective-dated records — we never overwrite history."*
- Go back to the dashboard and show the totals moved.

## 4. CSV export (15s)
- Click **Download CSV** → show the file opening with the full payroll.

## 5. Code & process (45s)
- Open the GitHub repo. Point out:
  - the **incremental commit history**;
  - `docs/requirements.md`, `docs/decisions.md` (ADRs), `docs/architecture.png`;
  - the **specs** (`bin/rspec` → 67 examples, ~4s) and mention TDD;
  - `docs/ai-workflow.md` — *"here's exactly how I used AI and how I reviewed its output."*
- Close: *"Seeded with 10,000 employees, tested, and deployed — and the docs explain every
  trade-off."*

## Tips
- Do a warm-up request first so the free-tier app isn't asleep when you hit record.
- If the first load is slow, narrate: *"it's waking from sleep — the free tier spins down
  when idle."*
