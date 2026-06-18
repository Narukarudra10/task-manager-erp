export default function RootPage() {
  return (
    <div style={{
      fontFamily: 'system-ui, sans-serif',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      height: '100vh',
      backgroundColor: '#0f0f10',
      color: '#f4f4f5',
      textAlign: 'center',
      padding: '20px',
    }}>
      <h1 style={{ fontSize: '2.5rem', fontWeight: 'bold', margin: '0 0 12px 0', color: '#6750A4' }}>TaskFlow API Backend</h1>
      <p style={{ color: '#a1a1aa', fontSize: '1.1rem', margin: '0 0 24px 0' }}>
        The collaborative SQLite database server is running and ready.
      </p>
      <div style={{
        padding: '12px 24px',
        backgroundColor: '#1c1c1e',
        borderRadius: '8px',
        border: '1px solid #2c2c2e',
        fontSize: '0.9rem',
        color: '#e5e5ea',
      }}>
        Connect using the Flutter client at <code style={{ color: '#34c759' }}>http://localhost:3000</code>
      </div>
    </div>
  )
}
