import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import type { Employee, EmployeeListResponse } from '../api/types'
import { formatMoney } from '../lib/format'
import Spinner from '../components/Spinner'

const PER_PAGE = 20

export default function EmployeesPage() {
  const [result, setResult] = useState<EmployeeListResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(1)
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState('')
  const [department, setDepartment] = useState('')
  const [country, setCountry] = useState('')
  const [status, setStatus] = useState('')
  const [options, setOptions] = useState<{ departments: string[]; countries: string[] }>({
    departments: [],
    countries: [],
  })
  const [error, setError] = useState('')

  useEffect(() => {
    api.departments().then((r) => setOptions((o) => ({ ...o, departments: r.departments })))
    api.countries().then((r) => setOptions((o) => ({ ...o, countries: r.countries })))
  }, [])

  useEffect(() => {
    const params = new URLSearchParams({ page: String(page), per_page: String(PER_PAGE) })
    if (search) params.set('q', search)
    if (department) params.set('department', department)
    if (country) params.set('country', country)
    if (status) params.set('status', status)

    setLoading(true)
    api
      .listEmployees(params)
      .then(setResult)
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false))
  }, [page, search, department, country, status])

  const applySearch = () => {
    setPage(1)
    setSearch(searchInput.trim())
  }

  return (
    <>
      <div className="page-header">
        <h1>Employees</h1>
        <div>
          <a className="btn secondary" href="/api/v1/employees/export.csv">
            Download CSV
          </a>{' '}
          <Link className="btn" to="/employees/new">
            + New employee
          </Link>
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="toolbar">
        <input
          type="text"
          placeholder="Search name or email"
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && applySearch()}
        />
        <button className="btn secondary" onClick={applySearch}>
          Search
        </button>
        <select value={department} onChange={(e) => { setDepartment(e.target.value); setPage(1) }}>
          <option value="">All departments</option>
          {options.departments.map((d) => <option key={d} value={d}>{d}</option>)}
        </select>
        <select value={country} onChange={(e) => { setCountry(e.target.value); setPage(1) }}>
          <option value="">All countries</option>
          {options.countries.map((c) => <option key={c} value={c}>{c}</option>)}
        </select>
        <select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1) }}>
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="terminated">Terminated</option>
        </select>
      </div>

      {loading && <Spinner label="Loading employees…" />}

      {!loading && (
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Department</th>
              <th>Country</th>
              <th>Status</th>
              <th>Current salary</th>
            </tr>
          </thead>
          <tbody>
            {result?.data.map((employee: Employee) => (
              <tr key={employee.id}>
                <td>
                  <Link to={`/employees/${employee.id}`}>{employee.name}</Link>
                </td>
                <td>{employee.email}</td>
                <td>{employee.department}</td>
                <td>{employee.country}</td>
                <td>
                  <span className={`badge ${employee.status}`}>{employee.status}</span>
                </td>
                <td>
                  {employee.current_salary
                    ? `${formatMoney(employee.current_salary.amount, employee.current_salary.currency)} / ${employee.current_salary.frequency}`
                    : '—'}
                </td>
              </tr>
            ))}
            {result && result.data.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">No employees match your filters.</td>
              </tr>
            )}
          </tbody>
        </table>
      )}

      {!loading && result && (
        <div className="pagination">
          <span className="muted">
            {result.meta.total_count.toLocaleString()} employees
          </span>
          <button disabled={page <= 1} onClick={() => setPage(page - 1)}>
            Prev
          </button>
          <span>
            Page {result.meta.page} of {result.meta.total_pages}
          </span>
          <button disabled={page >= result.meta.total_pages} onClick={() => setPage(page + 1)}>
            Next
          </button>
        </div>
      )}
    </>
  )
}