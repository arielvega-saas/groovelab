import { Suspense, lazy, useEffect } from 'react'
import { Sidebar } from './Sidebar'
import { TopBar } from './TopBar'
import { useAppStore } from '@/stores/app-store'
import { audioEngine } from '@/stores/audio-engine'

const Metronome = lazy(() => import('@/features/metronome/Metronome'))
const Drums = lazy(() => import('@/features/drums/Drums'))
const SamplerPads = lazy(() => import('@/features/sampler-pads/SamplerPads'))
const Looper = lazy(() => import('@/features/looper/Looper'))
const Tuner = lazy(() => import('@/features/tuner/Tuner'))
const Pedalboard = lazy(() => import('@/features/pedalboard/Pedalboard'))
const SongLab = lazy(() => import('@/features/song-lab/SongLab'))
const Piano = lazy(() => import('@/features/piano/Piano'))

const TOOLS = {
  metronome: Metronome,
  drums: Drums,
  sampler: SamplerPads,
  looper: Looper,
  tuner: Tuner,
  pedalboard: Pedalboard,
  songlab: SongLab,
  piano: Piano,
} as const

function LoadingSpinner() {
  return (
    <div className="flex-1 flex items-center justify-center">
      <div className="w-8 h-8 border-2 border-gl-accent/30 border-t-gl-accent rounded-full animate-spin" />
    </div>
  )
}

export function AppShell() {
  const { activeTool, audioInitialized, setAudioInitialized } = useAppStore()
  const ActiveComponent = TOOLS[activeTool]

  useEffect(() => {
    const initAudio = async () => {
      if (!audioInitialized) {
        const handler = async () => {
          await audioEngine.init()
          setAudioInitialized(true)
          document.removeEventListener('click', handler)
          document.removeEventListener('touchstart', handler)
        }
        document.addEventListener('click', handler)
        document.addEventListener('touchstart', handler)
      }
    }
    initAudio()
  }, [audioInitialized, setAudioInitialized])

  return (
    <div className="h-dvh flex bg-gl-deepest text-gl-text overflow-hidden">
      <Sidebar />
      <div className="flex-1 flex flex-col lg:ml-[72px]">
        <TopBar />
        <main className="flex-1 overflow-y-auto p-4">
          <Suspense fallback={<LoadingSpinner />}>
            <ActiveComponent />
          </Suspense>
        </main>
      </div>
    </div>
  )
}
