// src/App.jsx
import { useState } from 'react'
import { useSSE } from './useSSE'
import CityTab from './CityTab'
import CareTab from './CareTab'

const TAB_STYLES = {
  nav: {
    display: 'flex', gap: 4, padding: '12px 20px 0',
    borderBottom: '1px solid #d0e4e1', background: '#fff',
  },
  tab: (active) => ({
    padding: '8px 20px', cursor: 'pointer', border: 'none',
    borderBottom: active ? '3px solid #126a72' : '3px solid transparent',
    background: 'none', fontWeight: active ? 700 : 400,
    color: active ? '#126a72' : '#555', fontSize: 15,
  }),
  header: {
    display: 'flex', alignItems: 'center', gap: 10,
    padding: '14px 20px', background: '#126a72', color: '#fff',
  },
}

export default function App() {
  const [tab, setTab] = useState('city')
  const events = useSSE('/events/stream')

  const soundEvents = events.filter(e => e.type === 'sound')
  const mindEvents  = events.filter(e => e.type === 'mind')

  return (
    <div style={{ height: '100vh', display: 'flex', flexDirection: 'column' }}>
      <div style={TAB_STYLES.header}>
        <span style={{ fontSize: 22 }}>🛡️</span>
        <span style={{ fontWeight: 700, fontSize: 18 }}>SafeSense Dashboard</span>
        <span style={{ marginLeft: 'auto', fontSize: 13, opacity: 0.8 }}>
          {events.length} event{events.length !== 1 ? 's' : ''} live
        </span>
      </div>

      <nav style={TAB_STYLES.nav}>
        <button style={TAB_STYLES.tab(tab === 'city')} onClick={() => setTab('city')}>
          🗺 City
        </button>
        <button style={TAB_STYLES.tab(tab === 'care')} onClick={() => setTab('care')}>
          💙 Care
        </button>
      </nav>

      <div style={{ flex: 1, overflow: 'hidden' }}>
        {tab === 'city' && <CityTab events={soundEvents} allEvents={events} />}
        {tab === 'care' && <CareTab events={mindEvents} />}
      </div>
    </div>
  )
}
