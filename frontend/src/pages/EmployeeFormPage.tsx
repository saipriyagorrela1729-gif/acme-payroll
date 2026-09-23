import { useEffect, useState, type FormEvent } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api } from '../api/client'
import type { EmployeePayload } from '../api/types'

const CURRENCIES = ['INR', 'USD']
const COUNTRIES = ['IN', 'US']
const DEPARTMENTS = [
  'Engineering', 'Product', 'Sales', 'Finance', 'Legal', 'Operations',
  'Marketing', 'Design', 'Customer Support', 'HR',
]

export default function EmployeeFormPage() {
  const { id } = useParams<{ id: string }>()
  const editing = Boolean(id)
  const navigate = useNavigate()

  const [form, setForm] = useState<EmployeePayload>({
    name: '',
    email: '',
    job_title: '',
    department: '',
    country: 'IN',
    currency: 'INR',
    hire_date: new Date().toISOString().slice(0, 10),
    status: 'active',
  })
  const [error, setError] = useState('')

  useEffect(() => {
    if (!id) return
    api.getEmployee(Number(id)).then((r) => {
      const e = r.employee
      setForm({
        name: e.name,
        email: e.email,
        job_title: e.job_title,
        department: e.department,
        country: e.country,
        currency: e.currency,
        hire_date: e.hire_date,
        status: e.status,
      })
    }).catch((err: Error) => setError(err.message))
  }, [id])

  const set = (key: keyof EmployeePayload, value: string) => setForm((f) => ({ ...f, [key]: value }))

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')
    try {
      const result = editing
        ? await api.updateEmployee(Number(id), form)
        : await api.createEmployee(form)
      navigate(`/employees/${result.employee.id}`)
    } catch (err) {
      setError((err as Error).message)
    }
  }

  return (
    <>
      <div className="page-header">
        <h1>{editing ? 'Edit employee' : 'New employee'}</h1>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <form className="form-grid" onSubmit={submit}>
        <label>
          Name
          <input value={form.name} onChange={(e) => set('name', e.target.value)} required />
        </label>
        <label>
          Email
          <input type="email" value={form.email} onChange={(e) => set('email', e.target.value)} required />
        </label>
        <label>
          Job title
          <input value={form.job_title} onChange={(e) => set('job_title', e.target.value)} required />
        </label>
        <label>
          Department
          <select value={form.department} onChange={(e) => set('department', e.target.value)} required>
            <option value="">Select…</option>
            {DEPARTMENTS.map((d) => <option key={d} value={d}>{d}</option>)}
          </select>
        </label>
        <label>
          Country
          <select value={form.country} onChange={(e) => { set('country', e.target.value); set('currency', countryCurrency(e.target.value)) }} required>
            {COUNTRIES.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </label>
        <label>
          Currency
          <select value={form.currency} onChange={(e) => set('currency', e.target.value)} required>
            {CURRENCIES.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </label>
        <label>
          Hire date
          <input type="date" value={form.hire_date} onChange={(e) => set('hire_date', e.target.value)} required />
        </label>
        <label>
          Status
          <select value={form.status} onChange={(e) => set('status', e.target.value)}>
            <option value="active">Active</option>
            <option value="terminated">Terminated</option>
          </select>
        </label>
        <div className="full">
          <button className="btn" type="submit">{editing ? 'Save changes' : 'Create employee'}</button>
        </div>
      </form>
    </>
  )
}

const COUNTRY_CURRENCY: Record<string, string> = {
  IN: 'INR',
  US: 'USD',
}

function countryCurrency(country: string): string {
  return COUNTRY_CURRENCY[country] ?? 'INR'
}