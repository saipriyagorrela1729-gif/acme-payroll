import type {
  ApiError,
  Employee,
  EmployeeListResponse,
  EmployeePayload,
  PayrollSummary,
  SalaryRecord,
  SalaryRecordPayload,
} from './types'

const API = '/api/v1'
const TOKEN_KEY = 'acme_payroll_token'

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token)
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY)
}

export function isAuthenticated(): boolean {
  return getToken() !== null
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const token = getToken()
  const res = await fetch(`${API}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...options,
  })

  if (res.status === 401 && path !== '/session') {
    clearToken()
    window.location.assign('/login')
    throw new Error('Unauthorized')
  }

  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as ApiError
    throw new Error(JSON.stringify(body.errors ?? { error: res.statusText }))
  }

  if (res.status === 204) return undefined as T
  return res.json() as Promise<T>
}

export const api = {
  login: (email: string, password: string) =>
    request<{ token: string; email: string }>('/session', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),

  logout: () => request<void>('/session', { method: 'DELETE' }),

  listEmployees: (params: URLSearchParams) =>
    request<EmployeeListResponse>(`/employees?${params.toString()}`),

  getEmployee: (id: number) => request<{ employee: Employee }>(`/employees/${id}`),

  createEmployee: (data: EmployeePayload) =>
    request<{ employee: Employee }>('/employees', {
      method: 'POST',
      body: JSON.stringify({ employee: data }),
    }),

  updateEmployee: (id: number, data: Partial<EmployeePayload>) =>
    request<{ employee: Employee }>(`/employees/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ employee: data }),
    }),

  deleteEmployee: (id: number) => request<void>(`/employees/${id}`, { method: 'DELETE' }),

  createSalaryRecord: (id: number, data: SalaryRecordPayload) =>
    request<{ salary_record: SalaryRecord }>(`/employees/${id}/salary_records`, {
      method: 'POST',
      body: JSON.stringify({ salary_record: data }),
    }),

  updateSalaryRecord: (id: number, data: Partial<SalaryRecordPayload>) =>
    request<{ salary_record: SalaryRecord }>(`/salary_records/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ salary_record: data }),
    }),

  departments: () => request<{ departments: string[] }>('/departments'),
  countries: () => request<{ countries: string[] }>('/countries'),
  summary: () => request<{ summary: PayrollSummary }>('/summary'),
}