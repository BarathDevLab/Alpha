// src/CareTab.jsx
// Contact's alert feed — shows level only, never text or audio content.

const LEVEL_COLOR = { 1: '#126a72', 2: '#b26a00', 3: '#b00020' }
const LEVEL_LABEL = { 1: 'Low', 2: 'Medium', 3: 'High' }
const LEVEL_MSG   = {
  1: 'A low-level signal was detected. No action needed.',
  2: 'A medium-risk signal was detected. Consider checking in.',
  3: 'A high-risk signal was detected. Please reach out now.',
}

function AlertCard({ event }) {
  const color = LEVEL_COLOR[event.level] || '#555'
  const label = LEVEL_LABEL[event.level] || '?'
  const msg   = LEVEL_MSG[event.level] || ''

  return (
    <div style={{
      border: `1px solid ${color}30`,
      borderLeft: `4px solid ${color}`,
      borderRadius: 10, padding: 16,
      background: '#fff', marginBottom: 12,
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontWeight: 700, fontSize: 16, color }}>
          {label} risk
        </span>
        <span style={{ fontSize: 12, color: '#888' }}>
          {new Date(event.ts).toLocaleString()}
        </span>
      </div>
      <p style={{ marginTop: 8, fontSize: 14, color: '#333' }}>{msg}</p>
      <p style={{ marginTop: 4, fontSize: 12, color: '#999' }}>
        No text or audio was shared. Only this alert level was sent.
      </p>
    </div>
  )
}

export default function CareTab({ events }) {
  return (
    <div style={{ padding: 20, maxWidth: 640, margin: '0 auto', overflowY: 'auto', height: '100%' }}>
      <h2 style={{ marginBottom: 4 }}>💙 Care feed</h2>
      <p style={{ color: '#666', fontSize: 14, marginBottom: 20 }}>
        Alert levels from your paired contact's device. No content is ever shared.
      </p>

      {events.length === 0 && (
        <div style={{
          textAlign: 'center', padding: 40, color: '#888',
          border: '1px dashed #ccc', borderRadius: 12,
        }}>
          No alerts yet. When your contact's device detects a signal, it will appear here.
        </div>
      )}

      {events.map(e => <AlertCard key={e.id} event={e} />)}
    </div>
  )
}
