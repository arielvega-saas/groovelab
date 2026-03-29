import { motion } from 'motion/react'
import { cn } from '@/lib/utils'

interface MetronomeDisplayProps {
  bpm: number
  isRunning: boolean
  currentBeat: number
  beatsPerMeasure: number
  onBpmChange: (bpm: number) => void
  onTap: () => void
  onToggle: () => void
}

export function MetronomeDisplay({
  bpm, isRunning, currentBeat, beatsPerMeasure,
  onBpmChange, onTap, onToggle,
}: MetronomeDisplayProps) {
  const pendulumAngle = currentBeat % 2 === 0 ? -28 : 28

  return (
    <div className="flex flex-col items-center gap-6 p-4">
      <div className="flex flex-col items-center">
        <div className="numeric font-bold leading-none no-select"
          style={{
            fontSize: 84,
            color: isRunning ? '#FFFFFF' : '#404040',
            textShadow: isRunning ? '0 0 30px rgba(4,197,247,0.25)' : 'none',
            letterSpacing: '-0.03em',
            transition: 'color 0.3s',
          }}>
          {bpm.toFixed(1)}
        </div>
        <span className="hw-label text-studio-400 mt-1">BPM</span>
      </div>

      <div className="relative flex justify-center" style={{ width: 16, height: 148 }}>
        <motion.div
          className="absolute top-0 origin-top"
          style={{
            width: 2, height: 132,
            background: 'linear-gradient(to bottom, #04C5F7, rgba(4,197,247,0.15))',
            borderRadius: '1px',
          }}
          animate={isRunning ? { rotate: pendulumAngle } : { rotate: 0 }}
          transition={{ type: 'spring', stiffness: 280, damping: 22, mass: 0.9 }}
        >
          <div className="absolute bottom-0 left-1/2 -translate-x-1/2 rounded-full"
            style={{
              width: 18, height: 18,
              background: isRunning
                ? 'radial-gradient(circle at 35% 35%, #06E0FF, #04C5F7)'
                : 'radial-gradient(circle at 35% 35%, #444, #252525)',
              boxShadow: isRunning
                ? '0 0 12px rgba(4,197,247,0.7), 0 0 24px rgba(4,197,247,0.3)'
                : 'none',
              transition: 'background 0.3s, box-shadow 0.3s',
            }}
          />
        </motion.div>
        <div className="absolute top-0 w-2 h-2 rounded-full bg-studio-600 shadow-[inset_0_1px_2px_rgba(0,0,0,0.5)]" />
      </div>

      <div className="flex gap-2 items-center">
        {Array.from({ length: beatsPerMeasure }, (_, i) => {
          const isActive = isRunning && currentBeat === i
          const isDown = i === 0
          return (
            <div key={i}
              className={cn('rounded-full transition-all duration-75', isDown ? 'w-4 h-4' : 'w-3 h-3')}
              style={{
                backgroundColor: isActive ? (isDown ? '#FFFFFF' : '#04C5F7') : '#252525',
                boxShadow: isActive
                  ? isDown
                    ? '0 0 10px #FFF, 0 0 20px rgba(255,255,255,0.4)'
                    : '0 0 10px #04C5F7, 0 0 20px rgba(4,197,247,0.4)'
                  : 'none',
                transform: isActive ? 'scale(1.25)' : 'scale(1)',
              }}
            />
          )
        })}
      </div>

      <div className="flex items-center gap-4">
        <button onClick={() => onBpmChange(Math.max(10, bpm - 1))}
          className="w-12 h-12 rounded-full bg-studio-700 border border-studio-600 text-studio-200 text-xl no-select hover:bg-studio-600 active:bg-studio-800 transition-colors">
          −
        </button>
        <button onClick={onTap}
          className="no-select font-display text-sm tracking-widest text-accent border-2 border-accent/40 rounded-full hover:border-accent hover:bg-accent/5 active:bg-accent/10 transition-all duration-100"
          style={{ width: 80, height: 80, boxShadow: '0 0 20px rgba(4,197,247,0.1)' }}>
          TAP
        </button>
        <button onClick={() => onBpmChange(Math.min(400, bpm + 1))}
          className="w-12 h-12 rounded-full bg-studio-700 border border-studio-600 text-studio-200 text-xl no-select hover:bg-studio-600 active:bg-studio-800 transition-colors">
          +
        </button>
      </div>

      <button onClick={onToggle}
        className={cn(
          'w-20 h-20 rounded-full font-display text-sm tracking-widest no-select',
          'border-2 transition-all duration-200',
          isRunning
            ? 'border-error text-error hover:bg-error/10'
            : 'border-accent text-accent hover:bg-accent/10',
        )}
        style={{
          boxShadow: isRunning
            ? '0 0 20px rgba(239,68,68,0.2)'
            : '0 0 20px rgba(4,197,247,0.2)',
        }}>
        {isRunning ? 'STOP' : 'START'}
      </button>
    </div>
  )
}
