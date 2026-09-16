import { useEffect, useState } from 'react'
import { FileText, Server } from 'lucide-react'

export default function App() {
  const [health, setHealth] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    fetch('/api/health/')
      .then((response) => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`)
        }
        return response.json()
      })
      .then(setHealth)
      .catch((err) => setError(err.message))
  }, [])

  return (
    <main className="page">
      <header className="hero">
        <div className="hero-icon">
          <FileText size={28} />
        </div>
        <div>
          <p className="eyebrow">Proyecto Facturación</p>
          <h1>Arquitectura Django + React</h1>
          <p className="subtitle">
            Misma estructura que turismo-desarrollo: backend API, frontend Vite, deploy y CI.
          </p>
        </div>
      </header>

      <section className="card">
        <div className="card-title">
          <Server size={18} />
          <span>Estado del backend</span>
        </div>
        {health && (
          <pre>{JSON.stringify(health, null, 2)}</pre>
        )}
        {error && <p className="error">No se pudo conectar con /api/health/: {error}</p>}
        {!health && !error && <p>Verificando API...</p>}
      </section>
    </main>
  )
}
