import { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import * as Tone from 'tone'
import { cn } from '@/lib/cn'

/* ------------------------------------------------------------------ */
/*  Constants                                                          */
/* ------------------------------------------------------------------ */

const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'] as const
const FFT_SIZE = 4096
const HISTORY_LEN = 100
const SMOOTHING = 0.85
const MIN_DB = -60
const MAX_DB = 0

type WaveformType = 'sine' | 'sawtooth' | 'square' | 'triangle'

interface InstrumentPreset {
  label: string
  notes: string[]
}

const PRESETS: Record<string, InstrumentPreset> = {
  chromatic: { label: 'Chromatic', notes: [] },
  guitar: { label: 'Guitar', notes: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'] },
  bass: { label: 'Bass', notes: ['E1', 'A1', 'D2', 'G2'] },
  ukulele: { label: 'Ukulele', notes: ['G4', 'C4', 'E4', 'A4'] },
}

/* ------------------------------------------------------------------ */
/*  Pitch helpers                                                      */
/* ------------------------------------------------------------------ */

function frequencyToNote(freq: number, a4: number) {
  const semitonesFromA4 = 12 * Math.log2(freq / a4)
  const nearestSemitone = Math.round(semitonesFromA4)
  const cents = (semitonesFromA4 - nearestSemitone) * 100
  const midiNote = 69 + nearestSemitone
  const octave = Math.floor(midiNote / 12) - 1
  const noteIndex = ((midiNote % 12) + 12) % 12
  return {
    name: NOTE_NAMES[noteIndex],
    octave,
    cents: Math.round(cents * 10) / 10,
    midiNote,
  }
}

function noteNameToFreq(noteName: string, a4: number): number {
  const match = noteName.match(/^([A-G]#?)(\d)$/)
  if (!match) return a4
  const [, note, octStr] = match
  const noteIdx = NOTE_NAMES.indexOf(note as (typeof NOTE_NAMES)[number])
  if (noteIdx === -1) return a4
  const oct = parseInt(octStr)
  const midi = (oct + 1) * 12 + noteIdx
  return a4 * Math.pow(2, (midi - 69) / 12)
}

/* ------------------------------------------------------------------ */
/*  Autocorrelation pitch detector                                     */
/* ------------------------------------------------------------------ */

function autoCorrelate(buffer: Float32Array, sampleRate: number): number {
  const SIZE = buffer.length
  let rms = 0
  for (let i = 0; i < SIZE; i++) rms += buffer[i] * buffer[i]
  rms = Math.sqrt(rms / SIZE)
  if (rms < 0.008) return -1 // below noise floor

  // Trim silence from edges
  let r1 = 0
  let r2 = SIZE - 1
  const threshold = 0.2
  for (let i = 0; i < SIZE / 2; i++) {
    if (Math.abs(buffer[i]) < threshold) r1 = i; else break
  }
  for (let i = 1; i < SIZE / 2; i++) {
    if (Math.abs(buffer[SIZE - i]) < threshold) r2 = SIZE - i; else break
  }

  const trimmed = buffer.slice(r1, r2)
  const len = trimmed.length

  // Autocorrelation
  const corr = new Float32Array(len)
  for (let lag = 0; lag < len; lag++) {
    let sum = 0
    for (let i = 0; i < len - lag; i++) {
      sum += trimmed[i] * trimmed[i + lag]
    }
    corr[lag] = sum
  }

  // Find first dip then first peak after it
  let d = 0
  while (d < len && corr[d] > 0) d++
  if (d >= len) return -1

  let maxVal = -1
  let maxPos = -1
  for (let i = d; i < len; i++) {
    if (corr[i] > maxVal) {
      maxVal = corr[i]
      maxPos = i
    }
  }
  if (maxPos === -1) return -1

  // Parabolic interpolation for sub-sample accuracy
  const y1 = maxPos > 0 ? corr[maxPos - 1] : corr[maxPos]
  const y2 = corr[maxPos]
  const y3 = maxPos < len - 1 ? corr[maxPos + 1] : corr[maxPos]
  const shift = (y3 - y1) / (2 * (2 * y2 - y1 - y3))
  const refinedPos = maxPos + (isFinite(shift) ? shift : 0)

  return sampleRate / refinedPos
}

/* ------------------------------------------------------------------ */
/*  Headstock SVG                                                      */
/* ------------------------------------------------------------------ */

function GuitarHeadstock({
  notes,
  targetNote,
  inTune,
  cents,
  soundDetected,
}: {
  notes: string[]
  targetNote: string | null
  inTune: boolean
  cents: number
  soundDetected: boolean
}) {
  const isGuitar = notes.length === 6
  const isBass = notes.length === 4

  if (!isGuitar && !isBass) return null

  const w = 280
  const h = isGuitar ? 200 : 180

  // String color based on tuning status
  const getStringColor = (note: string) => {
    if (targetNote !== note) return '#555555'
    if (inTune) return '#00FF11'
    if (Math.abs(cents) < 15) return '#FF9500'
    return '#FF3B30'
  }

  // Peg rotation when being tuned
  const getPegRotation = (note: string) => {
    if (targetNote !== note) return 0
    if (inTune) return 0
    return Math.sin(Date.now() / 200) * 15 * (cents > 0 ? 1 : -1)
  }

  // String vibration class
  const getStringVibClass = (note: string) => {
    if (!soundDetected) return ''
    if (targetNote === note) return 'animate-[stringVib_0.05s_ease-in-out_infinite]'
    return ''
  }

  if (isGuitar) {
    // Guitar: 6 strings, 3+3 peg arrangement
    const leftPegs = [notes[0], notes[1], notes[2]] // E2, A2, D3 - left side
    const rightPegs = [notes[3], notes[4], notes[5]] // G3, B3, E4 - right side
    const stringSpacing = 24
    const startX = w / 2 - (5 * stringSpacing) / 2

    return (
      <div className="flex justify-center mb-2">
        <svg viewBox={`0 0 ${w} ${h}`} className="w-full max-w-[320px]">
          <defs>
            <linearGradient id="headstockGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#3D2B1F" />
              <stop offset="50%" stopColor="#2A1D13" />
              <stop offset="100%" stopColor="#1A1008" />
            </linearGradient>
            <filter id="pegShadow">
              <feDropShadow dx="0" dy="1" stdDeviation="1" floodColor="#000" floodOpacity="0.5" />
            </filter>
            <style>{`
              @keyframes stringVib {
                0%, 100% { transform: translateX(0); }
                25% { transform: translateX(-0.5px); }
                75% { transform: translateX(0.5px); }
              }
            `}</style>
          </defs>

          {/* Headstock body */}
          <path
            d={`M ${w / 2 - 50} ${h}
                Q ${w / 2 - 55} ${h - 40} ${w / 2 - 60} ${h - 70}
                Q ${w / 2 - 65} ${h - 110} ${w / 2 - 50} ${h - 140}
                Q ${w / 2 - 35} ${h - 165} ${w / 2 - 10} ${h - 175}
                Q ${w / 2} ${h - 180} ${w / 2 + 10} ${h - 175}
                Q ${w / 2 + 35} ${h - 165} ${w / 2 + 50} ${h - 140}
                Q ${w / 2 + 65} ${h - 110} ${w / 2 + 60} ${h - 70}
                Q ${w / 2 + 55} ${h - 40} ${w / 2 + 50} ${h}
                Z`}
            fill="url(#headstockGrad)"
            stroke="#1A1008"
            strokeWidth="1.5"
          />

          {/* Nut */}
          <rect
            x={w / 2 - 55}
            y={h - 14}
            width={110}
            height={6}
            rx={2}
            fill="#F5F0E0"
            opacity={0.9}
          />

          {/* Left pegs (E2, A2, D3) */}
          {leftPegs.map((note, i) => {
            const pegY = h - 60 - i * 38
            const pegX = w / 2 - 52
            const rot = getPegRotation(note)
            const color = getStringColor(note)
            return (
              <g key={`lpeg-${note}`}>
                {/* Peg shaft */}
                <line
                  x1={pegX - 20}
                  y1={pegY}
                  x2={pegX}
                  y2={pegY}
                  stroke="#888"
                  strokeWidth={3}
                />
                {/* Peg button */}
                <g
                  transform={`rotate(${rot} ${pegX - 24} ${pegY})`}
                  filter="url(#pegShadow)"
                >
                  <ellipse
                    cx={pegX - 28}
                    cy={pegY}
                    rx={8}
                    ry={5}
                    fill="#C0C0C0"
                    stroke="#999"
                    strokeWidth={0.5}
                  />
                  <line
                    x1={pegX - 36}
                    y1={pegY}
                    x2={pegX - 20}
                    y2={pegY}
                    stroke="#A0A0A0"
                    strokeWidth={2}
                  />
                </g>
                {/* String from peg to nut */}
                <line
                  x1={pegX}
                  y1={pegY}
                  x2={startX + i * stringSpacing}
                  y2={h - 11}
                  stroke={color}
                  strokeWidth={1.8 - i * 0.2}
                  className={getStringVibClass(note)}
                  opacity={0.85}
                />
                {/* Note label */}
                <text
                  x={pegX - 42}
                  y={pegY + 4}
                  fill={targetNote === note ? color : '#888'}
                  fontSize="9"
                  fontFamily="monospace"
                  textAnchor="end"
                  fontWeight={targetNote === note ? 'bold' : 'normal'}
                >
                  {note}
                </text>
              </g>
            )
          })}

          {/* Right pegs (G3, B3, E4) */}
          {rightPegs.map((note, i) => {
            const pegY = h - 60 - i * 38
            const pegX = w / 2 + 52
            const rot = getPegRotation(note)
            const color = getStringColor(note)
            return (
              <g key={`rpeg-${note}`}>
                {/* Peg shaft */}
                <line
                  x1={pegX}
                  y1={pegY}
                  x2={pegX + 20}
                  y2={pegY}
                  stroke="#888"
                  strokeWidth={3}
                />
                {/* Peg button */}
                <g
                  transform={`rotate(${rot} ${pegX + 24} ${pegY})`}
                  filter="url(#pegShadow)"
                >
                  <ellipse
                    cx={pegX + 28}
                    cy={pegY}
                    rx={8}
                    ry={5}
                    fill="#C0C0C0"
                    stroke="#999"
                    strokeWidth={0.5}
                  />
                  <line
                    x1={pegX + 20}
                    y1={pegY}
                    x2={pegX + 36}
                    y2={pegY}
                    stroke="#A0A0A0"
                    strokeWidth={2}
                  />
                </g>
                {/* String from peg to nut */}
                <line
                  x1={pegX}
                  y1={pegY}
                  x2={startX + (i + 3) * stringSpacing}
                  y2={h - 11}
                  stroke={color}
                  strokeWidth={1.2 - i * 0.15}
                  className={getStringVibClass(note)}
                  opacity={0.85}
                />
                {/* Note label */}
                <text
                  x={pegX + 42}
                  y={pegY + 4}
                  fill={targetNote === note ? color : '#888'}
                  fontSize="9"
                  fontFamily="monospace"
                  textAnchor="start"
                  fontWeight={targetNote === note ? 'bold' : 'normal'}
                >
                  {note}
                </text>
              </g>
            )
          })}

          {/* Strings going down from nut */}
          {notes.map((note, i) => {
            const color = getStringColor(note)
            const sx = startX + i * stringSpacing
            return (
              <line
                key={`str-${note}`}
                x1={sx}
                y1={h - 8}
                x2={sx}
                y2={h + 2}
                stroke={color}
                strokeWidth={2 - i * 0.2}
                className={getStringVibClass(note)}
                opacity={0.7}
              />
            )
          })}
        </svg>
      </div>
    )
  }

  // Bass: 4 strings, 2+2 peg arrangement
  const leftPegs = [notes[0], notes[1]] // E1, A1
  const rightPegs = [notes[2], notes[3]] // D2, G2
  const stringSpacing = 28
  const startX = w / 2 - (3 * stringSpacing) / 2

  return (
    <div className="flex justify-center mb-2">
      <svg viewBox={`0 0 ${w} ${h}`} className="w-full max-w-[320px]">
        <defs>
          <linearGradient id="headstockGradBass" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#3D2B1F" />
            <stop offset="50%" stopColor="#2A1D13" />
            <stop offset="100%" stopColor="#1A1008" />
          </linearGradient>
          <filter id="pegShadowBass">
            <feDropShadow dx="0" dy="1" stdDeviation="1" floodColor="#000" floodOpacity="0.5" />
          </filter>
          <style>{`
            @keyframes stringVib {
              0%, 100% { transform: translateX(0); }
              25% { transform: translateX(-0.7px); }
              75% { transform: translateX(0.7px); }
            }
          `}</style>
        </defs>

        {/* Headstock body */}
        <path
          d={`M ${w / 2 - 45} ${h}
              Q ${w / 2 - 50} ${h - 35} ${w / 2 - 55} ${h - 65}
              Q ${w / 2 - 58} ${h - 100} ${w / 2 - 45} ${h - 125}
              Q ${w / 2 - 30} ${h - 150} ${w / 2} ${h - 160}
              Q ${w / 2 + 30} ${h - 150} ${w / 2 + 45} ${h - 125}
              Q ${w / 2 + 58} ${h - 100} ${w / 2 + 55} ${h - 65}
              Q ${w / 2 + 50} ${h - 35} ${w / 2 + 45} ${h}
              Z`}
          fill="url(#headstockGradBass)"
          stroke="#1A1008"
          strokeWidth="1.5"
        />

        {/* Nut */}
        <rect
          x={w / 2 - 50}
          y={h - 14}
          width={100}
          height={6}
          rx={2}
          fill="#F5F0E0"
          opacity={0.9}
        />

        {/* Left pegs (E1, A1) */}
        {leftPegs.map((note, i) => {
          const pegY = h - 60 - i * 45
          const pegX = w / 2 - 48
          const rot = getPegRotation(note)
          const color = getStringColor(note)
          return (
            <g key={`lpeg-${note}`}>
              <line x1={pegX - 22} y1={pegY} x2={pegX} y2={pegY} stroke="#888" strokeWidth={3.5} />
              <g transform={`rotate(${rot} ${pegX - 26} ${pegY})`} filter="url(#pegShadowBass)">
                <ellipse cx={pegX - 30} cy={pegY} rx={9} ry={6} fill="#C0C0C0" stroke="#999" strokeWidth={0.5} />
                <line x1={pegX - 39} y1={pegY} x2={pegX - 21} y2={pegY} stroke="#A0A0A0" strokeWidth={2.5} />
              </g>
              <line
                x1={pegX}
                y1={pegY}
                x2={startX + i * stringSpacing}
                y2={h - 11}
                stroke={color}
                strokeWidth={2.5 - i * 0.3}
                className={getStringVibClass(note)}
                opacity={0.85}
              />
              <text
                x={pegX - 44}
                y={pegY + 4}
                fill={targetNote === note ? color : '#888'}
                fontSize="9"
                fontFamily="monospace"
                textAnchor="end"
                fontWeight={targetNote === note ? 'bold' : 'normal'}
              >
                {note}
              </text>
            </g>
          )
        })}

        {/* Right pegs (D2, G2) */}
        {rightPegs.map((note, i) => {
          const pegY = h - 60 - i * 45
          const pegX = w / 2 + 48
          const rot = getPegRotation(note)
          const color = getStringColor(note)
          return (
            <g key={`rpeg-${note}`}>
              <line x1={pegX} y1={pegY} x2={pegX + 22} y2={pegY} stroke="#888" strokeWidth={3.5} />
              <g transform={`rotate(${rot} ${pegX + 26} ${pegY})`} filter="url(#pegShadowBass)">
                <ellipse cx={pegX + 30} cy={pegY} rx={9} ry={6} fill="#C0C0C0" stroke="#999" strokeWidth={0.5} />
                <line x1={pegX + 21} y1={pegY} x2={pegX + 39} y2={pegY} stroke="#A0A0A0" strokeWidth={2.5} />
              </g>
              <line
                x1={pegX}
                y1={pegY}
                x2={startX + (i + 2) * stringSpacing}
                y2={h - 11}
                stroke={color}
                strokeWidth={2 - i * 0.3}
                className={getStringVibClass(note)}
                opacity={0.85}
              />
              <text
                x={pegX + 44}
                y={pegY + 4}
                fill={targetNote === note ? color : '#888'}
                fontSize="9"
                fontFamily="monospace"
                textAnchor="start"
                fontWeight={targetNote === note ? 'bold' : 'normal'}
              >
                {note}
              </text>
            </g>
          )
        })}

        {/* Strings going down from nut */}
        {notes.map((note, i) => {
          const color = getStringColor(note)
          const sx = startX + i * stringSpacing
          return (
            <line
              key={`str-${note}`}
              x1={sx}
              y1={h - 8}
              x2={sx}
              y2={h + 2}
              stroke={color}
              strokeWidth={2.8 - i * 0.4}
              className={getStringVibClass(note)}
              opacity={0.7}
            />
          )
        })}
      </svg>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Professional Gauge SVG                                             */
/* ------------------------------------------------------------------ */

function GaugeSVG({ cents, inTune }: { cents: number; inTune: boolean }) {
  const r = 130
  const cx = 160
  const cy = 160
  const startAngle = -135
  const endAngle = 135
  const totalRange = endAngle - startAngle

  // Arc path helper
  function describeArc(startA: number, endA: number, radius: number) {
    const s = (startA * Math.PI) / 180
    const e = (endA * Math.PI) / 180
    const x1 = cx + radius * Math.cos(s)
    const y1 = cy + radius * Math.sin(s)
    const x2 = cx + radius * Math.cos(e)
    const y2 = cy + radius * Math.sin(e)
    const largeArc = endA - startA > 180 ? 1 : 0
    return `M ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2}`
  }

  // Needle angle
  const clamped = Math.max(-50, Math.min(50, cents))
  const needleAngle = startAngle + ((clamped + 50) / 100) * totalRange
  const needleRad = (needleAngle * Math.PI) / 180
  const needleLen = r - 12

  // Tapered needle points
  const tipX = cx + needleLen * Math.cos(needleRad)
  const tipY = cy + needleLen * Math.sin(needleRad)
  const perpRad = needleRad + Math.PI / 2
  const baseW = 4
  const bx1 = cx + baseW * Math.cos(perpRad)
  const by1 = cy + baseW * Math.sin(perpRad)
  const bx2 = cx - baseW * Math.cos(perpRad)
  const by2 = cy - baseW * Math.sin(perpRad)

  const needleColor = inTune ? '#00FF11' : Math.abs(cents) < 15 ? '#FF9500' : '#FF3B30'

  // Zone arcs (in cents mapped to angle)
  const centToAngle = (c: number) => startAngle + ((c + 50) / 100) * totalRange

  // Generate tick marks every 2 cents
  const ticks = []
  for (let c = -50; c <= 50; c += 2) {
    const angle = centToAngle(c)
    const rad = (angle * Math.PI) / 180
    const isMajor = c % 10 === 0
    const isMid = c % 5 === 0 && !isMajor
    const inner = r - (isMajor ? 26 : isMid ? 22 : 18)
    const outer = r - 14
    ticks.push(
      <line
        key={`tick-${c}`}
        x1={cx + inner * Math.cos(rad)}
        y1={cy + inner * Math.sin(rad)}
        x2={cx + outer * Math.cos(rad)}
        y2={cy + outer * Math.sin(rad)}
        stroke={c === 0 ? '#00FF11' : isMajor ? '#8E8E93' : '#444444'}
        strokeWidth={isMajor ? 2 : isMid ? 1.2 : 0.6}
      />
    )
  }

  return (
    <svg viewBox="0 0 320 220" className="w-full max-w-[360px]">
      <defs>
        {/* Colored zone gradients */}
        <linearGradient id="gaugeGradPro" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#FF3B30" />
          <stop offset="20%" stopColor="#FF3B30" />
          <stop offset="30%" stopColor="#FF9500" />
          <stop offset="40%" stopColor="#FF9500" />
          <stop offset="45%" stopColor="#FFD60A" />
          <stop offset="50%" stopColor="#00FF11" />
          <stop offset="55%" stopColor="#FFD60A" />
          <stop offset="60%" stopColor="#FF9500" />
          <stop offset="70%" stopColor="#FF9500" />
          <stop offset="80%" stopColor="#FF3B30" />
          <stop offset="100%" stopColor="#FF3B30" />
        </linearGradient>

        <filter id="needleGlowPro">
          <feGaussianBlur stdDeviation="3" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>

        <filter id="needleDropShadow">
          <feDropShadow dx="1" dy="2" stdDeviation="2" floodColor="#000" floodOpacity="0.6" />
        </filter>

        {inTune && (
          <filter id="inTuneHalo">
            <feGaussianBlur stdDeviation="6" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        )}

        <filter id="lcdGlow">
          <feGaussianBlur stdDeviation="2" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      {/* Background arc */}
      <path
        d={describeArc(startAngle, endAngle, r)}
        fill="none"
        stroke="#1A1A1A"
        strokeWidth="16"
        strokeLinecap="round"
      />

      {/* Color zone arcs */}
      {/* Red zone left: -50 to -30 */}
      <path
        d={describeArc(centToAngle(-50), centToAngle(-30), r)}
        fill="none"
        stroke="#FF3B30"
        strokeWidth="10"
        strokeLinecap="butt"
        opacity={0.5}
      />
      {/* Orange zone left: -30 to -15 */}
      <path
        d={describeArc(centToAngle(-30), centToAngle(-15), r)}
        fill="none"
        stroke="#FF9500"
        strokeWidth="10"
        strokeLinecap="butt"
        opacity={0.5}
      />
      {/* Yellow zone left: -15 to -5 */}
      <path
        d={describeArc(centToAngle(-15), centToAngle(-5), r)}
        fill="none"
        stroke="#FFD60A"
        strokeWidth="10"
        strokeLinecap="butt"
        opacity={0.4}
      />
      {/* Green center: -5 to +5 */}
      <path
        d={describeArc(centToAngle(-5), centToAngle(5), r)}
        fill="none"
        stroke="#00FF11"
        strokeWidth="12"
        strokeLinecap="butt"
        opacity={0.8}
      />
      {/* Yellow zone right: +5 to +15 */}
      <path
        d={describeArc(centToAngle(5), centToAngle(15), r)}
        fill="none"
        stroke="#FFD60A"
        strokeWidth="10"
        strokeLinecap="butt"
        opacity={0.4}
      />
      {/* Orange zone right: +15 to +30 */}
      <path
        d={describeArc(centToAngle(15), centToAngle(30), r)}
        fill="none"
        stroke="#FF9500"
        strokeWidth="10"
        strokeLinecap="butt"
        opacity={0.5}
      />
      {/* Red zone right: +30 to +50 */}
      <path
        d={describeArc(centToAngle(30), centToAngle(50), r)}
        fill="none"
        stroke="#FF3B30"
        strokeWidth="10"
        strokeLinecap="butt"
        opacity={0.5}
      />

      {/* Tick marks every 2 cents */}
      {ticks}

      {/* Labels */}
      <text x="28" y="198" fill="#8E8E93" fontSize="10" fontFamily="monospace">-50</text>
      <text x="66" y="115" fill="#666" fontSize="9" fontFamily="monospace">-30</text>
      <text x={cx} y="44" fill="#00FF11" fontSize="11" fontFamily="monospace" textAnchor="middle" fontWeight="bold">0</text>
      <text x="242" y="115" fill="#666" fontSize="9" fontFamily="monospace">+30</text>
      <text x="272" y="198" fill="#8E8E93" fontSize="10" fontFamily="monospace">+50</text>

      {/* Tapered needle with drop shadow */}
      <polygon
        points={`${tipX},${tipY} ${bx1},${by1} ${bx2},${by2}`}
        fill={needleColor}
        filter={inTune ? 'url(#inTuneHalo)' : 'url(#needleDropShadow)'}
        opacity={0.95}
      />

      {/* Needle glow line overlay */}
      <line
        x1={cx}
        y1={cy}
        x2={tipX}
        y2={tipY}
        stroke={needleColor}
        strokeWidth="1"
        filter="url(#needleGlowPro)"
        opacity={0.5}
      />

      {/* Center hub */}
      <circle cx={cx} cy={cy} r="8" fill="#2A2A2A" stroke={needleColor} strokeWidth="1.5" />
      <circle cx={cx} cy={cy} r="3" fill={needleColor} opacity={0.8} />
    </svg>
  )
}

/* ------------------------------------------------------------------ */
/*  LCD Cent Display                                                   */
/* ------------------------------------------------------------------ */

function LcdCentDisplay({ cents, detectedNote, inTune }: { cents: number; detectedNote: string | null; inTune: boolean }) {
  const centsStr = cents >= 0 ? `+${Math.round(cents)}` : `${Math.round(cents)}`
  const color = !detectedNote
    ? '#555'
    : inTune
      ? '#00FF11'
      : Math.abs(cents) < 15
        ? '#FF9500'
        : '#FF3B30'

  return (
    <div
      className="relative mx-auto px-5 py-2 rounded-lg border"
      style={{
        background: 'linear-gradient(180deg, #0D0D0D 0%, #141414 100%)',
        borderColor: '#2A2A2A',
        boxShadow: inTune
          ? '0 0 20px rgba(0, 255, 17, 0.15), inset 0 1px 3px rgba(0,0,0,0.5)'
          : 'inset 0 1px 3px rgba(0,0,0,0.5)',
      }}
    >
      <span
        className="text-3xl font-mono font-bold tabular-nums tracking-wider"
        style={{
          color,
          textShadow: detectedNote
            ? `0 0 10px ${color}66, 0 0 20px ${color}33`
            : 'none',
        }}
      >
        {detectedNote ? `${centsStr}` : '--'}
      </span>
      <span
        className="text-lg font-mono ml-0.5"
        style={{ color: `${color}99` }}
      >
        {'\u00A2'}
      </span>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Segmented LED dB Meter                                             */
/* ------------------------------------------------------------------ */

function LedDbMeter({ dbNorm, peakHold }: { dbNorm: number; peakHold: number }) {
  const segments = 20

  return (
    <div className="flex flex-col-reverse gap-[2px] w-5">
      {Array.from({ length: segments }, (_, i) => {
        const segNorm = (i + 1) / segments
        const isLit = dbNorm >= segNorm - 1 / segments
        const isPeak = Math.abs(peakHold - segNorm) < 1 / segments && peakHold > 0.05

        // Color zones: 0-60% green, 60-85% yellow, 85-100% red
        let segColor: string
        if (segNorm > 0.85) {
          segColor = '#FF3B30'
        } else if (segNorm > 0.6) {
          segColor = '#FF9500'
        } else {
          segColor = '#00FF11'
        }

        return (
          <div
            key={i}
            className="w-full h-[6px] rounded-[1px] transition-opacity duration-75"
            style={{
              backgroundColor: isLit || isPeak ? segColor : '#1A1A1A',
              opacity: isLit ? 1 : isPeak ? 0.9 : 0.3,
              boxShadow: isLit ? `0 0 4px ${segColor}44` : 'none',
            }}
          />
        )
      })}
      <span className="text-[7px] text-gl-dim font-mono text-center">dB</span>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Enhanced Strobe bands component                                    */
/* ------------------------------------------------------------------ */

function StrobeBands({ cents, active }: { cents: number; active: boolean }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const offsetRef = useRef([0, 0, 0])
  const rafRef = useRef(0)

  useEffect(() => {
    if (!active) return
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let lastTime = performance.now()

    const draw = (time: number) => {
      const dt = (time - lastTime) / 16.67 // normalize to ~60fps
      lastTime = time

      const w = canvas.width
      const h = canvas.height
      ctx.fillStyle = '#0A0A0A'
      ctx.fillRect(0, 0, w, h)

      const speed = cents * 0.6
      const inTune = Math.abs(cents) < 3
      const bandCount = 3 // parallax layers

      for (let band = 0; band < bandCount; band++) {
        const layerSpeed = speed * (1 + band * 0.5) * dt
        offsetRef.current[band] += layerSpeed
        if (Math.abs(offsetRef.current[band]) > 2000) offsetRef.current[band] %= 2000

        const bandWidth = 14 + band * 6
        const numBands = Math.ceil(w / bandWidth) + 6
        const bandH = h / bandCount
        const bandY = band * bandH

        // Color gradient from center to edge
        const baseAlpha = inTune ? 0.85 : 0.6
        const layerAlpha = baseAlpha - band * 0.15

        for (let i = -3; i < numBands; i++) {
          const x = i * bandWidth * 2 + (offsetRef.current[band] % (bandWidth * 2))

          // Distance from center for color gradient
          const centerDist = Math.abs(x + bandWidth / 2 - w / 2) / (w / 2)
          const r = inTune ? 0 : Math.min(255, Math.floor(255 * centerDist))
          const g = inTune ? 255 : Math.max(0, Math.floor(255 * (1 - centerDist * 0.7)))
          const b = inTune ? 17 : 0

          ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${layerAlpha})`
          ctx.fillRect(x, bandY, bandWidth, bandH)
        }
      }

      // Subtle scanline overlay
      ctx.fillStyle = 'rgba(0, 0, 0, 0.1)'
      for (let y = 0; y < h; y += 3) {
        ctx.fillRect(0, y, w, 1)
      }

      rafRef.current = requestAnimationFrame(draw)
    }

    rafRef.current = requestAnimationFrame(draw)
    return () => cancelAnimationFrame(rafRef.current)
  }, [cents, active])

  if (!active) return null

  return (
    <canvas
      ref={canvasRef}
      width={400}
      height={40}
      className="w-full h-10 rounded-md"
    />
  )
}

/* ------------------------------------------------------------------ */
/*  Main Tuner component                                               */
/* ------------------------------------------------------------------ */

export default function Tuner() {
  /* State */
  const [isListening, setIsListening] = useState(false)
  const [detectedNote, setDetectedNote] = useState<string | null>(null)
  const [detectedOctave, setDetectedOctave] = useState<number | null>(null)
  const [cents, setCents] = useState(0)
  const [frequency, setFrequency] = useState(0)
  const [dB, setDB] = useState(MIN_DB)
  const [stroboMode, setStroboMode] = useState(false)
  const [refToneFreq, setRefToneFreq] = useState(440)
  const [refToneWave, setRefToneWave] = useState<WaveformType>('sine')
  const [refTonePlaying, setRefTonePlaying] = useState(false)
  const [preset, setPreset] = useState<string>('chromatic')
  const [_pitchHistory, setPitchHistory] = useState<number[]>([])
  const [peakDb, setPeakDb] = useState(0)

  /* Refs */
  const micRef = useRef<Tone.UserMedia | null>(null)
  const analyserRef = useRef<AnalyserNode | null>(null)
  const rafRef = useRef(0)
  const waveCanvasRef = useRef<HTMLCanvasElement>(null)
  const historyCanvasRef = useRef<HTMLCanvasElement>(null)
  const synthRef = useRef<Tone.Synth | null>(null)
  const pitchHistoryRef = useRef<number[]>([])
  const peakHoldRef = useRef(0)
  const peakDecayRef = useRef(0)

  const inTune = detectedNote !== null && Math.abs(cents) < 5

  /* ---- Start / Stop listening ---- */
  const startListening = useCallback(async () => {
    await Tone.start()
    const mic = new Tone.UserMedia()
    await mic.open()

    const ctx = Tone.getContext().rawContext as AudioContext
    const analyser = ctx.createAnalyser()
    analyser.fftSize = FFT_SIZE
    analyser.smoothingTimeConstant = SMOOTHING

    // Connect Tone.UserMedia output to native analyser
    const micOutput = mic.output as unknown as AudioNode
    micOutput.connect(analyser)

    micRef.current = mic
    analyserRef.current = analyser
    setIsListening(true)
  }, [])

  const stopListening = useCallback(() => {
    if (micRef.current) {
      micRef.current.close()
      micRef.current.dispose()
      micRef.current = null
    }
    analyserRef.current = null
    cancelAnimationFrame(rafRef.current)
    setIsListening(false)
    setDetectedNote(null)
    setDetectedOctave(null)
    setCents(0)
    setFrequency(0)
    setDB(MIN_DB)
    setPitchHistory([])
    setPeakDb(0)
    pitchHistoryRef.current = []
    peakHoldRef.current = 0
    peakDecayRef.current = 0
  }, [])

  /* ---- Analysis loop ---- */
  useEffect(() => {
    if (!isListening || !analyserRef.current) return

    const analyser = analyserRef.current
    const bufferLength = analyser.fftSize
    const dataArray = new Float32Array(bufferLength)
    const byteArray = new Uint8Array(analyser.frequencyBinCount)

    const loop = () => {
      analyser.getFloatTimeDomainData(dataArray)

      // RMS -> dB
      let rms = 0
      for (let i = 0; i < dataArray.length; i++) rms += dataArray[i] * dataArray[i]
      rms = Math.sqrt(rms / dataArray.length)
      const dbVal = rms > 0 ? 20 * Math.log10(rms) : MIN_DB
      const clampedDb = Math.max(MIN_DB, Math.min(MAX_DB, dbVal))
      setDB(clampedDb)

      // Peak hold
      const dbNormVal = Math.max(0, Math.min(1, (clampedDb - MIN_DB) / (MAX_DB - MIN_DB)))
      if (dbNormVal > peakHoldRef.current) {
        peakHoldRef.current = dbNormVal
        peakDecayRef.current = 0
      } else {
        peakDecayRef.current++
        if (peakDecayRef.current > 30) {
          peakHoldRef.current = Math.max(peakHoldRef.current - 0.01, 0)
        }
      }
      setPeakDb(peakHoldRef.current)

      // Pitch detection
      const freq = autoCorrelate(dataArray, analyser.context.sampleRate)
      if (freq > 30 && freq < 5000) {
        const note = frequencyToNote(freq, refToneFreq)
        setFrequency(Math.round(freq * 10) / 10)
        setDetectedNote(note.name)
        setDetectedOctave(note.octave)
        setCents(note.cents)

        pitchHistoryRef.current = [
          ...pitchHistoryRef.current.slice(-(HISTORY_LEN - 1)),
          note.cents,
        ]
        setPitchHistory([...pitchHistoryRef.current])
      }

      // Draw waveform - enhanced with gradient fill and grid
      const waveCanvas = waveCanvasRef.current
      if (waveCanvas) {
        const ctx = waveCanvas.getContext('2d')
        if (ctx) {
          analyser.getByteTimeDomainData(byteArray)
          const w = waveCanvas.width
          const h = waveCanvas.height

          ctx.fillStyle = '#0A0A0A'
          ctx.fillRect(0, 0, w, h)

          // Grid lines
          ctx.strokeStyle = '#1A1A1A'
          ctx.lineWidth = 0.5
          // Horizontal grid
          for (let y = 0; y < h; y += h / 6) {
            ctx.beginPath()
            ctx.moveTo(0, y)
            ctx.lineTo(w, y)
            ctx.stroke()
          }
          // Vertical grid
          for (let x = 0; x < w; x += w / 10) {
            ctx.beginPath()
            ctx.moveTo(x, 0)
            ctx.lineTo(x, h)
            ctx.stroke()
          }

          // Center line
          ctx.strokeStyle = '#333333'
          ctx.lineWidth = 0.5
          ctx.beginPath()
          ctx.moveTo(0, h / 2)
          ctx.lineTo(w, h / 2)
          ctx.stroke()

          // Build waveform path
          const sliceWidth = w / byteArray.length
          const points: [number, number][] = []
          let x = 0
          for (let i = 0; i < byteArray.length; i++) {
            const v = byteArray[i] / 128.0
            const y = (v * h) / 2
            points.push([x, y])
            x += sliceWidth
          }

          // Gradient fill under waveform
          const grad = ctx.createLinearGradient(0, 0, 0, h)
          grad.addColorStop(0, 'rgba(0, 229, 255, 0.15)')
          grad.addColorStop(0.5, 'rgba(0, 229, 255, 0.03)')
          grad.addColorStop(1, 'rgba(0, 229, 255, 0.15)')

          ctx.beginPath()
          ctx.moveTo(0, h / 2)
          for (const [px, py] of points) {
            ctx.lineTo(px, py)
          }
          ctx.lineTo(w, h / 2)
          ctx.closePath()
          ctx.fillStyle = grad
          ctx.fill()

          // Waveform line
          ctx.lineWidth = 1.5
          ctx.strokeStyle = '#00E5FF'
          ctx.beginPath()
          for (let i = 0; i < points.length; i++) {
            if (i === 0) ctx.moveTo(points[i][0], points[i][1])
            else ctx.lineTo(points[i][0], points[i][1])
          }
          ctx.stroke()

          // Frequency label overlay
          if (freq > 30 && freq < 5000) {
            ctx.fillStyle = 'rgba(0, 229, 255, 0.6)'
            ctx.font = '10px monospace'
            ctx.fillText(`${Math.round(freq)} Hz`, 6, 14)
          }
        }
      }

      // Draw pitch history - enhanced with gradient line and bezier smoothing
      const histCanvas = historyCanvasRef.current
      if (histCanvas && pitchHistoryRef.current.length > 1) {
        const ctx = histCanvas.getContext('2d')
        if (ctx) {
          const w = histCanvas.width
          const h = histCanvas.height
          ctx.fillStyle = '#121212'
          ctx.fillRect(0, 0, w, h)

          // Grid lines
          ctx.strokeStyle = '#1A1A1A'
          ctx.lineWidth = 0.5
          for (let y = 0; y <= h; y += h / 4) {
            ctx.beginPath()
            ctx.moveTo(0, y)
            ctx.lineTo(w, y)
            ctx.stroke()
          }

          // Zero line
          ctx.strokeStyle = '#444444'
          ctx.lineWidth = 1
          ctx.setLineDash([4, 4])
          ctx.beginPath()
          ctx.moveTo(0, h / 2)
          ctx.lineTo(w, h / 2)
          ctx.stroke()
          ctx.setLineDash([])

          // +/-5 cent zone shaded green
          const zone5Top = h / 2 - (5 / 50) * (h / 2)
          const zone5Bottom = h / 2 + (5 / 50) * (h / 2)
          const zoneGrad = ctx.createLinearGradient(0, zone5Top, 0, zone5Bottom)
          zoneGrad.addColorStop(0, 'rgba(0, 255, 17, 0.05)')
          zoneGrad.addColorStop(0.5, 'rgba(0, 255, 17, 0.12)')
          zoneGrad.addColorStop(1, 'rgba(0, 255, 17, 0.05)')
          ctx.fillStyle = zoneGrad
          ctx.fillRect(0, zone5Top, w, zone5Bottom - zone5Top)

          // Zone border lines
          ctx.strokeStyle = 'rgba(0, 255, 17, 0.2)'
          ctx.lineWidth = 0.5
          ctx.beginPath()
          ctx.moveTo(0, zone5Top)
          ctx.lineTo(w, zone5Top)
          ctx.stroke()
          ctx.beginPath()
          ctx.moveTo(0, zone5Bottom)
          ctx.lineTo(w, zone5Bottom)
          ctx.stroke()

          // History line with gradient color and bezier smoothing
          const hist = pitchHistoryRef.current
          const step = w / (HISTORY_LEN - 1)
          const offset = HISTORY_LEN - hist.length

          if (hist.length > 2) {
            // Build points
            const pts: [number, number][] = hist.map((c, i) => [
              (offset + i) * step,
              h / 2 - (c / 50) * (h / 2),
            ])

            // Draw line segments with per-segment color
            ctx.lineWidth = 2
            for (let i = 0; i < pts.length - 1; i++) {
              const c = Math.abs(hist[i])
              // Green when near 0, orange when moderate, red when far
              let r = 0, g = 255, b = 17
              if (c > 5) {
                const t = Math.min(1, (c - 5) / 35)
                r = Math.floor(255 * t)
                g = Math.floor(255 * (1 - t * 0.5))
                b = Math.floor(17 * (1 - t))
              }
              ctx.strokeStyle = `rgb(${r}, ${g}, ${b})`

              ctx.beginPath()
              ctx.moveTo(pts[i][0], pts[i][1])

              // Bezier interpolation for smooth curves
              if (i < pts.length - 2) {
                const cpx = (pts[i][0] + pts[i + 1][0]) / 2
                const cpy1 = pts[i][1]
                const cpy2 = pts[i + 1][1]
                ctx.bezierCurveTo(cpx, cpy1, cpx, cpy2, pts[i + 1][0], pts[i + 1][1])
              } else {
                ctx.lineTo(pts[i + 1][0], pts[i + 1][1])
              }
              ctx.stroke()
            }

            // Dot at current position
            const lastPt = pts[pts.length - 1]
            const lastC = Math.abs(hist[hist.length - 1])
            const dotColor = lastC < 5 ? '#00FF11' : lastC < 15 ? '#FF9500' : '#FF3B30'
            ctx.fillStyle = dotColor
            ctx.beginPath()
            ctx.arc(lastPt[0], lastPt[1], 3, 0, Math.PI * 2)
            ctx.fill()

            // Glow on dot
            ctx.fillStyle = `${dotColor}44`
            ctx.beginPath()
            ctx.arc(lastPt[0], lastPt[1], 6, 0, Math.PI * 2)
            ctx.fill()
          }

          // Labels
          ctx.fillStyle = '#555'
          ctx.font = '9px monospace'
          ctx.fillText('+50', 4, 12)
          ctx.fillText('0', 4, h / 2 + 3)
          ctx.fillText('-50', 4, h - 4)
        }
      }

      rafRef.current = requestAnimationFrame(loop)
    }

    rafRef.current = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(rafRef.current)
  }, [isListening, refToneFreq])

  /* ---- Reference tone ---- */
  const toggleRefTone = useCallback(() => {
    if (refTonePlaying) {
      if (synthRef.current) {
        synthRef.current.triggerRelease()
        synthRef.current.dispose()
        synthRef.current = null
      }
      setRefTonePlaying(false)
    } else {
      const synth = new Tone.Synth({
        oscillator: { type: refToneWave },
        envelope: { attack: 0.05, decay: 0, sustain: 1, release: 0.1 },
        volume: -12,
      }).toDestination()
      synth.triggerAttack(refToneFreq)
      synthRef.current = synth
      setRefTonePlaying(true)
    }
  }, [refTonePlaying, refToneFreq, refToneWave])

  // Update running ref tone when wave/freq changes
  useEffect(() => {
    if (refTonePlaying && synthRef.current) {
      synthRef.current.frequency.rampTo(refToneFreq, 0.05)
    }
  }, [refToneFreq, refTonePlaying])

  useEffect(() => {
    if (refTonePlaying && synthRef.current) {
      synthRef.current.oscillator.type = refToneWave
    }
  }, [refToneWave, refTonePlaying])

  /* ---- Cleanup ---- */
  useEffect(() => {
    return () => {
      stopListening()
      if (synthRef.current) {
        synthRef.current.triggerRelease()
        synthRef.current.dispose()
      }
    }
  }, [stopListening])

  /* ---- Helpers ---- */
  const dbNorm = Math.max(0, Math.min(1, (dB - MIN_DB) / (MAX_DB - MIN_DB)))
  const presetNotes = PRESETS[preset]?.notes ?? []

  /* ---- Target note for preset mode ---- */
  const targetNote = useMemo(() => {
    if (preset === 'chromatic' || !detectedNote || detectedOctave === null) return null
    const current = `${detectedNote}${detectedOctave}`
    const currentFreq = noteNameToFreq(current, refToneFreq)
    let closest = presetNotes[0]
    let closestDist = Infinity
    for (const pn of presetNotes) {
      const pFreq = noteNameToFreq(pn, refToneFreq)
      const dist = Math.abs(1200 * Math.log2(currentFreq / pFreq))
      if (dist < closestDist) {
        closestDist = dist
        closest = pn
      }
    }
    return closest
  }, [preset, detectedNote, detectedOctave, presetNotes, refToneFreq])

  const showHeadstock = (preset === 'guitar' || preset === 'bass') && presetNotes.length > 0

  /* ---------------------------------------------------------------- */
  /*  Render                                                           */
  /* ---------------------------------------------------------------- */

  return (
    <div className="flex flex-col gap-4 p-4 max-w-md mx-auto select-none">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-gl-text tracking-wide">Tuner</h2>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setStroboMode(!stroboMode)}
            className={cn(
              'px-3 py-1 rounded-md text-xs font-mono transition-colors',
              stroboMode
                ? 'bg-gl-accent/20 text-gl-accent border border-gl-accent/40'
                : 'bg-gl-surface text-gl-muted border border-gl-border'
            )}
          >
            STROBE
          </button>
          <button
            onClick={isListening ? stopListening : startListening}
            className={cn(
              'px-4 py-1.5 rounded-lg text-sm font-semibold transition-all neu-raised',
              isListening
                ? 'bg-gl-danger/20 text-gl-danger border border-gl-danger/40'
                : 'bg-gl-green/20 text-gl-green border border-gl-green/40'
            )}
          >
            {isListening ? 'STOP' : 'START'}
          </button>
        </div>
      </div>

      {/* Preset selector */}
      <div className="flex gap-1.5">
        {Object.entries(PRESETS).map(([key, p]) => (
          <button
            key={key}
            onClick={() => setPreset(key)}
            className={cn(
              'flex-1 px-2 py-1.5 rounded-md text-xs font-mono transition-colors',
              preset === key
                ? 'bg-gl-accent/20 text-gl-accent border border-gl-accent/40'
                : 'bg-gl-surface text-gl-muted border border-gl-border hover:border-gl-dim'
            )}
          >
            {p.label}
          </button>
        ))}
      </div>

      {/* Preset string indicators */}
      {preset !== 'chromatic' && presetNotes.length > 0 && (
        <div className="flex gap-1.5 justify-center">
          {presetNotes.map((n) => (
            <div
              key={n}
              className={cn(
                'px-2.5 py-1 rounded text-xs font-mono border transition-all',
                targetNote === n && inTune
                  ? 'bg-gl-green/20 text-gl-green border-gl-green/50 glow-green'
                  : targetNote === n
                    ? 'bg-gl-warm/15 text-gl-warm border-gl-warm/40'
                    : 'bg-gl-surface text-gl-dim border-gl-border'
              )}
            >
              {n}
            </div>
          ))}
        </div>
      )}

      {/* Headstock visualization */}
      {showHeadstock && (
        <div className="bg-gl-dark rounded-2xl p-3 neu-inset overflow-hidden">
          <GuitarHeadstock
            notes={presetNotes}
            targetNote={targetNote}
            inTune={inTune}
            cents={cents}
            soundDetected={isListening && detectedNote !== null}
          />
        </div>
      )}

      {/* Main display area */}
      <div className="relative bg-gl-dark rounded-2xl p-4 neu-inset">
        {/* dB meter - segmented LED style */}
        <div className="absolute right-3 top-4 bottom-4">
          <LedDbMeter dbNorm={dbNorm} peakHold={peakDb} />
        </div>

        {/* Gauge */}
        <div className="flex justify-center pr-6">
          <GaugeSVG cents={detectedNote ? cents : 0} inTune={inTune} />
        </div>

        {/* Note name */}
        <div className="text-center -mt-4">
          <span
            className={cn(
              'text-6xl font-mono font-bold tracking-tight transition-colors',
              !detectedNote && 'text-gl-dim',
              detectedNote && inTune && 'text-gl-green',
              detectedNote && !inTune && Math.abs(cents) < 15 && 'text-gl-warm',
              detectedNote && !inTune && Math.abs(cents) >= 15 && 'text-gl-danger'
            )}
            style={{
              textShadow:
                detectedNote && inTune
                  ? '0 0 20px rgba(0, 255, 17, 0.4), 0 0 40px rgba(0, 255, 17, 0.2)'
                  : 'none',
            }}
          >
            {detectedNote ? `${detectedNote}${detectedOctave}` : '--'}
          </span>
        </div>

        {/* LCD Cent display */}
        <div className="mt-3">
          <LcdCentDisplay cents={cents} detectedNote={detectedNote} inTune={inTune} />
        </div>

        {/* Hz */}
        <div className="flex justify-center mt-2">
          <span className="text-sm font-mono text-gl-muted tabular-nums">
            {detectedNote ? `${frequency.toFixed(1)} Hz` : '--- Hz'}
          </span>
        </div>

        {/* Strobe mode */}
        {stroboMode && (
          <div className="mt-3">
            <StrobeBands cents={detectedNote ? cents : 0} active={stroboMode && isListening} />
          </div>
        )}
      </div>

      {/* Waveform */}
      <div className="bg-gl-dark rounded-xl p-3 neu-inset">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-[10px] text-gl-dim font-mono uppercase tracking-wider">Waveform</span>
        </div>
        <canvas
          ref={waveCanvasRef}
          width={400}
          height={90}
          className="w-full h-[72px] rounded-md bg-gl-deepest"
        />
      </div>

      {/* Pitch history */}
      <div className="bg-gl-dark rounded-xl p-3 neu-inset">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-[10px] text-gl-dim font-mono uppercase tracking-wider">
            Pitch History
          </span>
          <span className="text-[10px] text-gl-dim font-mono">{HISTORY_LEN} samples</span>
        </div>
        <canvas
          ref={historyCanvasRef}
          width={400}
          height={80}
          className="w-full h-16 rounded-md bg-gl-dark"
        />
      </div>

      {/* Reference Tone */}
      <div className="bg-gl-panel rounded-xl p-4 neu-raised">
        <div className="flex items-center justify-between mb-3">
          <span className="text-xs text-gl-muted font-mono uppercase tracking-wider">
            Reference Tone
          </span>
          <button
            onClick={toggleRefTone}
            className={cn(
              'px-3 py-1 rounded-md text-xs font-mono font-semibold transition-all',
              refTonePlaying
                ? 'bg-gl-accent/20 text-gl-accent border border-gl-accent/40 glow-accent'
                : 'bg-gl-surface text-gl-muted border border-gl-border'
            )}
          >
            {refTonePlaying ? 'STOP' : 'PLAY'}
          </button>
        </div>

        {/* Frequency slider */}
        <div className="mb-3">
          <div className="flex justify-between items-baseline mb-1">
            <span className="text-[10px] text-gl-dim font-mono">A4 Reference</span>
            <span className="text-sm font-mono text-gl-text tabular-nums">
              {refToneFreq.toFixed(1)} Hz
            </span>
          </div>
          <input
            type="range"
            min={430}
            max={450}
            step={0.1}
            value={refToneFreq}
            onChange={(e) => setRefToneFreq(parseFloat(e.target.value))}
            className="w-full h-2 rounded-lg appearance-none cursor-pointer bg-gl-surface accent-gl-accent"
          />
          <div className="flex justify-between text-[9px] text-gl-dim font-mono mt-0.5">
            <span>430</span>
            <span>440</span>
            <span>450</span>
          </div>
        </div>

        {/* Waveform selector */}
        <div className="flex gap-1.5">
          {(['sine', 'sawtooth', 'square', 'triangle'] as WaveformType[]).map((w) => (
            <button
              key={w}
              onClick={() => setRefToneWave(w)}
              className={cn(
                'flex-1 px-2 py-1.5 rounded-md text-[10px] font-mono uppercase transition-colors',
                refToneWave === w
                  ? 'bg-gl-accent/20 text-gl-accent border border-gl-accent/40'
                  : 'bg-gl-surface text-gl-dim border border-gl-border hover:border-gl-dim'
              )}
            >
              {w === 'sawtooth' ? 'SAW' : w === 'triangle' ? 'TRI' : w === 'square' ? 'SQR' : 'SIN'}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
