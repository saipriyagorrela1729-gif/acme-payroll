import { useEffect, useMemo, useState } from 'react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { api } from '../api/client'
import type { PayrollSummary } from '../api/types'
import { formatBand, formatCompact, formatMoney, formatNumber } from '../lib/format'

const PIE_COLORS = ['#6d28d9', '#f43f5e']
const BAR_COLORS = ['#6d28d9', '#c084fc']
// The org pays in two currencies; INR is the default view.
const SUPPORTED_CURRENCIES = ['INR', 'USD']

export default function DashboardPage() {
  const [summary, setSummary] = useState<PayrollSummary | null>(null)
  const [currency, setCurrency] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    api.summary().then((r) => {
      setSummary(r.summary)
      const available = SUPPORTED_CURRENCIES.filter((c) => r.summary.payroll[c])
      setCurrency(available[0] ?? '')
    }).catch((e: Error) => setError(e.message))
  }, [])

  const headcountData = useMemo(() => {
    if (!summary) return []
    return [
      { name: 'Active', value: summary.headcount.active },
      { name: 'Terminated', value: summary.headcount.terminated },
    ]
  }, [summary])

  const departmentData = useMemo(
    () =>
      (summary?.by_department ?? [])
        .filter((row) => row.currency === currency)
        .map((row) => ({ name: row.name, Average: row.average, Median: row.median })),
    [summary, currency],
  )

  const distributionData = useMemo(() => (summary?.distribution[currency] ?? []), [summary, currency])

  const topEarners = useMemo(() => (summary?.top_earners[currency] ?? []), [summary, currency])

  if (error) return <div className="error-banner">{error}</div>
  if (!summary) return <p className="muted">Loading…</p>

  return (
    <>
      <div className="page-header">
        <h1>How ACME pays people</h1>
        <select value={currency} onChange={(e) => setCurrency(e.target.value)}>
          {SUPPORTED_CURRENCIES.filter((c) => summary.payroll[c]).map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
      </div>

      <div className="stat-cards">
        <div className="stat-card">
          <div className="label">Total employees</div>
          <div className="value">{formatNumber(summary.headcount.total)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Active</div>
          <div className="value">{formatNumber(summary.headcount.active)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Terminated</div>
          <div className="value">{formatNumber(summary.headcount.terminated)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Annual payroll ({currency})</div>
          <div className="value">{formatMoney(summary.payroll[currency]?.annualized, currency)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Monthly payroll ({currency})</div>
          <div className="value">{formatMoney(summary.payroll[currency]?.monthly, currency)}</div>
        </div>
      </div>

      <div className="charts">
        <div className="card">
          <h2>Headcount</h2>
          <ResponsiveContainer width="100%" height={260}>
            <PieChart>
              <Pie data={headcountData} dataKey="value" nameKey="name" innerRadius={50} outerRadius={90}>
                {headcountData.map((_, i) => <Cell key={i} fill={PIE_COLORS[i]} />)}
              </Pie>
              <Legend />
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        <div className="card">
          <h2>Average vs median salary by department ({currency})</h2>
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={departmentData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" angle={-25} textAnchor="end" interval={0} height={70} tick={{ fontSize: 11 }} />
              <YAxis tickFormatter={(v) => formatCompact(v as number)} width={55} tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v) => formatNumber(v as number)} />
              <Legend />
              <Bar dataKey="Average" fill={BAR_COLORS[0]} radius={[4, 4, 0, 0]} />
              <Bar dataKey="Median" fill={BAR_COLORS[1]} radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="card">
          <h2>Salary distribution ({currency})</h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={distributionData} layout="vertical" margin={{ left: 8, right: 16 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis type="number" allowDecimals={false} tick={{ fontSize: 12 }} />
              <YAxis
                type="category"
                dataKey="label"
                tickFormatter={formatBand}
                width={95}
                tick={{ fontSize: 11 }}
              />
              <Tooltip formatter={(v) => formatNumber(v as number)} />
              <Bar dataKey="count" fill="#6d28d9" radius={[0, 4, 4, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="card full">
          <h2>Top earners ({currency})</h2>
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Department</th>
                <th>Country</th>
                <th>Annualized salary</th>
              </tr>
            </thead>
            <tbody>
              {topEarners.map((e) => (
                <tr key={`${e.name}-${e.annualized_amount}`}>
                  <td>{e.name}</td>
                  <td>{e.department}</td>
                  <td>{e.country}</td>
                  <td>{formatMoney(e.annualized_amount, e.currency)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}