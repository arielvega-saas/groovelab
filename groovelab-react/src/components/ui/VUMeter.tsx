interface VUMeterProps {
  level: number
  peak?: number
  segments?: number
  width?: number
  height?: number
}

export function VUMeter({
  level, peak = 0, segments = 20, width = 12, height = 80,
}: VUMeterProps) {
  const active = Math.round(level * segments)
  const peakSeg = Math.round(peak * segments)

  const color = (i: number) =>
    i / segments > 0.85 ? '#FF0000'
    : i / segments > 0.65 ? '#FFAA00'
    : '#00FF44'

  return (
    <div
      className="flex gap-0.5"
      style={{ flexDirection: 'column-reverse', width, height }}
      role="meter"
      aria-label="Volume level"
      aria-valuenow={Math.round(level * 100)}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      {Array.from({ length: segments }, (_, i) => {
        const on = i < active || i === peakSeg
        const c = color(i)
        return (
          <div
            key={i}
            className="rounded-sm flex-1 transition-all duration-50"
            style={{
              backgroundColor: on ? c : '#1A1A1A',
              boxShadow: on ? `0 0 4px ${c}, 0 0 8px ${c}44` : 'inset 0 1px 2px rgba(0,0,0,0.5)',
              minHeight: 2,
            }}
          />
        )
      })}
    </div>
  )
}
