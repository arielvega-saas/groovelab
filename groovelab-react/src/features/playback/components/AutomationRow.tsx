/**
 * AutomationRow — Marker indicators with automation lines
 *
 * Shows labeled automation points (M, L, S, E) connected by
 * dashed orange lines representing volume/parameter automation.
 */
import { useRef, useEffect } from 'react'
import type { AutomationPoint } from '../types'

interface AutomationRowProps {
  points: AutomationPoint[]
  progress: number
}

export function AutomationRow({ points, progress }: AutomationRowProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || points.length === 0) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const dpr = window.devicePixelRatio || 1
    const w = canvas.clientWidth
    const h = canvas.clientHeight
    canvas.width = w * dpr
    canvas.height = h * dpr
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, w, h)

    // Draw automation line (dashed orange)
    ctx.strokeStyle = '#FF9020'
    ctx.lineWidth = 1.5
    ctx.setLineDash([4, 3])
    ctx.beginPath()

    const sorted = [...points].sort((a, b) => a.position - b.position)
    for (let i = 0; i < sorted.length; i++) {
      const x = sorted[i].position * w
      const y = (1 - sorted[i].value) * h
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.stroke()
    ctx.setLineDash([])

    // Draw markers
    for (const point of sorted) {
      const x = point.position * w
      const y = (1 - point.value) * h

      // Marker dot
      ctx.fillStyle = point.color
      ctx.beginPath()
      ctx.arc(x, y, 4, 0, Math.PI * 2)
      ctx.fill()

      // Label
      if (point.label) {
        ctx.fillStyle = point.color
        ctx.font = 'bold 7px JetBrains Mono, monospace'
        ctx.textAlign = 'center'
        ctx.fillText(point.label, x, y - 6)
      }
    }

    // Playhead
    if (progress > 0 && progress < 1) {
      const px = progress * w
      ctx.strokeStyle = 'rgba(255,255,255,0.5)'
      ctx.lineWidth = 1
      ctx.setLineDash([])
      ctx.beginPath()
      ctx.moveTo(px, 0)
      ctx.lineTo(px, h)
      ctx.stroke()
    }
  }, [points, progress])

  if (points.length === 0) return null

  return (
    <div className="h-7 flex-shrink-0 bg-studio-950 border-b border-studio-800/60 relative flex items-center">
      {/* AUTO label */}
      <div className="w-14 flex-shrink-0 flex items-center justify-center bg-studio-800 border-r border-studio-600/40 h-full">
        <span className="hw-label text-studio-500 text-[7px]">AUTO</span>
      </div>
      {/* Canvas */}
      <div className="flex-1 h-full relative">
        <canvas
          ref={canvasRef}
          className="w-full h-full"
          style={{ display: 'block' }}
        />
      </div>
    </div>
  )
}
