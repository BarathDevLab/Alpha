// src/useSSE.js
// Custom hook that opens an SSE connection and yields parsed event objects.

import { useEffect, useState, useRef } from 'react'

export function useSSE(url) {
  const [events, setEvents] = useState([])
  const esRef = useRef(null)

  useEffect(() => {
    const es = new EventSource(url)
    esRef.current = es

    es.onmessage = (e) => {
      try {
        const event = JSON.parse(e.data)
        setEvents(prev => [event, ...prev].slice(0, 300)) // keep last 300
      } catch (_) {}
    }

    es.onerror = () => {
      // SSE auto-reconnects; nothing to do
    }

    return () => {
      es.close()
    }
  }, [url])

  return events
}
