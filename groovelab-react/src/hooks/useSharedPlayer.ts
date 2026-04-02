/**
 * useSharedPlayer — Shared audio playback hook for SongLab ↔ Multitracks
 *
 * Manages Tone.js Players per-track with synchronized transport,
 * per-track volume/mute/solo, and playhead position updates.
 */
import { useCallback, useEffect, useRef } from 'react'
import * as Tone from 'tone'
import { useAppStore } from '@/stores/app-store'
import { useMultitrackStore } from '@/stores/multitrack-store'
import type { PistaMultitrack } from '@/stores/multitrack-store'

interface PlayerNode {
  player: Tone.Player
  volume: Tone.Volume
  panner: Tone.Panner
}

export function useSharedPlayer() {
  const { isPlaying, setPlaying, bpm } = useAppStore()
  const {
    currentTime,
    duration,
    pistaBase,
    pistasMultitrack,
    setCurrentTime,
    setDuration,
    setFader,
    toggleMute,
    toggleSolo,
  } = useMultitrackStore()

  const playersRef = useRef<Map<string, PlayerNode>>(new Map())
  const rafRef = useRef<number>(0)
  const playStartRef = useRef(0)
  const pausedAtRef = useRef(0)

  // All visible tracks
  const allTracks: PistaMultitrack[] = [
    ...(pistaBase ? [pistaBase] : []),
    ...pistasMultitrack,
  ]

  const hasSolo = allTracks.some((t) => t.soloed)

  // ── Sync volume/mute/solo to Tone nodes ──
  useEffect(() => {
    for (const track of allTracks) {
      const node = playersRef.current.get(track.id)
      if (!node) continue
      const db = track.volumen === 0 ? -Infinity : 20 * Math.log10(track.volumen / 100)
      node.volume.volume.value = db
      const audible = !track.muted && (!hasSolo || track.soloed)
      node.volume.mute = !audible
    }
  }, [allTracks, hasSolo])

  // ── Load audio buffer into a track ──
  const loadTrackAudio = useCallback(async (trackId: string, urlOrBuffer: string | AudioBuffer) => {
    await Tone.start()

    // Dispose existing player for this track
    const existing = playersRef.current.get(trackId)
    if (existing) {
      existing.player.stop()
      existing.player.dispose()
      existing.volume.dispose()
      existing.panner.dispose()
      playersRef.current.delete(trackId)
    }

    const vol = new Tone.Volume(0).toDestination()
    const panner = new Tone.Panner(0).connect(vol)

    let player: Tone.Player
    if (typeof urlOrBuffer === 'string') {
      player = new Tone.Player(urlOrBuffer).connect(panner)
      await Tone.loaded()
    } else {
      const toneBuffer = new Tone.ToneAudioBuffer(urlOrBuffer)
      player = new Tone.Player(toneBuffer).connect(panner)
    }

    player.loop = true

    playersRef.current.set(trackId, { player, volume: vol, panner })

    // Update duration to longest track
    const dur = player.buffer.duration
    const currentDur = useMultitrackStore.getState().duration
    if (dur > currentDur) {
      setDuration(dur)
    }

    return dur
  }, [setDuration])

  // ── Playhead animation ──
  const startPlayheadUpdate = useCallback(() => {
    const tick = () => {
      const dur = useMultitrackStore.getState().duration
      if (dur <= 0) {
        rafRef.current = requestAnimationFrame(tick)
        return
      }
      const elapsed = Tone.now() - playStartRef.current
      const pos = elapsed % dur
      setCurrentTime(pos)
      rafRef.current = requestAnimationFrame(tick)
    }
    rafRef.current = requestAnimationFrame(tick)
  }, [setCurrentTime])

  const stopPlayheadUpdate = useCallback(() => {
    cancelAnimationFrame(rafRef.current)
  }, [])

  // ── Play all loaded tracks ──
  const play = useCallback(async () => {
    await Tone.start()
    const offset = pausedAtRef.current
    playStartRef.current = Tone.now() - offset

    for (const [, node] of playersRef.current) {
      if (node.player.buffer.loaded) {
        node.player.start(undefined, offset)
      }
    }

    setPlaying(true)
    startPlayheadUpdate()
  }, [setPlaying, startPlayheadUpdate])

  // ── Pause ──
  const pause = useCallback(() => {
    const dur = useMultitrackStore.getState().duration
    const elapsed = Tone.now() - playStartRef.current
    pausedAtRef.current = dur > 0 ? elapsed % dur : 0

    for (const [, node] of playersRef.current) {
      node.player.stop()
    }

    setPlaying(false)
    stopPlayheadUpdate()
  }, [setPlaying, stopPlayheadUpdate])

  // ── Stop (reset to 0) ──
  const stop = useCallback(() => {
    pausedAtRef.current = 0

    for (const [, node] of playersRef.current) {
      node.player.stop()
    }

    setPlaying(false)
    setCurrentTime(0)
    stopPlayheadUpdate()
  }, [setPlaying, setCurrentTime, stopPlayheadUpdate])

  // ── Seek to position ──
  const seek = useCallback((time: number) => {
    pausedAtRef.current = time
    setCurrentTime(time)

    if (useAppStore.getState().isPlaying) {
      // Restart all players at new offset
      playStartRef.current = Tone.now() - time
      for (const [, node] of playersRef.current) {
        if (node.player.buffer.loaded) {
          node.player.stop()
          node.player.start(undefined, time)
        }
      }
    }
  }, [setCurrentTime])

  // ── Toggle play/pause ──
  const togglePlay = useCallback(async () => {
    if (isPlaying) {
      pause()
    } else {
      await play()
    }
  }, [isPlaying, play, pause])

  // ── Cleanup on unmount ──
  useEffect(() => {
    return () => {
      stopPlayheadUpdate()
      for (const [, node] of playersRef.current) {
        node.player.stop()
        node.player.dispose()
        node.volume.dispose()
        node.panner.dispose()
      }
      playersRef.current.clear()
    }
  }, [stopPlayheadUpdate])

  // ── Sync BPM to transport ──
  useEffect(() => {
    Tone.getTransport().bpm.value = bpm
  }, [bpm])

  return {
    // Transport
    play,
    pause,
    stop,
    seek,
    togglePlay,
    isPlaying,
    currentTime,
    duration,
    // Track management
    loadTrackAudio,
    // Store proxies
    setFader,
    toggleMute,
    toggleSolo,
    // Computed
    hasSolo,
    allTracks,
  }
}
