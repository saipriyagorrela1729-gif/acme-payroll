# Payroll Management System — Requirements (v1.0)

## 1. Goal

Replace ACME's spreadsheet-based salary management with a web application that lets the
HR Manager **manage salary records** for ~10,000 employees across multiple countries and
**answer questions about how the org pays people** — quickly, accurately, and in one place.

## 2. User Persona

**HR Manager.** A single user managing employee salary data day-to-day. Not a payroll
accountant; not an employee self-service user.

## 3. Scope & Features

### In scope
- **Employee management**: create, view, edit, delete, search, and filter employees
  (name, email, job title, department, country, currency, hire date, status).
- **Salary management**: record a salary per employee with amount, currency, frequency
  (annual/monthly/hourly), and effective date. Salary **history is retained** — every
  change is an effective-dated record; the current salary is the latest record.
- **Multi-country support**: employees are based in India or the US; each employee has a
  country and currency (INR or USD); salaries are stored in the employee's local currency
  and reported **per currency** (no currency conversion).
- **Reporting — "how the org pays people"**:
  - Total headcount and total monthly/annual payroll (per currency)
  - Average and **median** salary by department and by country
  - Salary distribution (banded histogram)
  - Top earners
  - Headcount by status and by country
- **CSV export**: one-click download of the current payroll for all employees.
- **Seed data**: script that creates 10,000 realistic employees with salary history.

### Out of scope (deliberately, with reasoning)
- **Authentication / authorization** — the persona is a single HR Manager; adding login,
  roles, and audit trails adds a full security surface with zero demo value. Treated as a
  documented follow-up.
- **Payroll processing** — payslips, deductions, taxes, provident fund, bank transfers.
  We manage *salary records*; we do not run payroll. This is a separate product.
- **Currency conversion / FX rates** — we report per currency rather than invent exchange
  rates. A live-FX integration is an external dependency we deliberately avoid in a demo.
- **Net vs gross calculation** — only base/gross salary is stored; tax and take-home
  computation is explicitly out of scope.
- **Notifications / emails, document uploads, org charts, employee self-service.**

## 4. Assumptions (unresolved in the brief — made explicit)

These are the choices we made where the brief was ambiguous. Each is easy to change.

| Ambiguity in brief | Our assumption | Why |
|---|---|---|
| "Answer questions about how the org pays people" | Aggregate **dashboard of statistics** (not natural-language Q&A) | Dashboard is deterministic, fast, and demos reliably; an LLM chat layer adds big scope for little value here |
| Salary frequency | Store amount **+ frequency** per record; normalize to annual for comparison | Countries use different conventions; we keep ground truth and derive comparisons |
| Multi-currency meaning | Two currencies only (INR, USD); **report per currency** | The org standardized on these two; no fake FX math |
| Salary history | Effective-dated `salary_records`; current = latest record | Tracking raises/tenure is barely more work and answers "how we pay" far better |
| Gross vs net | **Base/gross salary** | Deductions are out of scope |
| "10,000 employees" | Seed with 10k rows; UI paginates | Confirms performance approach without caching layers |

## 5. Acceptance Criteria

1. HR can create/edit/delete employees and record salary changes through the UI.
2. The employees list supports search, filter (department/country/status), sort, pagination.
3. The dashboard shows payroll totals, average & median salary by department/country,
   salary distribution, and top earners.
4. The seed script creates 10,000 employees with salary history in under ~30 seconds.
5. All report numbers are reproducible from the stored records (verified by tests).
6. The app is deployed and usable; a short demo video is recorded.
7. Core functionality is covered by fast, deterministic RSpec tests.