// src/CityTab.jsx
// Left: Leaflet map with event pins. Right: timeline list.

import { MapContainer, TileLayer, CircleMarker, Popup } from 'react-leaflet'
import 'leaflet/dist/leaflet.css'

// ── Geohash → lat/lng decoder (base32, simple 2D) ────────────────────────────
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz'
function geohashToLatLng(hash) {
  if (!hash) return null
  let isLng = true, minLat = -90, maxLat = 90, minLng = -180, maxLng = 180
  for (const ch of hash.toLowerCase()) {
    const idx = BASE32.indexOf(ch)
    if (idx < 0) return null
    for (let bits = 4; bits >= 0; bits--) {
      const bit = (idx >> bits) & 1
      if (isLng) {
        const mid = (minLng + maxLng) / 2
        bit ? (minLng = mid) : (maxLng = mid)
      } else {
        const mid = (minLat + maxLat) / 2
        bit ? (minLat = mid) : (maxLat = mid)
      }
      isLng = !isLng
    }
  }
  return [(minLat + maxLat) / 2, (minLng + maxLng) / 2]
}

const LEVEL_COLOR = { 1: '#126a72', 2: '#b26a00', 3: '#b00020' }
const LEVEL_LABEL = { 1: 'Low', 2: 'Medium', 3: 'High' }

function EventPin({ event }) {
  const coords = geohashToLatLng(event.geohash)
  if (!coords) return null
  const color = LEVEL_COLOR[event.level] || '#555'
  return (
    <CircleMarker
      center={coords}
      radius={10 + event.level * 3}
      pathOptions={{ color, fillColor: color, fillOpacity: 0.6 }}
    >
      <Popup>
        <strong>{event.label}</strong><br />
        Level: {LEVEL_LABEL[event.level]}<br />
        {event.db && <>~{event.db}<br /></>}
        {new Date(event.ts).toLocaleTimeString()}
      </Popup>
    </CircleMarker>
  )
}

function TimelineRow({ event }) {
  const color = LEVEL_COLOR[event.level] || '#555'
  const label = LEVEL_LABEL[event.level] || '?'
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '10px 16px', borderBottom: '1px solid #eee',
    }}>
      <div style={{
        width: 10, height: 10, borderRadius: '50%',
        background: color, flexShrink: 0,
      }} />
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 600, fontSize: 14 }}>{event.label}</div>
        <div style={{ fontSize: 12, color: '#666' }}>
          {new Date(event.ts).toLocaleTimeString()} · {event.geohash ?? 'no location'}
          {event.db && ` · ${event.db}`}
        </div>
      </div>
      <span style={{
        fontSize: 12, fontWeight: 700, color,
        background: color + '18', padding: '2px 8px', borderRadius: 20,
      }}>{label}</span>
    </div>
  )
}

export default function CityTab({ events, allEvents }) {
  // Default centre: Chennai (matches demo geohash "ttnem")
  const centre = [13.08, 80.27]

  return (
    <div style={{ display: 'flex', height: '100%' }}>
      {/* Map */}
      <div style={{ flex: 1 }}>
        <MapContainer
          center={centre} zoom={11}
          style={{ width: '100%', height: '100%' }}
          scrollWheelZoom
        >
          <TileLayer
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            attribution="© OpenStreetMap contributors"
          />
          {events.map(e => <EventPin key={e.id} event={e} />)}
        </MapContainer>
      </div>

      {/* Timeline */}
      <div style={{
        width: 320, borderLeft: '1px solid #d0e4e1',
        background: '#fff', overflowY: 'auto', display: 'flex', flexDirection: 'column',
      }}>
        <div style={{ padding: '12px 16px', fontWeight: 700, borderBottom: '1px solid #eee', fontSize: 14 }}>
          Event timeline · {allEvents.length} total
        </div>
        {allEvents.length === 0 && (
          <div style={{ padding: 24, color: '#888', textAlign: 'center' }}>
            Waiting for events…
          </div>
        )}
        {allEvents.map(e => <TimelineRow key={e.id + e.receivedAt} event={e} />)}
      </div>
    </div>
  )
}
