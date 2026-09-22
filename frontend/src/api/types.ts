export interface SalaryRecord {
  id: number
  amount: string
  currency: string
  frequency: 'annual' | 'monthly' | 'hourly'
  effective_date: string
  annualized_amount: string
}

export interface Employee {
  id: number
  name: string
  email: string
  job_title: string
  department: string
  country: string
  currency: string
  hire_date: string
  status: 'active' | 'terminated'
  current_salary: SalaryRecord | null
  salary_history?: SalaryRecord[]
}

export interface EmployeeListResponse {
  data: Employee[]
  meta: { page: number; per_page: number; total_count: number; total_pages: number }
}

export interface EmployeePayload {
  name: string
  email: string
  job_title: string
  department: string
  country: string
  currency: string
  hire_date: string
  status?: 'active' | 'terminated'
}

export interface SalaryRecordPayload {
  amount: string
  currency: string
  frequency: 'annual' | 'monthly' | 'hourly'
  effective_date: string
}

export interface GroupStats {
  name: string
  currency: string
  employees: number
  average: number
  median: number
}

export interface DistributionBand {
  band: number
  label: string
  count: number
}

export interface TopEarner {
  name: string
  department: string
  country: string
  currency: string
  annualized_amount: number
}

export interface PayrollSummary {
  headcount: { total: number; active: number; terminated: number }
  payroll: Record<string, { annualized: number; monthly: number }>
  by_department: GroupStats[]
  by_country: GroupStats[]
  distribution: Record<string, DistributionBand[]>
  top_earners: Record<string, TopEarner[]>
}

export interface ApiError {
  errors: Record<string, string>
}