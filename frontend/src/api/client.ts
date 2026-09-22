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

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${API}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })

  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as ApiError
    throw new Error(JSON.stringify(body.errors ?? { error: res.statusText }))
  }

  if (res.status === 204) return undefined as T
  return res.json() as Promise<T>
}

export const api = {
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

  departments: () => request<{ departments: string[] }>('/departments'),
  countries: () => request<{ countries: string[] }>('/countries'),
  summary: () => request<{ summary: PayrollSummary }>('/summary'),
}