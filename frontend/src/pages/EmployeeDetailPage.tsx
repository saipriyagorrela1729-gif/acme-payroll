import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '../api/client'
import type { Employee, SalaryRecordPayload } from '../api/types'
import { formatDate, formatMoney } from '../lib/format'
import Spinner from '../components/Spinner'
import SalaryBreakdown from '../components/SalaryBreakdown'

export default function EmployeeDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [employee, setEmployee] = useState<Employee | null>(null)
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const [deleting, setDeleting] = useState(false)

  // Add-salary form
  const [amount, setAmount] = useState('')
  const [frequency, setFrequency] = useState<'annual' | 'monthly' | 'hourly'>('annual')
  const [effectiveDate, setEffectiveDate] = useState(new Date().toISOString().slice(0, 10))
  const [formError, setFormError] = useState('')

  const load = () => {
    api
      .getEmployee(Number(id))
      .then((r) => {
        setEmployee(r.employee)
        setAmount(r.employee.current_salary?.amount ?? '')
        setFrequency((r.employee.current_salary?.frequency as SalaryRecordPayload['frequency']) ?? 'annual')
      })
      .catch((e: Error) => setError(e.message))
  }

  useEffect(load, [id])

  const addSalary = async (e: FormEvent) => {
    e.preventDefault()
    setFormError('')
    setSaving(true)
    try {
      await api.createSalaryRecord(Number(id), {
        amount,
        currency: employee!.currency,
        frequency,
        effective_date: effectiveDate,
      })
      setAmount('')
      load()
    } catch (err) {
      setFormError((err as Error).message)
    } finally {
      setSaving(false)
    }
  }

  const remove = async () => {
    if (!window.confirm(`Delete ${employee?.name} and their salary history?`)) return
    setDeleting(true)
    try {
      await api.deleteEmployee(employee!.id)
      navigate('/employees')
    } catch (err) {
      setError((err as Error).message)
      setDeleting(false)
    }
  }

  if (error) return <div className="error-banner">{error}</div>
  if (!employee) return <Spinner label="Loading employee…" />

  const history = employee.salary_history ?? []

  return (
    <>
      <div className="page-header">
        <h1>{employee.name}</h1>
        <div>
          <Link className="btn secondary" to="/employees">
            ← Back
          </Link>{' '}
          <Link className="btn secondary" to={`/employees/${employee.id}/edit`}>
            Edit
          </Link>{' '}
          <button className="btn danger" onClick={remove} disabled={deleting}>
            {deleting ? 'Deleting…' : 'Delete'}
          </button>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 20 }}>
        <table>
          <tbody>
            <tr><th style={{ width: 180 }}>Email</th><td>{employee.email}</td></tr>
            <tr><th>Job title</th><td>{employee.job_title}</td></tr>
            <tr><th>Department</th><td>{employee.department}</td></tr>
            <tr><th>Country / currency</th><td>{employee.country} · {employee.currency}</td></tr>
            <tr><th>Hire date</th><td>{formatDate(employee.hire_date)}</td></tr>
            <tr><th>Status</th><td><span className={`badge ${employee.status}`}>{employee.status}</span></td></tr>
            <tr>
              <th>Current salary</th>
              <td>
                {employee.current_salary
                  ? `${formatMoney(employee.current_salary.amount, employee.current_salary.currency)} / ${employee.current_salary.frequency}`
                  : '—'}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      {employee.current_salary && (
        <div className="card" style={{ marginBottom: 20 }}>
          <h2>Current salary breakdown ({employee.currency})</h2>
          <SalaryBreakdown record={employee.current_salary} onSaved={load} />
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        <div className="card">
          <h2>Salary history</h2>
          <table>
            <thead>
              <tr><th>Effective date</th><th>Amount</th><th>Frequency</th></tr>
            </thead>
            <tbody>
              {history.map((record) => (
                <tr key={record.id}>
                  <td>{formatDate(record.effective_date)}</td>
                  <td>{formatMoney(record.amount, record.currency)}</td>
                  <td>{record.frequency}</td>
                </tr>
              ))}
              {history.length === 0 && (
                <tr><td colSpan={3} className="muted">No salary records yet.</td></tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="card">
          <h2>Add a salary revision</h2>
          <p className="muted">
            Creates a new effective-dated record (e.g. a raise) and carries the current
            breakdown over, scaled to the new amount. The previous record stays in history.
          </p>
          {formError && <div className="error-banner">{formError}</div>}
          <form className="form-grid" onSubmit={addSalary}>
            <label>
              Amount ({employee.currency})
              <input type="number" step="0.01" min="0" value={amount} onChange={(e) => setAmount(e.target.value)} required />
            </label>
            <label>
              Frequency
              <select value={frequency} onChange={(e) => setFrequency(e.target.value as SalaryRecordPayload['frequency'])}>
                <option value="annual">Annual</option>
                <option value="monthly">Monthly</option>
                <option value="hourly">Hourly</option>
              </select>
            </label>
            <label className="full">
              Effective date
              <input type="date" value={effectiveDate} onChange={(e) => setEffectiveDate(e.target.value)} required />
            </label>
            <div className="full">
              <button className="btn" type="submit" disabled={saving}>
                {saving ? 'Saving…' : 'Save salary'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  )
}