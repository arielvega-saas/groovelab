/**
 * TrackWaveform — Canvas-based waveform visualization for a single track
 *
 * Draws colored waveform bars with section-based coloring,
 * playhead line, and mute opacity handling.
 */
import { useRef, useEffect, memo } from 'react'
import type { Section } from '../types'

interface TrackWaveformProps {
  peaks: number[]
  baseColor: string
  sections: Section[]
  progress: number
  muted: boolean
}

export const TrackWaveform = memo(function TrackWaveform({
  peaks,
  baseColor,
  sections,
  progress,
  muted,
}: TrackWaveformProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const dpr = window.devicePixelRatio || 1
    const w = canvas.clientWidth
    const h = canvas.clientHeight
    canvas.width = w * dpr
    canvas.height = h * dpr
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, w, h)

    const barW = w / peaks.length
    const half = h / 2
    const alpha = muted ? '25' : '80'

    for (let i = 0; i < peaks.length; i++) {
      const amp = peaks[i] * half * 0.85
      const x = i * barW
      const position = i / peaks.length

      // Determine color from section at this position
      let color = baseColor
      for (const section of sections) {
        if (position >= section.start && position < section.end) {
          color = section.color
          break
        }
      }

      ctx.fillStyle = color + alpha
      ctx.fillRect(x + 0.5, half - amp, Math.max(1, barW - 1), amp * 2)
    }

    // Playhead
    if (progress > 0 && progress < 1) {
      const px = progress * w
      ctx.fillStyle = 'rgba(255,255,255,0.8)'
      ctx.fillRect(px, 0, 1.5, h)
    }
  }, [peaks, baseColor, sections, progress, muted])

  return (
    <canvas
      ref={canvasRef}
      className="w-full h-full"
      style={{ display: 'block' }}
    />
  )
})
