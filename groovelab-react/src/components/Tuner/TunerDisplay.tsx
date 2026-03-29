import { useMemo } from 'react'

interface TunerDisplayProps {
  note: string | null
  octave: number | null
  cents: number
  frequency: number | null
  isActive: boolean
}

export function TunerDisplay({
  note, octave, cents, frequency, isActive,
}: TunerDisplayProps) {
  const rotation = (cents / 50) * 45
  const isInTune = Math.abs(cents) < 5
  const isClose = Math.abs(cents) < 15
  const needleCol = isInTune ? '#00FF44' : isClose ? '#FFAA00' : '#FF4444'

  const ticks = useMemo(() =>
    Array.from({ length: 21 }, (_, i) => {
      const ang = -90 + (i * 180) / 20
      const rad = (ang * Math.PI) / 180
      const r1 = i % 5 === 0 ? 66 : 70
      const r2 = 78
      return {
        x1: 100 + r1 * Math.cos(rad), y1: 100 + r1 * Math.sin(rad),
        x2: 100 + r2 * Math.cos(rad), y2: 100 + r2 * Math.sin(rad),
        major: i % 5 === 0, center: i === 10,
      }
    }), [])

  return (
    <div className="flex flex-col items-center gap-3 w-full">
      <div className="relative w-72 h-40">
        <svg viewBox="0 0 200 112" className="w-full">
          <path d="M22 100 A78 78 0 0 1 55 28" fill="none" stroke="#FF444460" strokeWidth="8" strokeLinecap="round" />
          <path d="M55 28 A78 78 0 0 1 82 13" fill="none" stroke="#FFAA0060" strokeWidth="8" strokeLinecap="round" />
          <path d="M82 13 A78 78 0 0 1 118 13" fill="none"
            stroke={isActive && isInTune ? '#00FF44' : '#00FF4460'}
            strokeWidth="8" strokeLinecap="round"
            style={{ filter: isActive && isInTune ? 'drop-shadow(0 0 5px #00FF44)' : 'none', transition: 'stroke 0.3s, filter 0.3s' }} />
          <path d="M118 13 A78 78 0 0 1 145 28" fill="none" stroke="#FFAA0060" strokeWidth="8" strokeLinecap="round" />
          <path d="M145 28 A78 78 0 0 1 178 100" fill="none" stroke="#FF444460" strokeWidth="8" strokeLinecap="round" />
          {ticks.map((t, i) => (
            <line key={i} x1={t.x1} y1={t.y1} x2={t.x2} y2={t.y2}
              stroke={t.center ? '#505050' : '#353535'}
              strokeWidth={t.center ? 2.5 : t.major ? 1.5 : 0.8} />
          ))}
        </svg>
        <div className="absolute bottom-0 left-1/2 origin-bottom"
          style={{
            width: 2.5, height: 92,
            transform: `translateX(-50%) rotate(${rotation}deg)`,
            transition: isActive ? 'transform 0.15s cubic-bezier(0.34,1.2,0.64,1)' : 'none',
            background: `linear-gradient(to top, #444, ${needleCol})`,
            borderRadius: '2px 2px 0 0',
            filter: isActive ? `drop-shadow(0 0 4px ${needleCol})` : 'none',
          }}
        />
        <div className="absolute bottom-[-4px] left-1/2 w-3 h-3 rounded-full -translate-x-1/2 bg-studio-600 shadow-[0_0_0_1px_#505050]" />
      </div>

      <div className="flex items-start gap-1">
        <span className="font-display font-bold leading-none"
          style={{
            fontSize: 76,
            color: isActive ? (isInTune ? '#00FF44' : '#FFFFFF') : '#383838',
            textShadow: isActive && isInTune ? '0 0 24px rgba(0,255,68,0.6), 0 0 48px rgba(0,255,68,0.25)' : 'none',
            transition: 'color 0.25s, text-shadow 0.25s',
          }}>
          {note ?? '\u2014'}
        </span>
        {octave !== null && (
          <span className="numeric text-studio-400 text-xl mt-3">{octave}</span>
        )}
      </div>

      <div className="flex items-center gap-3">
        <span className="numeric text-2xl font-bold"
          style={{
            color: isActive ? (isInTune ? '#00FF44' : isClose ? '#FFAA00' : '#FF4444') : '#383838',
            minWidth: '5ch', textAlign: 'center',
            transition: 'color 0.2s',
          }}>
          {isActive ? (cents >= 0 ? '+' : '') + cents.toFixed(1) : '\u00B10.0'}
        </span>
        <span className="hw-label">CENTS</span>
      </div>

      {frequency !== null && frequency > 0 && (
        <span className="numeric text-sm text-studio-400">{frequency.toFixed(1)} Hz</span>
      )}

      <div className="px-4 py-1 rounded-full border transition-all duration-300"
        style={{
          borderColor: isActive && isInTune ? '#00FF44' : '#383838',
          color: isActive && isInTune ? '#00FF44' : '#505050',
          boxShadow: isActive && isInTune ? '0 0 12px rgba(0,255,68,0.3)' : 'none',
          backgroundColor: isActive && isInTune ? 'rgba(0,255,68,0.08)' : 'transparent',
        }}>
        <span className="hw-label">
          {!isActive ? 'LISTENING...' : isInTune ? '\u2713 IN TUNE' : 'ADJUST TUNING'}
        </span>
      </div>
    </div>
  )
}
