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

// Compact form for chart axes: 2500000 -> "2.5M", 1200000000 -> "1.2B".
export function formatCompact(value: number | string | undefined | null): string {
  if (value === undefined || value === null || value === '') return '—'
  return new Intl.NumberFormat(undefined, {
    notation: 'compact',
    maximumFractionDigits: 1,
  }).format(Number(value))
}

// Distribution band labels come from the API as "44583–61702"; compact both ends.
export function formatBand(label: string): string {
  const [low, high] = label.split('–')
  if (high === undefined) return formatCompact(label)
  return `${formatCompact(low)}–${formatCompact(high)}`
}