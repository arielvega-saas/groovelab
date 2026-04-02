/**
 * StatusBar — Bottom status bar showing total time, buffer, sample rate, and latency
 *
 * Matches the design: TOTAL: 36:50 | Buffers: 256 · 44.1kHz · Latencia: 5.8ms
 */
import { formatTime } from '../constants'

interface StatusBarProps {
  totalDuration: number
  bufferSize: number
  sampleRate: number
  latencyMs: number
}

export function StatusBar({ totalDuration, bufferSize, sampleRate, latencyMs }: StatusBarProps) {
  const sampleRateKHz = (sampleRate / 1000).toFixed(1)

  return (
    <div className="h-6 flex-shrink-0 bg-studio-900 border-t border-studio-600/40 flex items-center px-3 gap-4">
      <div className="flex items-center gap-1">
        <span className="hw-label text-studio-500 text-[8px]">TOTAL</span>
        <span className="numeric text-[10px] text-studio-300 font-semibold">
          {formatTime(totalDuration)}
        </span>
      </div>

      <div className="flex-1" />

      <div className="flex items-center gap-2 text-[9px]">
        <span className="text-studio-500">
          Buffers: <span className="numeric text-studio-400">{bufferSize}</span>
        </span>
        <span className="text-studio-600">&middot;</span>
        <span className="numeric text-studio-400">{sampleRateKHz}kHz</span>
        <span className="text-studio-600">&middot;</span>
        <span className="text-studio-500">
          Latencia: <span className="numeric text-studio-400">{latencyMs}ms</span>
        </span>
      </div>
    </div>
  )
}
