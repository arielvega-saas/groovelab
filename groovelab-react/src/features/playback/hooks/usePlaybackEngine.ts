/**
 * usePlaybackEngine — Core audio playback hook for Multitracks Live
 *
 * Manages Tone.js Players per-track with synchronized transport,
 * per-track volume/mute/solo/pan, master volume, playhead updates,
 * and audio buffer loading. Designed for low-latency live performance.
 */
import { useCallback, useEffect, useRef } from 'react'
import * as Tone from 'tone'
import { usePlaybackStore } from '../store'
import { audioEngine } from '@/stores/audio-engine'
import { computeWaveformPeaks } from '../services/session-import'

interface PlayerNode {
  player: Tone.Player
  volume: Tone.Volume
  panner: Tone.Panner
}

export function usePlaybackEngine() {
  const {
    isPlaying, currentTime, duration, tracks, masterVolume,
    activeSong, activeSongIndex, repertoire,
    setPlaying, setCurrentTime, setDuration,
    setFader, toggleMute, toggleSolo, setPan, setMasterVolume,
    setEngineReady, setLoadingTrack, setError,
    updateTrackBuffer, nextSong, prevSong, setActiveSong,
  } = usePlaybackStore()

  const playersRef = useRef<Map<string, PlayerNode>>(new Map())
  const rafRef = useRef<number>(0)
  const playStartRef = useRef(0)
  const pausedAtRef = useRef(0)
  const masterGainRef = useRef<Tone.Volume | null>(null)

  const hasSolo = tracks.some(t => t.soloed)

  /* ── Initialize master gain node ── */
  useEffect(() => {
    if (!masterGainRef.current) {
      masterGainRef.current = new Tone.Volume(0).toDestination()
    }
    return () => {
      masterGainRef.current?.dispose()
      masterGainRef.current = null
    }
  }, [])

  /* ── Sync master volume ── */
  useEffect(() => {
    if (masterGainRef.current) {
      const db = masterVolume === 0 ? -Infinity : 20 * Math.log10(masterVolume / 100)
      masterGainRef.current.volume.value = db
    }
  }, [masterVolume])

  /* ── Sync per-track volume/mute/solo/pan to Tone nodes ── */
  useEffect(() => {
    for (const track of tracks) {
      const node = playersRef.current.get(track.id)
      if (!node) continue
      const db = track.volume === 0 ? -Infinity : 20 * Math.log10(track.volume / 100)
      node.volume.volume.value = db
      const audible = !track.muted && (!hasSolo || track.soloed)
      node.volume.mute = !audible
      node.panner.pan.value = track.pan
    }
  }, [tracks, hasSolo])

  /* ── Load audio into a track ── */
  const loadTrackAudio = useCallback(async (
    trackId: string,
    source: string | AudioBuffer,
  ): Promise<number> => {
    await Tone.start()
    if (!audioEngine.isReady) {
      await audioEngine.init()
      setEngineReady(true)
    }

    setLoadingTrack(trackId)
    setError(null)

    try {
      // Dispose existing player
      const existing = playersRef.current.get(trackId)
      if (existing) {
        existing.player.stop()
        existing.player.dispose()
        existing.volume.dispose()
        existing.panner.dispose()
        playersRef.current.delete(trackId)
      }

      const masterOut = masterGainRef.current ?? Tone.getDestination()
      const vol = new Tone.Volume(0).connect(masterOut)
      const panner = new Tone.Panner(0).connect(vol)

      let player: Tone.Player
      if (typeof source === 'string') {
        player = new Tone.Player(source).connect(panner)
        await Tone.loaded()
      } else {
        const toneBuffer = new Tone.ToneAudioBuffer(source)
        player = new Tone.Player(toneBuffer).connect(panner)
      }

      player.loop = false

      playersRef.current.set(trackId, { player, volume: vol, panner })

      // Compute waveform and update store
      const buf = player.buffer.get()
      if (buf) {
        const waveform = computeWaveformPeaks(buf)
        updateTrackBuffer(trackId, buf, waveform)
      }

      // Update duration to longest loaded track
      const dur = player.buffer.duration
      const currentDur = usePlaybackStore.getState().duration
      if (dur > currentDur) {
        setDuration(dur)
      }

      return dur
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Error loading audio'
      setError(msg)
      throw err
    } finally {
      setLoadingTrack(null)
    }
  }, [setDuration, setEngineReady, setLoadingTrack, setError, updateTrackBuffer])

  /* ── Playhead animation loop ── */
  const startPlayheadUpdate = useCallback(() => {
    const tick = () => {
      const dur = usePlaybackStore.getState().duration
      if (dur <= 0) {
        rafRef.current = requestAnimationFrame(tick)
        return
      }
      const elapsed = Tone.now() - playStartRef.current
      if (elapsed >= dur) {
        // Track finished — stop playback
        stopPlayback()
        return
      }
      setCurrentTime(elapsed)
      rafRef.current = requestAnimationFrame(tick)
    }
    rafRef.current = requestAnimationFrame(tick)
  }, [setCurrentTime])

  const stopPlayheadUpdate = useCallback(() => {
    cancelAnimationFrame(rafRef.current)
  }, [])

  /* ── Play all loaded tracks ── */
  const play = useCallback(async () => {
    await Tone.start()
    if (!audioEngine.isReady) {
      await audioEngine.init()
      setEngineReady(true)
    }

    const offset = pausedAtRef.current
    playStartRef.current = Tone.now() - offset

    for (const [, node] of playersRef.current) {
      if (node.player.buffer.loaded) {
        try {
          node.player.start(undefined, offset)
        } catch {
          // Player might already be started
        }
      }
    }

    setPlaying(true)
    startPlayheadUpdate()
  }, [setPlaying, startPlayheadUpdate, setEngineReady])

  /* ── Pause ── */
  const pause = useCallback(() => {
    const dur = usePlaybackStore.getState().duration
    const elapsed = Tone.now() - playStartRef.current
    pausedAtRef.current = dur > 0 ? Math.min(elapsed, dur) : 0

    for (const [, node] of playersRef.current) {
      try { node.player.stop() } catch { /* already stopped */ }
    }

    setPlaying(false)
    stopPlayheadUpdate()
  }, [setPlaying, stopPlayheadUpdate])

  /* ── Stop (reset to 0) ── */
  const stopPlayback = useCallback(() => {
    pausedAtRef.current = 0

    for (const [, node] of playersRef.current) {
      try { node.player.stop() } catch { /* ok */ }
    }

    setPlaying(false)
    setCurrentTime(0)
    stopPlayheadUpdate()
  }, [setPlaying, setCurrentTime, stopPlayheadUpdate])

  /* ── Seek to position ── */
  const seek = useCallback((time: number) => {
    const dur = usePlaybackStore.getState().duration
    const clampedTime = Math.max(0, Math.min(time, dur))
    pausedAtRef.current = clampedTime
    setCurrentTime(clampedTime)

    if (usePlaybackStore.getState().isPlaying) {
      playStartRef.current = Tone.now() - clampedTime
      for (const [, node] of playersRef.current) {
        if (node.player.buffer.loaded) {
          try {
            node.player.stop()
            node.player.start(undefined, clampedTime)
          } catch { /* ok */ }
        }
      }
    }
  }, [setCurrentTime])

  /* ── Toggle play/pause ── */
  const togglePlay = useCallback(async () => {
    if (usePlaybackStore.getState().isPlaying) {
      pause()
    } else {
      await play()
    }
  }, [play, pause])

  /* ── Restart from beginning ── */
  const restart = useCallback(() => {
    stopPlayback()
  }, [stopPlayback])

  /* ── Get VU level for a track (simulated when no real audio) ── */
  const getVULevel = useCallback((trackId: string): number => {
    const state = usePlaybackStore.getState()
    if (!state.isPlaying) return 0
    const track = state.tracks.find(t => t.id === trackId)
    if (!track || track.muted) return 0
    const soloActive = state.tracks.some(t => t.soloed)
    if (soloActive && !track.soloed) return 0
    const base = (track.volume / 100) * 0.7
    return Math.min(1, base + Math.sin(Date.now() / 200 + track.id.charCodeAt(0)) * 0.15)
  }, [])

  /* ── Cleanup on unmount ── */
  useEffect(() => {
    return () => {
      stopPlayheadUpdate()
      for (const [, node] of playersRef.current) {
        try {
          node.player.stop()
          node.player.dispose()
          node.volume.dispose()
          node.panner.dispose()
        } catch { /* ok */ }
      }
      playersRef.current.clear()
    }
  }, [stopPlayheadUpdate])

  /* ── Get buffer latency info ── */
  const getLatencyInfo = useCallback(() => {
    if (!audioEngine.isReady) return { bufferSize: 256, sampleRate: 44100, latency: 5.8 }
    const report = audioEngine.measureLatency()
    return {
      bufferSize: 256,
      sampleRate: report.sampleRate,
      latency: Math.round(report.totalEstimate * 1000 * 10) / 10,
    }
  }, [])

  return {
    // Transport
    play,
    pause,
    stop: stopPlayback,
    seek,
    togglePlay,
    restart,
    isPlaying,
    currentTime,
    duration,
    // Track management
    loadTrackAudio,
    setFader,
    toggleMute,
    toggleSolo,
    setPan,
    setMasterVolume,
    // Song navigation
    activeSong,
    activeSongIndex,
    repertoire,
    nextSong,
    prevSong,
    setActiveSong,
    // Computed
    hasSolo,
    tracks,
    masterVolume,
    // Helpers
    getVULevel,
    getLatencyInfo,
  }
}
