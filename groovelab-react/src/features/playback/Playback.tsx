/**
 * Playback / Multitracks Live — Main module component
 *
 * CSS Grid layout matching the exact HTML source:
 * grid-template-rows: 52px auto 1fr 34px
 * grid-template-columns: 210px 1fr
 * Areas: transport | setlist+timeline | setlist+mixer | bottombar
 */
import { useState, useEffect, useRef, useCallback } from 'react'
import { usePlaybackStore } from './store'
import { usePlaybackEngine } from './hooks/usePlaybackEngine'
import { importMultitrackSession } from './services/session-import'
import { getTotalDuration } from './constants'

import { TransportBar } from './components/TransportBar'
import { SetlistPanel } from './components/SetlistPanel'
import { TimelinePanel } from './components/TimelinePanel'
import { MixerPanel } from './components/MixerPanel'
import { BottomBar } from './components/BottomBar'

import './playback.css'

export default function Playback() {
  const [, setFileLoading] = useState(false)

  const {
    mode, setMode,
    repertoire, activeSong, activeSongIndex,
    tracks, masterVolume, visibleSequences,
    transitionType, setTransitionType,
    activeTab, setActiveTab,
    sidebarCollapsed,
    initDemo,
  } = usePlaybackStore()

  const {
    isPlaying, currentTime, duration,
    togglePlay, stop, seek,
    nextSong, prevSong, setActiveSong,
    setFader, toggleMute, toggleSolo,
    setMasterVolume,
    hasSolo,
    getVULevel,
    getLatencyInfo,
    loadTrackAudio,
  } = usePlaybackEngine()

  const multiFileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    initDemo()
  }, [initDemo])

  const progress = duration > 0 ? currentTime / duration : 0
  const sections = activeSong?.sections ?? []
  const automationPoints = activeSong?.automationPoints ?? []
  const visibleTracks = tracks.filter(t => visibleSequences.includes(t.name))
  const totalDuration = getTotalDuration(repertoire?.songs ?? [])
  const latencyInfo = getLatencyInfo()

  const bpm = activeSong?.bpm ?? 120
  const secondsPerBeat = 60 / bpm
  const totalBeats = currentTime / secondsPerBeat
  const currentBar = Math.floor(totalBeats / 4) + 1
  const currentBeat = (Math.floor(totalBeats) % 4) + 1

  const handleTimelineSeek = useCallback((ratio: number) => {
    if (!duration) return
    seek(ratio * duration)
  }, [duration, seek])

  const handleMultiFileSelect = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (!files || files.length === 0) return
    setFileLoading(true)
    try {
      const result = await importMultitrackSession(files)
      for (const track of result.tracks) {
        if (track.audioBuffer && track.id) {
          await loadTrackAudio(track.id, track.audioBuffer)
        }
      }
    } catch (err) {
      console.error('Failed to import session:', err)
    } finally {
      setFileLoading(false)
      if (e.target) e.target.value = ''
    }
  }, [loadTrackAudio])

  return (
    <div className="gl-playback" style={{ margin: '-1rem', height: 'calc(100% + 2rem)' }}>
      {/* Hidden file input */}
      <input
        ref={multiFileInputRef}
        type="file"
        accept="audio/*"
        multiple
        className="hidden"
        onChange={handleMultiFileSelect}
      />

      {/* TRANSPORT BAR */}
      <TransportBar
        activeSong={activeSong}
        currentTime={currentTime}
        duration={duration}
        isPlaying={isPlaying}
        mode={mode}
        currentBar={currentBar}
        currentBeat={currentBeat}
        onTogglePlay={togglePlay}
        onStop={stop}
        onNext={nextSong}
        onPrev={prevSong}
        onModeChange={setMode}
      />

      {/* SETLIST PANEL */}
      <SetlistPanel
        repertoire={repertoire}
        activeSongIndex={activeSongIndex}
        isPlaying={isPlaying}
        transitionType={transitionType}
        collapsed={sidebarCollapsed}
        onSelectSong={setActiveSong}
        onPrev={prevSong}
        onNext={nextSong}
        onTransitionChange={setTransitionType}
        totalDuration={totalDuration}
      />

      {/* TIMELINE */}
      <TimelinePanel
        sections={sections}
        automationPoints={automationPoints}
        progress={progress}
        duration={duration}
        bpm={bpm}
        onSeek={handleTimelineSeek}
        onImport={() => multiFileInputRef.current?.click()}
      />

      {/* MIXER */}
      <MixerPanel
        tracks={visibleTracks}
        masterVolume={masterVolume}
        hasSolo={hasSolo}
        getVULevel={getVULevel}
        onSetFader={setFader}
        onToggleMute={toggleMute}
        onToggleSolo={toggleSolo}
        onSetMasterVolume={setMasterVolume}
      />

      {/* BOTTOM BAR */}
      <BottomBar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        bufferSize={latencyInfo.bufferSize}
        sampleRate={latencyInfo.sampleRate}
        latencyMs={latencyInfo.latency}
      />
    </div>
  )
}
