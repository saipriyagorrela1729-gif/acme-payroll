import { lazy, Suspense } from 'react'
import { NavLink, Route, Routes } from 'react-router-dom'
import Spinner from './components/Spinner'
import EmployeeDetailPage from './pages/EmployeeDetailPage'
import EmployeeFormPage from './pages/EmployeeFormPage'
import EmployeesPage from './pages/EmployeesPage'

// Recharts is heavy (~500 kB); load it only when the dashboard is opened.
const DashboardPage = lazy(() => import('./pages/DashboardPage'))

export default function App() {
  return (
    <>
      <nav className="nav">
        <span className="brand">ACME Payroll</span>
        <NavLink to="/" end>
          Dashboard
        </NavLink>
        <NavLink to="/employees">Employees</NavLink>
      </nav>

      <main className="container">
        <Suspense fallback={<Spinner label="Loading…" />}>
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/employees" element={<EmployeesPage />} />
            <Route path="/employees/new" element={<EmployeeFormPage />} />
            <Route path="/employees/:id/edit" element={<EmployeeFormPage />} />
            <Route path="/employees/:id" element={<EmployeeDetailPage />} />
          </Routes>
        </Suspense>
      </main>
    </>
  )
}