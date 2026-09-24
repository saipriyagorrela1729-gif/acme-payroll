import { lazy, Suspense, type ReactNode } from 'react'
import { NavLink, Navigate, Route, Routes, useNavigate } from 'react-router-dom'
import { api, clearToken, isAuthenticated } from './api/client'
import Spinner from './components/Spinner'
import EmployeeDetailPage from './pages/EmployeeDetailPage'
import EmployeeFormPage from './pages/EmployeeFormPage'
import EmployeesPage from './pages/EmployeesPage'
import LoginPage from './pages/LoginPage'

// Recharts is heavy (~500 kB); load it only when the dashboard is opened.
const DashboardPage = lazy(() => import('./pages/DashboardPage'))

function RequireAuth({ children }: { children: ReactNode }) {
  if (!isAuthenticated()) return <Navigate to="/login" replace />
  return <>{children}</>
}

function Nav() {
  const navigate = useNavigate()

  const logout = async () => {
    try {
      await api.logout()
    } catch {
      // ignore — we clear the token regardless
    }
    clearToken()
    navigate('/login')
  }

  return (
    <nav className="nav">
      <span className="brand">ACME Payroll</span>
      <NavLink to="/" end>
        Dashboard
      </NavLink>
      <NavLink to="/employees">Employees</NavLink>
      <button className="nav-logout" onClick={logout}>
        Log out
      </button>
    </nav>
  )
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/*"
        element={
          <RequireAuth>
            <Nav />
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
          </RequireAuth>
        }
      />
    </Routes>
  )
}