import { useEffect, useCallback } from 'react'
import { useAppStore } from '@/stores/app-store'
import { audioEngine } from '@/stores/audio-engine'

/** Hook to ensure audio context is initialized on first user gesture */
export function useAudioInit() {
  const { audioInitialized, setAudioInitialized } = useAppStore()

  const initAudio = useCallback(async () => {
    if (!audioInitialized) {
      await audioEngine.init()
      setAudioInitialized(true)
    }
  }, [audioInitialized, setAudioInitialized])

  return { audioInitialized, initAudio }
}

/** Hook for requestAnimationFrame loop */
export function useAnimationFrame(callback: (time: number) => void, active: boolean) {
  useEffect(() => {
    if (!active) return
    let frameId: number
    const loop = (time: number) => {
      callback(time)
      frameId = requestAnimationFrame(loop)
    }
    frameId = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(frameId)
  }, [callback, active])
}
