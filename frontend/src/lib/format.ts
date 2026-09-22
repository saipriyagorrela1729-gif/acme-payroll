export function formatNumber(value: number | string | undefined | null): string {
  if (value === undefined || value === null || value === '') return '—'
  return Number(value).toLocaleString(undefined, { maximumFractionDigits: 0 })
}

export function formatMoney(value: number | string | undefined | null, currency?: string): string {
  if (value === undefined || value === null || value === '') return '—'
  const amount = Number(value).toLocaleString(undefined, { maximumFractionDigits: 0 })
  return currency ? `${currency} ${amount}` : amount
}

export function formatDate(date: string | undefined | null): string {
  if (!date) return '—'
  return new Date(`${date}T00:00:00`).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}