import type { PistaMultitrack, Repertorio } from '@/stores/multitrack-store'

export const PISTAS_DEFAULT: Omit<PistaMultitrack, 'audioBuffer' | 'waveformData'>[] = [
  { id: 'click', nombre: 'Click',   color: '#04C5F7', volumen: 85, muted: false, soloed: false, origen: 'click' },
  { id: 'guia',  nombre: 'Guia',    color: '#9B6BFF', volumen: 75, muted: false, soloed: false, origen: 'guia' },
  { id: 'bat',   nombre: 'Bateria', color: '#FF9020', volumen: 70, muted: false, soloed: false, origen: 'custom' },
  { id: 'loop',  nombre: 'Loop',    color: '#20CC60', volumen: 65, muted: false, soloed: false, origen: 'custom' },
  { id: 'bajo',  nombre: 'Bajo',    color: '#FFAA00', volumen: 72, muted: false, soloed: false, origen: 'custom' },
  { id: 'ge1',   nombre: 'GE 1',    color: '#FF3060', volumen: 68, muted: false, soloed: false, origen: 'custom' },
  { id: 'ge2',   nombre: 'GE 2',    color: '#9B6BFF', volumen: 65, muted: false, soloed: false, origen: 'custom' },
]

export const REPERTORIO_DEMO: Repertorio = {
  id: 'demo-domingo',
  nombre: 'Domingo',
  fecha: 'sept 21, 2025, 3:30 p.m.',
  updatedAt: Date.now(),
  canciones: [
    { id: 'c1', nombre: 'La Gloria De Dios', tonalidad: 'Ab', bpm: 70, duracion: 412, emoji: '\u267E\uFE0F',
      marcadores: [
        { id: 'm1', posicion: .05, etiqueta: 'Ci', color: '#04C5F7' },
        { id: 'm2', posicion: .22, etiqueta: 'I',  color: '#9B6BFF' },
        { id: 'm3', posicion: .45, etiqueta: 'V',  color: '#FF9020' },
        { id: 'm4', posicion: .68, etiqueta: 'Pr', color: '#FF3060' },
        { id: 'm5', posicion: .88, etiqueta: 'Rf', color: '#20CC60' },
      ] },
    { id: 'c2', nombre: 'Yahweh Se Manifestara', tonalidad: 'G', bpm: 78, duracion: 384, emoji: '\uD83D\uDC65', marcadores: [] },
    { id: 'c3', nombre: 'Digno de Adorar', tonalidad: 'D', bpm: 82, duracion: 356, emoji: '\uD83C\uDFA4', marcadores: [] },
    { id: 'c4', nombre: 'Creo En Ti', tonalidad: 'D', bpm: 74, duracion: 392, emoji: '\uD83D\uDD4A\uFE0F', marcadores: [] },
  ],
}
