import { useState } from 'react'
import { api } from '../api/client'
import type { SalaryRecord } from '../api/types'
import { formatMoney } from '../lib/format'

interface EditableRow {
  id?: number
  name: string
  kind: 'earning' | 'deduction'
  amount: string
  _destroy?: boolean
}

export default function SalaryBreakdown({
  record,
  onSaved,
}: {
  record: SalaryRecord
  onSaved: () => void
}) {
  const [editing, setEditing] = useState(false)
  const [rows, setRows] = useState<EditableRow[]>([])
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const currency = record.currency
  const components = (record.salary_components ?? []).filter((c) => !(c as { _destroy?: boolean })._destroy)
  const earnings = components.filter((c) => c.kind === 'earning')
  const deductions = components.filter((c) => c.kind === 'deduction')

  const startEdit = () => {
    setRows(components.map((c) => ({ id: c.id, name: c.name, kind: c.kind, amount: c.amount })))
    setEditing(true)
    setError('')
  }

  const updateRow = (index: number, key: keyof EditableRow, value: string) =>
    setRows((current) => current.map((row, i) => (i === index ? { ...row, [key]: value } : row)))

  const addRow = (kind: 'earning' | 'deduction') =>
    setRows((current) => [...current, { name: kind === 'earning' ? 'New earning' : 'New deduction', kind, amount: '0' }])

  const removeRow = (index: number) =>
    setRows((current) => current.map((row, i) => (i === index ? { ...row, _destroy: true } : row)))

  const active = rows.filter((r) => !r._destroy)
  const draftGross = active.filter((r) => r.kind === 'earning').reduce((sum, r) => sum + Number(r.amount || 0), 0)
  const draftDeductions = active.filter((r) => r.kind === 'deduction').reduce((sum, r) => sum + Number(r.amount || 0), 0)

  const save = async () => {
    setSaving(true)
    setError('')
    try {
      await api.updateSalaryRecord(record.id, {
        salary_components_attributes: rows.map((row, index) => ({
          id: row.id,
          name: row.name,
          kind: row.kind,
          amount: row.amount,
          position: index + 1,
          _destroy: row._destroy,
        })),
      })
      setEditing(false)
      onSaved()
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setSaving(false)
    }
  }

  if (editing) {
    return (
      <div className="breakdown">
        {error && <div className="error-banner">{error}</div>}
        <table>
          <thead>
            <tr>
              <th>Component</th>
              <th>Type</th>
              <th>Amount</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) =>
              row._destroy ? null : (
                <tr key={index}>
                  <td>
                    <input type="text" value={row.name} onChange={(e) => updateRow(index, 'name', e.target.value)} />
                  </td>
                  <td>
                    <select value={row.kind} onChange={(e) => updateRow(index, 'kind', e.target.value)}>
                      <option value="earning">Earning</option>
                      <option value="deduction">Deduction</option>
                    </select>
                  </td>
                  <td>
                    <input type="number" min="0" step="0.01" value={row.amount} onChange={(e) => updateRow(index, 'amount', e.target.value)} />
                  </td>
                  <td>
                    <button type="button" className="link-btn" onClick={() => removeRow(index)}>
                      Remove
                    </button>
                  </td>
                </tr>
              ),
            )}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan={2}>Gross (earnings)</td>
              <td>{formatMoney(draftGross, currency)}</td>
              <td></td>
            </tr>
            <tr>
              <td colSpan={2}>Deductions</td>
              <td>{formatMoney(draftDeductions, currency)}</td>
              <td></td>
            </tr>
            <tr className="net">
              <td colSpan={2}>Net pay</td>
              <td>{formatMoney(draftGross - draftDeductions, currency)}</td>
              <td></td>
            </tr>
          </tfoot>
        </table>

        <div className="breakdown-actions" style={{ marginTop: 10 }}>
          <button className="btn secondary" type="button" onClick={() => addRow('earning')}>
            + Earning
          </button>{' '}
          <button className="btn secondary" type="button" onClick={() => addRow('deduction')}>
            + Deduction
          </button>{' '}
          <button className="btn" type="button" onClick={save} disabled={saving}>
            {saving ? 'Saving…' : 'Save breakdown'}
          </button>{' '}
          <button className="btn secondary" type="button" onClick={() => setEditing(false)} disabled={saving}>
            Cancel
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="breakdown">
      <div className="breakdown-actions">
        <button className="btn secondary" type="button" onClick={startEdit}>
          Edit breakdown
        </button>
      </div>
      <table>
        <thead>
          <tr>
            <th>Component</th>
            <th>Type</th>
            <th>Amount</th>
          </tr>
        </thead>
        <tbody>
          {components.length === 0 && (
            <tr>
              <td colSpan={3} className="muted">No breakdown recorded. Click “Edit breakdown” to add one.</td>
            </tr>
          )}
          {earnings.map((c) => (
            <tr key={c.id}>
              <td>{c.name}</td>
              <td>Earning</td>
              <td>{formatMoney(c.amount, currency)}</td>
            </tr>
          ))}
          {deductions.map((c) => (
            <tr key={c.id}>
              <td>{c.name}</td>
              <td>Deduction</td>
              <td>− {formatMoney(c.amount, currency)}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan={2}>Gross (earnings)</td>
            <td>{formatMoney(record.gross_earnings, currency)}</td>
          </tr>
          <tr>
            <td colSpan={2}>Deductions</td>
            <td>{formatMoney(record.total_deductions, currency)}</td>
          </tr>
          <tr className="net">
            <td colSpan={2}>Net pay</td>
            <td>{formatMoney(record.net_pay, currency)}</td>
          </tr>
        </tfoot>
      </table>
    </div>
  )
}