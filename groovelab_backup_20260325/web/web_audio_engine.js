/**
 * GrooveLab Web Audio Engine
 *
 * Implements a precise Web Audio API metronome using the look-ahead scheduler pattern.
 * This provides sample-accurate timing for click sounds on web browsers.
 *
 * Features: Metronome, Drum Machine, Loop Station (pro), MIDI, Input Monitoring,
 * Level Metering, Waveform Extraction, Mixdown Export.
 */
(function() {
  'use strict';

  class GrooveLabWebAudio {
    constructor() {
      this.ctx = null;
      this.buffers = {};
      this.isPlaying = false;
      this.schedulerTimer = null;

      // Metronome config
      this.bpm = 120;
      this.beatsPerBar = 4;
      this.beatUnit = 4;
      this.subdivision = 1;
      this.swingPercent = 0;
      this.clickSoundPrefix = 'click';
      this.accentPattern = [1.0, 0.7, 0.7, 0.7];
      this.humanFeel = 0;

      // Scheduler state
      this.nextNoteTime = 0;
      this.currentBeat = 0;
      this.currentSubBeat = 0;
      this.measureCount = 0;

      // Scheduler tuning
      this.lookahead = 0.1;       // seconds to look ahead
      this.scheduleInterval = 25; // ms between scheduler runs

      // Beat callback (set from Dart)
      this.onBeatCallback = null;

      // Master gain
      this.masterGain = null;

      // Guide & loop master gains (created in init)
      this.guideGain = null;
      this.loopMasterGain = null;
      this.monitorGainNode = null;

      // Guide mute state
      this._guideMuted = false;
      this._guidePrevVolume = 1.0;

      // Drum machine state
      this.isDrumMode = false;
      this.drumPattern = {};
      this.drumVolumes = {};

      // Interval training state
      this.intervalEnabled = false;
      this.intervalClickBars = 4;
      this.intervalSilentBars = 2;

      // Random silence state
      this.randomSilenceEnabled = false;
      this.randomSilenceProbability = 25; // percentage

      // Count-in state
      this.countInBars = 0;
      this.countInRemaining = 0; // bars remaining in count-in

      // Loop Station state
      this.loopLayers = [];        // Array of {buffer, gainNode, panNode, name, muted, solo}
      this.loopDuration = 0;       // Duration of first layer (defines loop length)
      this.isLooping = false;      // Whether loop playback is active
      this.isOverdubbing = false;  // Whether currently recording overdub
      this._loopStartTime = 0;     // When loop playback started
      this._loopSources = [];      // Active AudioBufferSourceNodes
      this._loopRecChunks = [];    // Chunks for loop recording
      this._loopMediaRecorder = null;
      this._loopMediaStream = null;
      this._loopRecordStartTime = 0;
      this._loopOverdubTimer = null;
      this._soloActive = false;    // Whether any layer is currently soloed

      // Loop position tracking
      this.onLoopPositionCallback = null;
      this._loopPositionTimer = null;

      // Overdub auto-stop callback (notifies Dart when auto-stop fires)
      this.onOverdubAutoStopCallback = null;

      // Input monitoring state
      this._monitorStream = null;
      this._monitorSource = null;
      this._monitorGain = null;

      // Input level meter state
      this.onInputLevelCallback = null;
      this._analyserNode = null;
      this._levelAnimFrame = null;
      this._meterStream = null;

      // Export state
      this._lastExportUrl = null;

      // MIDI state
      this.midiAccess = null;
      this.midiInputs = [];
      this.midiEnabled = false;
      this.onMidiEvent = null;  // Callback to Dart
      this.midiMappings = {};   // Custom MIDI note-to-action mappings
      this.midiLoopMappings = {}; // MIDI note-to-loop-action mappings

      // Pad state
      this.pads = [];           // Array of {buffer, source, gainNode, panNode, name, key, tempo, volume, playing, loop}
      this.padMasterGain = null; // Master gain for all pads
      this.padPanNode = null;    // StereoPanner for pad routing
      this.guidePanNode = null;  // StereoPanner for guide routing

      // Pad crossfade state
      this._activePadIndex = -1;       // Currently active pad sound index
      this._activePadKey = null;        // Currently playing key (e.g. 'C', 'D#')
      this._padCrossfadeSources = [];   // Active crossfade sources for cleanup
      this._padHold = false;            // Hold mode (sustain current pad)
      this._padTransitionMode = 'smooth';
      this._padTransitionTime = 1.2;    // seconds

      // Song Lab state
      this.songLabTracks = [];
      this.songLabMasterGain = null;
      this.songLabDuration = 0;
      this.songLabPlaying = false;
      this.songLabStartTime = 0;
      this.songLabPauseOffset = 0;
      this.songLabSpeed = 1.0;
      this.songLabPitchShift = 0;
      this.songLabLoopA = -1;
      this.songLabLoopB = -1;
      this.songLabSources = [];
      this.songLabRecording = false;
      this.songLabRecChunks = [];
      this.songLabRecMediaRecorder = null;
      this.songLabRecStream = null;
      this.songLabRecBuffer = null;
      this._songLabPositionTimer = null;
      this._songLabSoloActive = false;
      this.onSongLabPositionCallback = null;
    }

    init() {
      try {
        this.ctx = new (window.AudioContext || window.webkitAudioContext)();
        this.masterGain = this.ctx.createGain();
        this.masterGain.gain.value = 1.0;
        this.masterGain.connect(this.ctx.destination);

        // Guide gain (metronome/drums route through here)
        this.guideGain = this.ctx.createGain();
        this.guideGain.gain.value = 1.0;
        this.guidePanNode = this.ctx.createStereoPanner();
        this.guidePanNode.pan.value = 0;
        this.guideGain.connect(this.guidePanNode);
        this.guidePanNode.connect(this.masterGain);

        // Loop master gain (all loop layers route through here)
        this.loopMasterGain = this.ctx.createGain();
        this.loopMasterGain.gain.value = 1.0;
        this.loopMasterGain.connect(this.masterGain);

        // Song Lab master gain (all song lab tracks route through here)
        this.songLabMasterGain = this.ctx.createGain();
        this.songLabMasterGain.gain.value = 1.0;
        this.songLabMasterGain.connect(this.masterGain);

        // Pad master gain (all pads route through here)
        this.padMasterGain = this.ctx.createGain();
        this.padMasterGain.gain.value = 1.0;
        this.padPanNode = this.ctx.createStereoPanner();
        this.padPanNode.pan.value = 0;
        this.padMasterGain.connect(this.padPanNode);
        this.padPanNode.connect(this.masterGain);

        // Monitor gain node (input monitoring routes through here)
        this.monitorGainNode = this.ctx.createGain();
        this.monitorGainNode.gain.value = 1.0;
        this.monitorGainNode.connect(this.masterGain);

        console.log('[GrooveLabWebAudio] Initialized, sampleRate:', this.ctx.sampleRate);
        return true;
      } catch (e) {
        console.error('[GrooveLabWebAudio] Init failed:', e);
        return false;
      }
    }

    async loadSound(key, arrayBuffer) {
      if (!this.ctx) return false;
      try {
        // decodeAudioData detaches the buffer, so pass a copy
        const copy = arrayBuffer.slice(0);
        const audioBuffer = await this.ctx.decodeAudioData(copy);
        this.buffers[key] = audioBuffer;
        return true;
      } catch (e) {
        console.warn('[GrooveLabWebAudio] Failed to decode:', key, e);
        return false;
      }
    }

    _playBuffer(bufferKey, time, gain) {
      const buffer = this.buffers[bufferKey];
      if (!buffer) {
        // Try generic fallback
        const fb = this.buffers['click_normal'];
        if (!fb) return;
        this._playRawBuffer(fb, time, gain);
        return;
      }
      this._playRawBuffer(buffer, time, gain);
    }

    _playRawBuffer(buffer, time, gain) {
      const source = this.ctx.createBufferSource();
      source.buffer = buffer;
      const gainNode = this.ctx.createGain();
      gainNode.gain.value = Math.max(0, Math.min(1, gain));
      source.connect(gainNode);
      gainNode.connect(this.guideGain);
      source.start(time);
    }

    _getSoundKey(beatInBar, isSubBeat) {
      const prefix = this.clickSoundPrefix;

      // Hi-Hat special: single sound for everything
      if (prefix === 'hihat_click') {
        return 'hihat_click';
      }

      if (isSubBeat) {
        // Try prefix_sub → click_sub → prefix_normal
        if (this.buffers[prefix + '_sub']) return prefix + '_sub';
        if (this.buffers['click_sub']) return 'click_sub';
        return prefix + '_normal';
      }

      const accent = beatInBar < this.accentPattern.length
        ? this.accentPattern[beatInBar] : 0.7;

      if (accent >= 0.9) {
        return this.buffers[prefix + '_accent'] ? prefix + '_accent' : 'click_accent';
      }
      if (accent <= 0.3) {
        return this.buffers[prefix + '_ghost'] ? prefix + '_ghost' : prefix + '_normal';
      }
      return this.buffers[prefix + '_normal'] ? prefix + '_normal' : 'click_normal';
    }

    _getVolume(beatInBar, isSubBeat) {
      if (isSubBeat) return 0.4;
      return beatInBar < this.accentPattern.length
        ? this.accentPattern[beatInBar] : 0.7;
    }

    // ── METRONOME SCHEDULER ──

    _scheduler() {
      if (!this.isPlaying || !this.ctx) return;

      const currentTime = this.ctx.currentTime;

      while (this.nextNoteTime < currentTime + this.lookahead) {
        const beatInBar = this.currentBeat;
        const isSubBeat = this.currentSubBeat > 0;

        // Timing adjustments
        let timeOffset = 0;

        // Swing: delay even-numbered sub-beats
        if (this.swingPercent > 0 && this.subdivision >= 2 && this.currentSubBeat === 1) {
          const beatDur = 60.0 / this.bpm;
          const subDur = beatDur / this.subdivision;
          timeOffset += (this.swingPercent / 100.0) * subDur * 0.5;
        }

        // Human feel: subtle random timing jitter on non-downbeats
        if (this.humanFeel > 0 && (isSubBeat || beatInBar > 0)) {
          const maxMs = (this.humanFeel / 100.0) * 0.015;
          timeOffset += (Math.random() * 2 - 1) * maxMs;
        }

        const playTime = Math.max(this.nextNoteTime + timeOffset, currentTime);

        // Count-in mode: play simple clicks, no intervals/silence/drums
        const inCountIn = this.countInRemaining > 0;

        if (inCountIn) {
          // During count-in: only play main beats (no subdivisions)
          if (!isSubBeat) {
            const key = this.buffers['click_accent'] ? 'click_accent' : 'click_normal';
            this._playBuffer(key, playTime, 1.0);
          }
        } else {
          // Determine if this beat should be muted
          let muted = false;
          if (!this.isDrumMode) {
            // Interval training: cycle of click bars then silent bars
            if (this.intervalEnabled) {
              const cycleLen = this.intervalClickBars + this.intervalSilentBars;
              const barInCycle = this.measureCount % cycleLen;
              if (barInCycle >= this.intervalClickBars) {
                muted = true;
              }
            }
            // Random silence: each non-downbeat has a chance to be muted
            if (this.randomSilenceEnabled && !muted) {
              if (Math.random() * 100 < this.randomSilenceProbability) {
                muted = true;
              }
            }
          }

          if (this.isDrumMode) {
            this._scheduleDrumStep(playTime);
          } else if (!muted) {
            // Metronome click
            const soundKey = this._getSoundKey(beatInBar, isSubBeat);
            const volume = this._getVolume(beatInBar, isSubBeat);
            this._playBuffer(soundKey, playTime, volume);
          }
        }

        // Fire beat event for UI synchronization (main beats only)
        if (!isSubBeat && this.onBeatCallback) {
          const bi = beatInBar;
          const mi = this.measureCount;
          const isAccent = (bi < this.accentPattern.length) && this.accentPattern[bi] >= 0.9;
          const isDrum = this.isDrumMode;
          const delayMs = Math.max(0, (playTime - currentTime) * 1000);
          setTimeout(() => {
            if (this.onBeatCallback) {
              this.onBeatCallback(bi, mi, isAccent, isDrum);
            }
          }, delayMs);
        }

        // Advance position
        this.currentSubBeat++;
        // During count-in, skip subdivisions (only play main beats)
        const effectiveSub = inCountIn ? 1 : this.subdivision;
        if (this.currentSubBeat >= effectiveSub) {
          this.currentSubBeat = 0;
          this.currentBeat++;
          if (this.currentBeat >= this.beatsPerBar) {
            this.currentBeat = 0;
            if (inCountIn) {
              this.countInRemaining--;
              if (this.countInRemaining <= 0) {
                // Count-in finished — reset measure count for real playback
                this.measureCount = 0;
              }
            } else {
              this.measureCount++;
            }
          }
        }

        // Next note time
        const beatDuration = 60.0 / this.bpm;
        const subBeatDuration = beatDuration / Math.max(1, this.subdivision);
        this.nextNoteTime += subBeatDuration;
      }
    }

    _scheduleDrumStep(playTime) {
      const step = this.currentBeat;
      const stepsPerBeat = this.drumStepsPerBeat || 4;
      // Determine which beat this step falls on for accent
      const beatIndex = Math.floor(step / stepsPerBeat);
      const accentPat = this.drumAccentPattern || [];
      const accentMul = (beatIndex < accentPat.length) ? accentPat[beatIndex] : 1.0;

      for (const [track, steps] of Object.entries(this.drumPattern)) {
        if (steps && step < steps.length && steps[step] > 0) {
          const baseVol = this.drumVolumes[track] !== undefined ? this.drumVolumes[track] : 0.8;
          const vol = baseVol * accentMul;
          const key = this._drumTrackToKey(track);
          this._playBuffer(key, playTime, vol);
        }
      }
    }

    _drumTrackToKey(track) {
      const map = {
        'kick': 'kick',
        'snare': 'snare',
        'hihat': 'hihat',
        'hihat_open': 'hihat_open',
        'ride': 'ride',
      };
      return map[track] || track;
    }

    // ── PUBLIC API: METRONOME ──

    startMetronome(bpm, beatsPerBar, beatUnit, subdivision, swingPercent, clickSound, accentPattern, hapticEnabled) {
      // Resume suspended context (browser autoplay policy)
      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume();
      }

      this.stopMetronome();

      this.isDrumMode = false;
      this.bpm = bpm || 120;
      this.beatsPerBar = beatsPerBar || 4;
      this.beatUnit = beatUnit || 4;
      this.subdivision = subdivision || 1;
      this.swingPercent = swingPercent || 0;
      this.accentPattern = accentPattern || [1.0, 0.7, 0.7, 0.7];
      this._mapClickSound(clickSound || 'Wood');

      this.currentBeat = 0;
      this.currentSubBeat = 0;
      this.measureCount = 0;
      this.countInRemaining = this.countInBars;
      this.nextNoteTime = this.ctx.currentTime + 0.05;
      this.isPlaying = true;

      this.schedulerTimer = setInterval(() => this._scheduler(), this.scheduleInterval);
      console.log('[GrooveLabWebAudio] Metronome started:', this.bpm, 'BPM',
        this.countInBars > 0 ? `(count-in: ${this.countInBars} bars)` : '');
    }

    stopMetronome() {
      this.isPlaying = false;
      if (this.schedulerTimer !== null) {
        clearInterval(this.schedulerTimer);
        this.schedulerTimer = null;
      }
    }

    _mapClickSound(name) {
      const map = {
        'Wood':      'click',
        'WoodBlock': 'woodblock',
        'SineBurst': 'sineburst',
        'Digital':   'digital',
        'Clave':     'clave',
        'Clave HQ':  'clave_hq',
        'Hi-Hat':    'hihat_click',
        'Cowbell':   'cowbell',
        'Beep':      'beep',
        'Rimshot':   'rimshot',
        'Shaker':    'shaker',
        'Tambourine':'tambourine',
      };
      this.clickSoundPrefix = map[name] || 'click';
    }

    updateBpm(bpm) { this.bpm = bpm; }
    updateTimeSignature(beatsPerBar, beatUnit) {
      this.beatsPerBar = beatsPerBar;
      this.beatUnit = beatUnit;
    }
    updateSubdivision(sub) { this.subdivision = sub; }
    updateSwing(pct) { this.swingPercent = pct; }
    updateClickSound(name) { this._mapClickSound(name); }
    updateAccentPattern(pattern) { this.accentPattern = pattern; }
    updateHumanFeel(pct) { this.humanFeel = pct; }
    updateCountIn(bars) { this.countInBars = bars; }
    setHapticMode(enabled) { /* no-op on web */ }
    updatePolyrhythm(enabled, value) { /* simplified no-op for web */ }
    updateIntervalTraining(enabled, clickBars, silentBars) {
      this.intervalEnabled = enabled;
      this.intervalClickBars = clickBars || 4;
      this.intervalSilentBars = silentBars || 2;
    }
    updateRandomSilence(enabled, probability) {
      this.randomSilenceEnabled = enabled;
      this.randomSilenceProbability = probability || 25;
    }

    // ── PUBLIC API: DRUM MACHINE ──

    startDrumPattern(bpm, pattern, swingPercent, drumBeats, drumBeatUnit, drumAccentPattern) {
      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume();
      }

      this.stopMetronome();

      this.isDrumMode = true;
      // Calculate steps per beat based on beat unit: /4 = 4 steps, /8 = 2 steps
      const beatUnit = drumBeatUnit || 4;
      const beats = drumBeats || 4;
      const stepsPerBeat = beatUnit === 8 ? 2 : 4;
      const totalSteps = beats * stepsPerBeat;

      // BPM × stepsPerBeat to get step rate
      this.bpm = (bpm || 120) * stepsPerBeat;
      this.drumPattern = pattern || {};
      this.swingPercent = swingPercent || 0;
      this.beatsPerBar = totalSteps;
      this.drumStepsPerBeat = stepsPerBeat;
      this.drumBeats = beats;
      this.drumAccentPattern = drumAccentPattern || [];
      this.subdivision = 1;
      this.accentPattern = [];

      this.currentBeat = 0;
      this.currentSubBeat = 0;
      this.measureCount = 0;
      this.nextNoteTime = this.ctx.currentTime + 0.05;
      this.isPlaying = true;

      this.schedulerTimer = setInterval(() => this._scheduler(), this.scheduleInterval);
      console.log('[GrooveLabWebAudio] Drum pattern started:', totalSteps, 'steps,', bpm, 'BPM');
    }

    stopDrumPattern() { this.stopMetronome(); }
    updateDrumPattern(pattern) { this.drumPattern = pattern; }
    updateDrumVolumes(volumes) { this.drumVolumes = volumes; }
    updateDrumTimeSig(beats, beatUnit) {
      const oldStepsPerBeat = this.drumStepsPerBeat || 4;
      const stepsPerBeat = beatUnit === 8 ? 2 : 4;
      // Recalculate BPM step rate based on new beat unit
      const quarterBpm = this.bpm / oldStepsPerBeat;
      this.drumStepsPerBeat = stepsPerBeat;
      this.drumBeats = beats;
      this.beatsPerBar = beats * stepsPerBeat;
      this.bpm = quarterBpm * stepsPerBeat;
      this.currentBeat = 0;
    }
    updateDrumAccentPattern(pattern) { this.drumAccentPattern = pattern || []; }

    async playDrumHit(track) {
      if (!this.ctx) return;
      if (this.ctx.state === 'suspended') await this.ctx.resume();
      const key = this._drumTrackToKey(track);
      const vol = this.drumVolumes[track] !== undefined ? this.drumVolumes[track] : 0.8;
      this._playBuffer(key, this.ctx.currentTime, vol);
    }

    // ── VOLUME ──

    setVolume(vol) {
      if (this.masterGain) {
        this.masterGain.gain.value = Math.max(0, Math.min(1, vol));
      }
    }

    // ── GUIDE VOLUME CONTROL ──

    setGuideVolume(vol) {
      if (this.guideGain) {
        this.guideGain.gain.value = Math.max(0, Math.min(1, vol));
        if (vol > 0) {
          this._guidePrevVolume = vol;
          this._guideMuted = false;
        }
      }
    }

    setLoopMasterVolume(vol) {
      if (this.loopMasterGain) {
        this.loopMasterGain.gain.value = Math.max(0, Math.min(1, vol));
      }
    }

    muteGuide(muted) {
      if (!this.guideGain) return;
      if (muted) {
        this._guidePrevVolume = this.guideGain.gain.value;
        this.guideGain.gain.value = 0;
        this._guideMuted = true;
      } else {
        this.guideGain.gain.value = this._guidePrevVolume;
        this._guideMuted = false;
      }
    }

    isGuideMuted() {
      return this._guideMuted;
    }

    // ── LATENCY ──

    getOutputLatency() {
      if (this.ctx && this.ctx.outputLatency) {
        return this.ctx.outputLatency * 1000; // seconds to ms
      }
      return this.ctx ? this.ctx.baseLatency * 1000 : 0;
    }

    // ── AUDIO CONTEXT RESUME (iOS/Safari autoplay policy) ──

    async resumeContext() {
      if (this.ctx && this.ctx.state === 'suspended') {
        try {
          await this.ctx.resume();
          console.log('[GrooveLabWebAudio] AudioContext resumed');
          return true;
        } catch (e) {
          console.warn('[GrooveLabWebAudio] Resume failed:', e);
          return false;
        }
      }
      return true;
    }

    // ── WEB RECORDING (MediaRecorder API) ──

    async startWebRecording() {
      try {
        // Resume audio context first (iOS requirement)
        await this.resumeContext();

        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        this._recordedChunks = [];
        this._mediaStream = stream;

        // Prefer webm, fall back to mp4 for Safari
        const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
          ? 'audio/webm;codecs=opus'
          : MediaRecorder.isTypeSupported('audio/mp4')
            ? 'audio/mp4'
            : '';

        this._mediaRecorder = new MediaRecorder(stream, mimeType ? { mimeType } : {});

        this._mediaRecorder.ondataavailable = (e) => {
          if (e.data.size > 0) {
            this._recordedChunks.push(e.data);
          }
        };

        this._mediaRecorder.onstop = () => {
          const blob = new Blob(this._recordedChunks, {
            type: this._mediaRecorder.mimeType || 'audio/webm'
          });
          this._lastRecordingUrl = URL.createObjectURL(blob);
          this._lastRecordingBlob = blob;
          console.log('[GrooveLabWebAudio] Recording saved, size:', blob.size);
        };

        this._mediaRecorder.start(100); // Collect data every 100ms
        this._isWebRecording = true;
        console.log('[GrooveLabWebAudio] Web recording started');
        return 'recording';
      } catch (e) {
        console.error('[GrooveLabWebAudio] Recording failed:', e);
        if (e.name === 'NotAllowedError') return 'permission_denied';
        if (e.name === 'NotFoundError') return 'no_microphone';
        return 'error';
      }
    }

    stopWebRecording() {
      if (this._mediaRecorder && this._isWebRecording) {
        this._mediaRecorder.stop();
        this._isWebRecording = false;

        // Stop all tracks on the media stream
        if (this._mediaStream) {
          this._mediaStream.getTracks().forEach(track => track.stop());
          this._mediaStream = null;
        }
        console.log('[GrooveLabWebAudio] Web recording stopped');
        return true;
      }
      return false;
    }

    getLastRecordingUrl() {
      return this._lastRecordingUrl || '';
    }

    isWebRecording() {
      return this._isWebRecording === true;
    }

    playRecording() {
      if (this._lastRecordingUrl) {
        if (this._playbackAudio) {
          this._playbackAudio.pause();
          this._playbackAudio = null;
        }
        this._playbackAudio = new Audio(this._lastRecordingUrl);
        this._playbackAudio.play();
        return true;
      }
      return false;
    }

    stopPlayback() {
      if (this._playbackAudio) {
        this._playbackAudio.pause();
        this._playbackAudio.currentTime = 0;
        this._playbackAudio = null;
        return true;
      }
      return false;
    }

    discardRecording() {
      if (this._lastRecordingUrl) {
        URL.revokeObjectURL(this._lastRecordingUrl);
        this._lastRecordingUrl = null;
        this._lastRecordingBlob = null;
        this._recordedChunks = [];
        return true;
      }
      return false;
    }

    hasRecording() {
      return !!this._lastRecordingUrl;
    }

    // ── LOOP STATION ──

    async startLoopRecording() {
      try {
        // Resume audio context first (iOS/Safari requirement)
        await this.resumeContext();

        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        this._loopRecChunks = [];
        this._loopMediaStream = stream;

        // Prefer webm, fall back to mp4 for Safari
        const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
          ? 'audio/webm;codecs=opus'
          : MediaRecorder.isTypeSupported('audio/mp4')
            ? 'audio/mp4'
            : '';

        this._loopMediaRecorder = new MediaRecorder(stream, mimeType ? { mimeType } : {});

        this._loopMediaRecorder.ondataavailable = (e) => {
          if (e.data.size > 0) {
            this._loopRecChunks.push(e.data);
          }
        };

        this._loopRecordStartTime = this.ctx.currentTime;
        this._loopMediaRecorder.start(100);
        this.isOverdubbing = true;

        // Auto-start playback of existing layers during overdub
        if (this.loopLayers.length > 0 && !this.isLooping) {
          this.startLoopPlayback();
        }

        // Track recording elapsed time for UI
        this._recElapsedTimer = setInterval(() => {
          if (this.isOverdubbing && this.onLoopPositionCallback) {
            const elapsed = this.ctx.currentTime - this._loopRecordStartTime;
            // For first recording (no loop duration yet), send elapsed seconds as negative to distinguish
            if (this.loopDuration === 0) {
              // Send -1 to indicate "recording, no loop set yet"
              this.onLoopPositionCallback(-1);
            }
          }
        }, 50);

        // If loop already exists (overdub), auto-stop after one loop cycle
        if (this.loopDuration > 0) {
          let remainingMs;
          if (this.isLooping && this._loopStartTime > 0) {
            const elapsed = this.ctx.currentTime - this._loopStartTime;
            const positionInLoop = elapsed % this.loopDuration;
            remainingMs = (this.loopDuration - positionInLoop) * 1000;
          } else {
            remainingMs = this.loopDuration * 1000;
          }
          this._loopOverdubTimer = setTimeout(async () => {
            if (this.isOverdubbing) {
              const result = await this.stopLoopRecording();
              // Notify Dart that overdub auto-stopped
              if (this.onOverdubAutoStopCallback && result && result.success) {
                this.onOverdubAutoStopCallback(
                  result.layerCount,
                  this.loopDuration,
                  result.layerIndex
                );
              }
            }
          }, remainingMs);
        }

        console.log('[GrooveLabWebAudio] Loop recording started',
          this.loopDuration > 0 ? `(overdub, auto-stop in ${this.loopDuration.toFixed(2)}s)` : '(first layer)');
        return 'recording';
      } catch (e) {
        console.error('[GrooveLabWebAudio] Loop recording failed:', e);
        if (e.name === 'NotAllowedError') return 'permission_denied';
        if (e.name === 'NotFoundError') return 'no_microphone';
        return 'error';
      }
    }

    async stopLoopRecording() {
      if (!this._loopMediaRecorder || !this.isOverdubbing) {
        return { success: false, layerCount: this.loopLayers.length };
      }

      // Clear overdub auto-stop timer
      if (this._loopOverdubTimer) {
        clearTimeout(this._loopOverdubTimer);
        this._loopOverdubTimer = null;
      }

      if (this._recElapsedTimer) {
        clearInterval(this._recElapsedTimer);
        this._recElapsedTimer = null;
      }

      return new Promise((resolve) => {
        this._loopMediaRecorder.onstop = async () => {
          try {
            const blob = new Blob(this._loopRecChunks, {
              type: this._loopMediaRecorder.mimeType || 'audio/webm'
            });

            // Convert blob to AudioBuffer
            const arrayBuffer = await blob.arrayBuffer();
            const audioBuffer = await this.ctx.decodeAudioData(arrayBuffer);

            // For overdubs, align buffer to exact loop duration (prevent clips/gaps)
            let finalBuffer = audioBuffer;
            if (this.loopDuration > 0 && this.loopLayers.length > 0) {
              const targetLength = Math.round(this.loopDuration * audioBuffer.sampleRate);
              if (Math.abs(audioBuffer.length - targetLength) > 1) {
                const aligned = this.ctx.createBuffer(
                  audioBuffer.numberOfChannels,
                  targetLength,
                  audioBuffer.sampleRate
                );
                const copyLength = Math.min(audioBuffer.length, targetLength);
                for (let ch = 0; ch < audioBuffer.numberOfChannels; ch++) {
                  const src = audioBuffer.getChannelData(ch);
                  const dst = aligned.getChannelData(ch);
                  dst.set(src.subarray(0, copyLength));
                }
                finalBuffer = aligned;
                console.log('[GrooveLabWebAudio] Overdub buffer aligned:', audioBuffer.length, '->', targetLength, 'samples');
              }
            }

            // Create a gain node for this layer
            const gainNode = this.ctx.createGain();
            gainNode.gain.value = 1.0;

            // Create a stereo panner node for this layer
            const panNode = this.ctx.createStereoPanner();
            panNode.pan.value = 0;
            gainNode.connect(panNode);
            panNode.connect(this.loopMasterGain);

            // On first recording, set the loop duration
            if (this.loopLayers.length === 0) {
              this.loopDuration = audioBuffer.duration;
              console.log('[GrooveLabWebAudio] Loop duration set:', this.loopDuration.toFixed(2), 's');
            }

            this.loopLayers.push({
              buffer: finalBuffer,
              gainNode: gainNode,
              panNode: panNode,
              name: `Layer ${this.loopLayers.length + 1}`,
              muted: false,
              solo: false,
            });
            console.log('[GrooveLabWebAudio] Layer added, total:', this.loopLayers.length);

            // Auto-start playback after recording
            if (!this.isLooping) {
              // Small delay to ensure buffer is ready
              setTimeout(() => {
                this.startLoopPlayback();
              }, 50);
            }

            resolve({
              success: true,
              layerCount: this.loopLayers.length,
              duration: this.loopDuration,
              layerIndex: this.loopLayers.length - 1,
            });
          } catch (e) {
            console.error('[GrooveLabWebAudio] Failed to decode loop recording:', e);
            resolve({ success: false, layerCount: this.loopLayers.length, error: e.message });
          }
        };

        this._loopMediaRecorder.stop();
        this.isOverdubbing = false;

        // Stop microphone tracks
        if (this._loopMediaStream) {
          this._loopMediaStream.getTracks().forEach(track => track.stop());
          this._loopMediaStream = null;
        }
      });
    }

    startLoopPlayback() {
      if (this.loopLayers.length === 0 || this.loopDuration === 0) {
        console.warn('[GrooveLabWebAudio] No loop layers to play');
        return false;
      }

      // Resume audio context (browser autoplay policy)
      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume();
      }

      this.stopLoopPlayback();
      this.isLooping = true;
      this._loopStartTime = this.ctx.currentTime;

      this._scheduleLoopCycle();

      // Start loop position tracking
      this._startLoopPositionTimer();

      console.log('[GrooveLabWebAudio] Loop playback started,', this.loopLayers.length, 'layers');
      return true;
    }

    _scheduleLoopCycle() {
      if (!this.isLooping) return;

      const startTime = this._loopStartTime;
      const sources = [];

      // Determine if any layer is soloed
      this._soloActive = this.loopLayers.some(l => l.solo);

      for (let i = 0; i < this.loopLayers.length; i++) {
        const layer = this.loopLayers[i];
        const source = this.ctx.createBufferSource();
        source.buffer = layer.buffer;
        source.connect(layer.gainNode);
        source.loop = true;
        source.loopEnd = this.loopDuration;

        // Respect mute/solo: if solo is active, only play soloed layers;
        // otherwise respect muted flag. We do this by setting gain to 0
        // for muted layers rather than not starting them (so we can unmute live).
        if (this._soloActive) {
          layer.gainNode.gain.value = layer.solo ? layer.gainNode.gain.value || 1.0 : 0;
        } else if (layer.muted) {
          layer.gainNode.gain.value = 0;
        }

        source.start(startTime);
        sources.push(source);
      }

      this._loopSources = sources;
    }

    stopLoopPlayback() {
      this.isLooping = false;
      this._stopLoopPositionTimer();
      for (const source of this._loopSources) {
        try {
          source.stop();
        } catch (_) {}
      }
      this._loopSources = [];
    }

    undoLastLayer() {
      if (this.loopLayers.length === 0) return false;

      const removed = this.loopLayers.pop();
      if (removed) {
        if (removed.panNode) removed.panNode.disconnect();
        if (removed.gainNode) removed.gainNode.disconnect();
      }

      // Recalculate solo state
      this._soloActive = this.loopLayers.some(l => l.solo);

      if (this.loopLayers.length === 0) {
        this.loopDuration = 0;
        this.stopLoopPlayback();
      } else if (this.isLooping) {
        // Restart playback without the removed layer
        this.stopLoopPlayback();
        this.isLooping = true;
        this._loopStartTime = this.ctx.currentTime;
        this._scheduleLoopCycle();
        this._startLoopPositionTimer();
      }

      console.log('[GrooveLabWebAudio] Layer undone, remaining:', this.loopLayers.length);
      return true;
    }

    clearLoop() {
      this.stopLoopPlayback();

      // Stop any ongoing recording
      if (this.isOverdubbing) {
        if (this._loopOverdubTimer) {
          clearTimeout(this._loopOverdubTimer);
          this._loopOverdubTimer = null;
        }
        if (this._loopMediaRecorder && this._loopMediaRecorder.state !== 'inactive') {
          this._loopMediaRecorder.stop();
        }
        this.isOverdubbing = false;
        if (this._loopMediaStream) {
          this._loopMediaStream.getTracks().forEach(track => track.stop());
          this._loopMediaStream = null;
        }
      }

      for (const layer of this.loopLayers) {
        if (layer.panNode) layer.panNode.disconnect();
        if (layer.gainNode) layer.gainNode.disconnect();
      }

      this.loopLayers = [];
      this.loopDuration = 0;
      this._loopRecChunks = [];
      this._soloActive = false;
      console.log('[GrooveLabWebAudio] Loop cleared');
      return true;
    }

    setLayerVolume(index, vol) {
      if (index < 0 || index >= this.loopLayers.length) return false;
      const layer = this.loopLayers[index];
      layer.gainNode.gain.value = Math.max(0, Math.min(1, vol));
      return true;
    }

    // ── PER-LAYER CONTROLS ──

    setLayerMute(index, muted) {
      if (index < 0 || index >= this.loopLayers.length) return false;
      const layer = this.loopLayers[index];
      layer.muted = muted;

      // If solo is not active, apply mute directly
      if (!this._soloActive) {
        if (muted) {
          layer._prevGain = layer.gainNode.gain.value;
          layer.gainNode.gain.value = 0;
        } else {
          layer.gainNode.gain.value = layer._prevGain !== undefined ? layer._prevGain : 1.0;
        }
      }
      return true;
    }

    setLayerSolo(index, solo) {
      if (index < 0 || index >= this.loopLayers.length) return false;
      this.loopLayers[index].solo = solo;

      // Recalculate solo state
      this._soloActive = this.loopLayers.some(l => l.solo);

      // Update gains for all layers
      for (let i = 0; i < this.loopLayers.length; i++) {
        const layer = this.loopLayers[i];
        if (this._soloActive) {
          // Only soloed layers are audible
          if (layer.solo) {
            layer.gainNode.gain.value = layer._prevGain !== undefined ? layer._prevGain : 1.0;
          } else {
            if (layer.gainNode.gain.value > 0) {
              layer._prevGain = layer.gainNode.gain.value;
            }
            layer.gainNode.gain.value = 0;
          }
        } else {
          // No solo active: respect mute state
          if (layer.muted) {
            layer.gainNode.gain.value = 0;
          } else {
            layer.gainNode.gain.value = layer._prevGain !== undefined ? layer._prevGain : 1.0;
          }
        }
      }
      return true;
    }

    setLayerPan(index, pan) {
      if (index < 0 || index >= this.loopLayers.length) return false;
      const layer = this.loopLayers[index];
      if (layer.panNode) {
        layer.panNode.pan.value = Math.max(-1, Math.min(1, pan));
      }
      return true;
    }

    deleteLayer(index) {
      if (index < 0 || index >= this.loopLayers.length) return false;

      const removed = this.loopLayers.splice(index, 1)[0];
      if (removed) {
        if (removed.panNode) removed.panNode.disconnect();
        if (removed.gainNode) removed.gainNode.disconnect();
      }

      // Recalculate solo state
      this._soloActive = this.loopLayers.some(l => l.solo);

      if (this.loopLayers.length === 0) {
        this.loopDuration = 0;
        this.stopLoopPlayback();
      } else if (this.isLooping) {
        // Restart playback without the removed layer
        this.stopLoopPlayback();
        this.isLooping = true;
        this._loopStartTime = this.ctx.currentTime;
        this._scheduleLoopCycle();
        this._startLoopPositionTimer();
      }

      console.log('[GrooveLabWebAudio] Layer', index, 'deleted, remaining:', this.loopLayers.length);
      return true;
    }

    renameLayer(index, name) {
      if (index < 0 || index >= this.loopLayers.length) return false;
      this.loopLayers[index].name = name;
      return true;
    }

    // ── INPUT MONITORING ──

    async startInputMonitoring() {
      try {
        await this.resumeContext();
        this._monitorStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        this._monitorSource = this.ctx.createMediaStreamSource(this._monitorStream);
        this._monitorGain = this.ctx.createGain();
        this._monitorGain.gain.value = 1.0;
        this._monitorSource.connect(this._monitorGain);
        this._monitorGain.connect(this.monitorGainNode);
        console.log('[GrooveLabWebAudio] Input monitoring started');
        return true;
      } catch (e) {
        console.error('[GrooveLabWebAudio] Input monitoring failed:', e);
        return false;
      }
    }

    stopInputMonitoring() {
      if (this._monitorSource) {
        this._monitorSource.disconnect();
        this._monitorSource = null;
      }
      if (this._monitorGain) {
        this._monitorGain.disconnect();
        this._monitorGain = null;
      }
      if (this._monitorStream) {
        this._monitorStream.getTracks().forEach(track => track.stop());
        this._monitorStream = null;
      }
      console.log('[GrooveLabWebAudio] Input monitoring stopped');
    }

    setMonitorVolume(vol) {
      if (this.monitorGainNode) {
        this.monitorGainNode.gain.value = Math.max(0, Math.min(1, vol));
      }
    }

    isMonitoring() {
      return this._monitorSource != null;
    }

    // ── INPUT LEVEL METER ──

    async startInputLevelMeter() {
      try {
        await this.resumeContext();
        this._meterStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const source = this.ctx.createMediaStreamSource(this._meterStream);
        this._analyserNode = this.ctx.createAnalyser();
        this._analyserNode.fftSize = 2048;
        source.connect(this._analyserNode);

        const dataArray = new Float32Array(this._analyserNode.fftSize);

        const tick = () => {
          if (!this._analyserNode) return;
          this._analyserNode.getFloatTimeDomainData(dataArray);
          // Calculate RMS
          let sum = 0;
          for (let i = 0; i < dataArray.length; i++) {
            sum += dataArray[i] * dataArray[i];
          }
          const rms = Math.sqrt(sum / dataArray.length);
          // Clamp to 0-1
          const level = Math.min(1, rms * 3); // slight boost so normal levels are visible
          if (this.onInputLevelCallback) {
            this.onInputLevelCallback(level);
          }
          this._levelAnimFrame = requestAnimationFrame(tick);
        };

        this._levelAnimFrame = requestAnimationFrame(tick);
        console.log('[GrooveLabWebAudio] Input level meter started');
        return true;
      } catch (e) {
        console.error('[GrooveLabWebAudio] Input level meter failed:', e);
        return false;
      }
    }

    stopInputLevelMeter() {
      if (this._levelAnimFrame != null) {
        cancelAnimationFrame(this._levelAnimFrame);
        this._levelAnimFrame = null;
      }
      if (this._analyserNode) {
        this._analyserNode.disconnect();
        this._analyserNode = null;
      }
      if (this._meterStream) {
        this._meterStream.getTracks().forEach(track => track.stop());
        this._meterStream = null;
      }
      console.log('[GrooveLabWebAudio] Input level meter stopped');
    }

    // ── TUNER / PITCH DETECTION (YIN Autocorrelation) ──

    async getAudioInputDevices() {
      try {
        // Request permission first so we get labels
        const tempStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        tempStream.getTracks().forEach(t => t.stop());
        const devices = await navigator.mediaDevices.enumerateDevices();
        return devices
          .filter(d => d.kind === 'audioinput')
          .map((d, idx) => ({
            id: d.deviceId,
            name: d.label || `Audio Input ${idx + 1}`
          }));
      } catch(e) {
        console.error('[GrooveLabWebAudio] getAudioInputDevices failed:', e);
        return [];
      }
    }

    async startTuner(deviceId) {
      try {
        await this.resumeContext();
        // Always stop the previous stream so device changes take effect
        if (this._tunerStream) {
          this._tunerStream.getTracks().forEach(t => t.stop());
          this._tunerStream = null;
        }
        if (this._tunerAnalyser) {
          this._tunerAnalyser.disconnect();
          this._tunerAnalyser = null;
        }
        const audioConstraints = {
          echoCancellation: false, noiseSuppression: false, autoGainControl: false
        };
        if (deviceId && deviceId !== '') {
          audioConstraints.deviceId = { exact: deviceId };
        }
        this._tunerStream = await navigator.mediaDevices.getUserMedia({ audio: audioConstraints });
        const source = this.ctx.createMediaStreamSource(this._tunerStream);
        this._tunerAnalyser = this.ctx.createAnalyser();
        this._tunerAnalyser.fftSize = 4096; // Higher for better low-freq resolution
        source.connect(this._tunerAnalyser);

        const bufLen = this._tunerAnalyser.fftSize;
        const buf = new Float32Array(bufLen);
        const sampleRate = this.ctx.sampleRate;

        const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

        const detectPitch = () => {
          if (!this._tunerAnalyser) return;

          this._tunerAnalyser.getFloatTimeDomainData(buf);

          // Check signal level (RMS)
          let rms = 0;
          for (let i = 0; i < bufLen; i++) rms += buf[i] * buf[i];
          rms = Math.sqrt(rms / bufLen);
          if (rms < 0.01) {
            // Too quiet — no note
            if (this.onTunerCallback) {
              this.onTunerCallback({ frequency: 0, note: '-', octave: 0, cents: 0, inTune: false, level: rms });
            }
            this._tunerFrame = requestAnimationFrame(detectPitch);
            return;
          }

          // YIN autocorrelation
          const halfLen = Math.floor(bufLen / 2);
          const yinBuf = new Float32Array(halfLen);
          yinBuf[0] = 1;

          let runningSum = 0;
          for (let tau = 1; tau < halfLen; tau++) {
            let diff = 0;
            for (let i = 0; i < halfLen; i++) {
              const d = buf[i] - buf[i + tau];
              diff += d * d;
            }
            yinBuf[tau] = diff;
            runningSum += diff;
            yinBuf[tau] *= tau / runningSum; // Cumulative mean normalized
          }

          // Find first dip below threshold
          const threshold = 0.15;
          let tauEstimate = -1;
          for (let tau = 2; tau < halfLen; tau++) {
            if (yinBuf[tau] < threshold) {
              while (tau + 1 < halfLen && yinBuf[tau + 1] < yinBuf[tau]) tau++;
              tauEstimate = tau;
              break;
            }
          }

          if (tauEstimate === -1) {
            if (this.onTunerCallback) {
              this.onTunerCallback({ frequency: 0, note: '-', octave: 0, cents: 0, inTune: false, level: rms });
            }
            this._tunerFrame = requestAnimationFrame(detectPitch);
            return;
          }

          // Parabolic interpolation for sub-sample accuracy
          const s0 = yinBuf[tauEstimate - 1];
          const s1 = yinBuf[tauEstimate];
          const s2 = tauEstimate + 1 < halfLen ? yinBuf[tauEstimate + 1] : s1;
          const betterTau = tauEstimate + (s2 - s0) / (2 * (2 * s1 - s2 - s0));
          const frequency = sampleRate / betterTau;

          // Frequency to note
          if (frequency < 25 || frequency > 2000) {
            if (this.onTunerCallback) {
              this.onTunerCallback({ frequency: 0, note: '-', octave: 0, cents: 0, inTune: false, level: rms });
            }
            this._tunerFrame = requestAnimationFrame(detectPitch);
            return;
          }

          const midiNum = 12 * (Math.log2(frequency / 440)) + 69;
          const roundedMidi = Math.round(midiNum);
          const cents = Math.round((midiNum - roundedMidi) * 100);
          const noteIdx = ((roundedMidi % 12) + 12) % 12;
          const octave = Math.floor(roundedMidi / 12) - 1;
          const note = NOTE_NAMES[noteIdx];
          const inTune = Math.abs(cents) <= 5;

          if (this.onTunerCallback) {
            this.onTunerCallback({
              frequency: Math.round(frequency * 10) / 10,
              note, octave, cents, inTune, level: rms
            });
          }

          this._tunerFrame = requestAnimationFrame(detectPitch);
        };

        this._tunerFrame = requestAnimationFrame(detectPitch);
        console.log('[GrooveLabWebAudio] Tuner started');
        return true;
      } catch (e) {
        console.error('[GrooveLabWebAudio] Tuner failed:', e);
        return false;
      }
    }

    stopTuner() {
      if (this._tunerFrame != null) {
        cancelAnimationFrame(this._tunerFrame);
        this._tunerFrame = null;
      }
      if (this._tunerAnalyser) {
        this._tunerAnalyser.disconnect();
        this._tunerAnalyser = null;
      }
      if (this._tunerStream) {
        this._tunerStream.getTracks().forEach(t => t.stop());
        this._tunerStream = null;
      }
      console.log('[GrooveLabWebAudio] Tuner stopped');
    }

    // ── LOOP POSITION TRACKING ──

    _startLoopPositionTimer() {
      this._stopLoopPositionTimer();
      if (!this.isLooping || this.loopDuration === 0) return;
      this._loopPositionTimer = setInterval(() => {
        if (!this.isLooping || this.loopDuration === 0) {
          this._stopLoopPositionTimer();
          return;
        }
        const elapsed = this.ctx.currentTime - this._loopStartTime;
        const position = (elapsed % this.loopDuration) / this.loopDuration;
        if (this.onLoopPositionCallback) {
          this.onLoopPositionCallback(Math.max(0, Math.min(1, position)));
        }
      }, 50);
    }

    _stopLoopPositionTimer() {
      if (this._loopPositionTimer != null) {
        clearInterval(this._loopPositionTimer);
        this._loopPositionTimer = null;
      }
    }

    // ── EXPORT MIXDOWN ──

    async exportMixdown(format, includeGuide) {
      if (this.loopLayers.length === 0 || this.loopDuration === 0) {
        console.warn('[GrooveLabWebAudio] No loop layers to export');
        return null;
      }

      const sampleRate = this.ctx.sampleRate;
      const length = Math.ceil(this.loopDuration * sampleRate);
      const numberOfChannels = 2; // stereo output
      const offlineCtx = new OfflineAudioContext(numberOfChannels, length, sampleRate);

      // Create a master gain in the offline context
      const offlineMaster = offlineCtx.createGain();
      offlineMaster.gain.value = 1.0;
      offlineMaster.connect(offlineCtx.destination);

      for (let i = 0; i < this.loopLayers.length; i++) {
        const layer = this.loopLayers[i];

        // Skip muted layers (respect solo)
        if (this._soloActive && !layer.solo) continue;
        if (!this._soloActive && layer.muted) continue;

        const source = offlineCtx.createBufferSource();
        source.buffer = layer.buffer;

        const gainNode = offlineCtx.createGain();
        gainNode.gain.value = layer.gainNode.gain.value;

        const panNode = offlineCtx.createStereoPanner();
        panNode.pan.value = layer.panNode ? layer.panNode.pan.value : 0;

        source.connect(gainNode);
        gainNode.connect(panNode);
        panNode.connect(offlineMaster);
        source.start(0);
      }

      // Render guide track (metronome/drum clicks) into the offline context
      if (includeGuide) {
        const guideGain = offlineCtx.createGain();
        guideGain.gain.value = this.guideGain ? this.guideGain.gain.value : 1.0;
        guideGain.connect(offlineMaster);

        const beatDuration = 60.0 / this.bpm;
        const totalBeats = Math.floor(this.loopDuration / beatDuration);

        if (this.isDrumMode) {
          // Schedule drum pattern hits
          const stepsPerBeat = this.drumStepsPerBeat || 4;
          const stepDuration = beatDuration / stepsPerBeat;
          const totalSteps = this.beatsPerBar * stepsPerBeat;

          for (let t = 0; t < this.loopDuration; t += stepDuration) {
            const stepInBar = Math.round(t / stepDuration) % totalSteps;
            for (const [track, steps] of Object.entries(this.drumPattern)) {
              if (steps && stepInBar < steps.length && steps[stepInBar] > 0) {
                const baseVol = this.drumVolumes[track] !== undefined ? this.drumVolumes[track] : 0.8;
                const key = this._drumTrackToKey(track);
                const buffer = this.buffers[key];
                if (buffer) {
                  const src = offlineCtx.createBufferSource();
                  src.buffer = buffer;
                  const gn = offlineCtx.createGain();
                  gn.gain.value = Math.max(0, Math.min(1, baseVol));
                  src.connect(gn);
                  gn.connect(guideGain);
                  src.start(t);
                }
              }
            }
          }
        } else {
          // Schedule metronome clicks
          const subBeatDuration = beatDuration / Math.max(1, this.subdivision);

          for (let t = 0; t < this.loopDuration; t += subBeatDuration) {
            const beatIndex = Math.floor(t / beatDuration);
            const beatInBar = beatIndex % this.beatsPerBar;
            const subBeatIndex = Math.round((t - beatIndex * beatDuration) / subBeatDuration);
            const isSubBeat = subBeatIndex > 0;

            const soundKey = this._getSoundKey(beatInBar, isSubBeat);
            const volume = this._getVolume(beatInBar, isSubBeat);
            const buffer = this.buffers[soundKey];

            if (buffer) {
              const src = offlineCtx.createBufferSource();
              src.buffer = buffer;
              const gn = offlineCtx.createGain();
              gn.gain.value = Math.max(0, Math.min(1, volume));
              src.connect(gn);
              gn.connect(guideGain);
              src.start(t);
            }
          }
        }
      }

      const renderedBuffer = await offlineCtx.startRendering();

      // Encode as WAV (for both 'wav' and 'mp3' since browser MP3 encoding is impractical)
      const wavBlob = this._encodeWav(renderedBuffer);

      // Revoke old URL if any
      if (this._lastExportUrl) {
        URL.revokeObjectURL(this._lastExportUrl);
      }

      this._lastExportUrl = URL.createObjectURL(wavBlob);
      console.log('[GrooveLabWebAudio] Mixdown exported, format:', format || 'wav', 'size:', wavBlob.size);
      return this._lastExportUrl;
    }

    _encodeWav(audioBuffer) {
      const numChannels = audioBuffer.numberOfChannels;
      const sampleRate = audioBuffer.sampleRate;
      const length = audioBuffer.length;
      const bitsPerSample = 16;
      const bytesPerSample = bitsPerSample / 8;
      const blockAlign = numChannels * bytesPerSample;
      const dataSize = length * blockAlign;
      const headerSize = 44;
      const buffer = new ArrayBuffer(headerSize + dataSize);
      const view = new DataView(buffer);

      // Helper to write string
      const writeString = (offset, str) => {
        for (let i = 0; i < str.length; i++) {
          view.setUint8(offset + i, str.charCodeAt(i));
        }
      };

      // RIFF header
      writeString(0, 'RIFF');
      view.setUint32(4, headerSize + dataSize - 8, true);
      writeString(8, 'WAVE');

      // fmt chunk
      writeString(12, 'fmt ');
      view.setUint32(16, 16, true); // chunk size
      view.setUint16(20, 1, true);  // PCM format
      view.setUint16(22, numChannels, true);
      view.setUint32(24, sampleRate, true);
      view.setUint32(28, sampleRate * blockAlign, true); // byte rate
      view.setUint16(32, blockAlign, true);
      view.setUint16(34, bitsPerSample, true);

      // data chunk
      writeString(36, 'data');
      view.setUint32(40, dataSize, true);

      // Get channel data
      const channels = [];
      for (let ch = 0; ch < numChannels; ch++) {
        channels.push(audioBuffer.getChannelData(ch));
      }

      // Interleave and write PCM samples
      let offset = headerSize;
      for (let i = 0; i < length; i++) {
        for (let ch = 0; ch < numChannels; ch++) {
          let sample = channels[ch][i];
          // Clamp
          sample = Math.max(-1, Math.min(1, sample));
          // Convert to 16-bit integer
          const int16 = sample < 0 ? sample * 0x8000 : sample * 0x7FFF;
          view.setInt16(offset, int16, true);
          offset += 2;
        }
      }

      return new Blob([buffer], { type: 'audio/wav' });
    }

    // ── WAVEFORM DATA EXTRACTION ──

    getLayerWaveform(index, numSamples) {
      if (index < 0 || index >= this.loopLayers.length) return [];
      const layer = this.loopLayers[index];
      const buffer = layer.buffer;
      if (!buffer || numSamples <= 0) return [];

      const channelData = buffer.getChannelData(0);
      const totalSamples = channelData.length;
      const samplesPerChunk = totalSamples / numSamples;
      const peaks = new Array(numSamples);

      for (let i = 0; i < numSamples; i++) {
        const start = Math.floor(i * samplesPerChunk);
        const end = Math.min(Math.floor((i + 1) * samplesPerChunk), totalSamples);
        let max = 0;
        for (let j = start; j < end; j++) {
          const abs = Math.abs(channelData[j]);
          if (abs > max) max = abs;
        }
        peaks[i] = max;
      }

      return peaks;
    }

    // ── LOOP STATE ──

    getLoopState() {
      return {
        layerCount: this.loopLayers.length,
        duration: this.loopDuration,
        isPlaying: this.isLooping,
        isRecording: this.isOverdubbing,
        layers: this.loopLayers.map((l, i) => ({
          name: l.name || `Layer ${i + 1}`,
          volume: l.gainNode.gain.value,
          pan: l.panNode ? l.panNode.pan.value : 0,
          muted: l.muted || false,
          solo: l.solo || false,
        })),
        position: this.isLooping ? ((this.ctx.currentTime - this._loopStartTime) % this.loopDuration) / this.loopDuration : 0,
        isMonitoring: this._monitorSource != null,
      };
    }

    // ── MIDI ──

    async initMidi() {
      if (!navigator.requestMIDIAccess) {
        console.warn('[GrooveLabWebAudio] Web MIDI API not supported');
        return [];
      }
      try {
        this.midiAccess = await navigator.requestMIDIAccess({ sysex: false });
        this.midiEnabled = true;

        // Listen for device connect/disconnect
        this.midiAccess.onstatechange = (event) => {
          console.log('[GrooveLabWebAudio] MIDI state change:', event.port.name, event.port.state);
          this._updateMidiInputs();
        };

        this._updateMidiInputs();

        const names = this.midiInputs.map(input => input.name || 'Unknown');
        console.log('[GrooveLabWebAudio] MIDI initialized, inputs:', names);
        return this.getMidiDevices();
      } catch (e) {
        console.error('[GrooveLabWebAudio] MIDI init failed:', e);
        return [];
      }
    }

    _updateMidiInputs() {
      // Remove old listeners
      for (const input of this.midiInputs) {
        input.onmidimessage = null;
      }

      this.midiInputs = [];
      if (!this.midiAccess) return;

      for (const input of this.midiAccess.inputs.values()) {
        if (input.state === 'connected') {
          this.midiInputs.push(input);
          input.onmidimessage = (event) => this._onMidiMessage(event);
        }
      }
    }

    _onMidiMessage(event) {
      if (!event.data || event.data.length < 2) return;

      const status = event.data[0];
      const note = event.data[1];
      const velocity = event.data.length > 2 ? event.data[2] : 0;

      // Parse status byte (high nibble)
      const statusType = status & 0xF0;
      let type = 'unknown';

      if (statusType === 0x90 && velocity > 0) {
        type = 'noteOn';
      } else if (statusType === 0x80 || (statusType === 0x90 && velocity === 0)) {
        type = 'noteOff';
      } else if (statusType === 0xB0) {
        type = 'cc';
      } else {
        return; // Ignore other message types
      }

      // Check for MIDI loop station mappings (noteOn only)
      if (type === 'noteOn' && this.midiLoopMappings[note]) {
        const loopAction = this.midiLoopMappings[note];
        this._executeMidiLoopAction(loopAction);
      }

      // Determine action from mappings or defaults
      let action = this.midiMappings[note] || '';
      if (!action && type === 'noteOn') {
        // Default MIDI note mappings
        switch (note) {
          case 36: action = 'kick'; break;      // C2 = kick / tap tempo
          case 38: action = 'snare'; break;     // D2 = snare
          case 42: action = 'hihat'; break;     // F#2 = hi-hat
          default: action = 'tap'; break;       // Any other note = tap tempo
        }
      }
      if (type === 'cc' && note === 1) {
        action = 'bpm'; // Mod wheel = BPM control
      }

      // Fire callback to Dart
      if (this.onMidiEvent) {
        this.onMidiEvent(status, note, velocity, type, action);
      }
    }

    // ── MIDI LOOP STATION MAPPING ──

    setMidiLoopMapping(action, noteNumber) {
      this.midiLoopMappings[noteNumber] = action;
      console.log('[GrooveLabWebAudio] MIDI loop mapping set:', noteNumber, '->', action);
    }

    _executeMidiLoopAction(action) {
      switch (action) {
        case 'record':
          this.startLoopRecording();
          break;
        case 'stop':
          if (this.isOverdubbing) {
            this.stopLoopRecording();
          } else {
            this.stopLoopPlayback();
          }
          break;
        case 'play':
          this.startLoopPlayback();
          break;
        case 'overdub':
          if (this.isOverdubbing) {
            this.stopLoopRecording();
          } else {
            this.startLoopRecording();
          }
          break;
        case 'undo':
          this.undoLastLayer();
          break;
        case 'clear':
          this.clearLoop();
          break;
        default:
          console.log('[GrooveLabWebAudio] Unknown MIDI loop action:', action);
      }
    }

    getMidiDevices() {
      if (!this.midiAccess) return [];
      const devices = [];
      for (const input of this.midiAccess.inputs.values()) {
        if (input.state === 'connected') {
          devices.push({
            id: input.id,
            name: input.name || 'Unknown',
            manufacturer: input.manufacturer || 'Unknown',
          });
        }
      }
      return devices;
    }

    setMidiMapping(noteNumber, action) {
      this.midiMappings[noteNumber] = action;
      console.log('[GrooveLabWebAudio] MIDI mapping set:', noteNumber, '->', action);
    }

    disconnectMidi() {
      // Remove listeners from all inputs
      for (const input of this.midiInputs) {
        input.onmidimessage = null;
      }
      this.midiInputs = [];

      if (this.midiAccess) {
        this.midiAccess.onstatechange = null;
      }

      this.midiEnabled = false;
      this.midiAccess = null;
      console.log('[GrooveLabWebAudio] MIDI disconnected');
    }

    // ── LOOP BEAT INFO ──

    getLoopBeatInfo() {
      if (!this.isLooping || this.loopDuration === 0) {
        return { beat: 0, bar: 0, totalBeats: 0, totalBars: 0, beatInBar: 0 };
      }
      const elapsed = this.ctx.currentTime - this._loopStartTime;
      const positionInLoop = elapsed % this.loopDuration;
      const beatDuration = 60.0 / this.bpm;
      const currentBeat = Math.floor(positionInLoop / beatDuration);
      const totalBeats = Math.floor(this.loopDuration / beatDuration);
      const beatsPerBar = this.beatsPerBar || 4;
      const currentBar = Math.floor(currentBeat / beatsPerBar);
      const totalBars = Math.ceil(totalBeats / beatsPerBar);
      const beatInBar = currentBeat % beatsPerBar;
      return {
        beat: currentBeat,
        bar: currentBar,
        totalBeats: totalBeats,
        totalBars: totalBars,
        beatInBar: beatInBar,
        beatsPerBar: beatsPerBar
      };
    }

    // ── STEM EXPORT ──

    async exportStems() {
      if (this.loopLayers.length === 0 || this.loopDuration === 0) return null;

      const stems = [];
      const sampleRate = this.ctx.sampleRate;
      const length = Math.ceil(this.loopDuration * sampleRate);

      for (let i = 0; i < this.loopLayers.length; i++) {
        const layer = this.loopLayers[i];
        if (layer.muted) continue; // Skip muted layers

        const offlineCtx = new OfflineAudioContext(2, length, sampleRate);
        const source = offlineCtx.createBufferSource();
        source.buffer = layer.buffer;

        const gainNode = offlineCtx.createGain();
        gainNode.gain.value = layer.gainNode.gain.value;

        const panNode = offlineCtx.createStereoPanner();
        panNode.pan.value = layer.panNode ? layer.panNode.pan.value : 0;

        source.connect(gainNode);
        gainNode.connect(panNode);
        panNode.connect(offlineCtx.destination);
        source.start(0);

        const rendered = await offlineCtx.startRendering();
        const wavBlob = this._encodeWav(rendered);
        const url = URL.createObjectURL(wavBlob);

        stems.push({
          index: i,
          name: layer.name || ('Layer ' + (i + 1)),
          url: url,
          size: wavBlob.size,
        });
      }

      return stems;
    }

    async exportSelectedLayers(indices) {
      if (this.loopLayers.length === 0 || this.loopDuration === 0) return null;

      const sampleRate = this.ctx.sampleRate;
      const length = Math.ceil(this.loopDuration * sampleRate);
      const offlineCtx = new OfflineAudioContext(2, length, sampleRate);

      const offlineMaster = offlineCtx.createGain();
      offlineMaster.gain.value = 1.0;
      offlineMaster.connect(offlineCtx.destination);

      for (const idx of indices) {
        if (idx < 0 || idx >= this.loopLayers.length) continue;
        const layer = this.loopLayers[idx];

        const source = offlineCtx.createBufferSource();
        source.buffer = layer.buffer;

        const gainNode = offlineCtx.createGain();
        gainNode.gain.value = layer.gainNode.gain.value;

        const panNode = offlineCtx.createStereoPanner();
        panNode.pan.value = layer.panNode ? layer.panNode.pan.value : 0;

        source.connect(gainNode);
        gainNode.connect(panNode);
        panNode.connect(offlineMaster);
        source.start(0);
      }

      const rendered = await offlineCtx.startRendering();
      const wavBlob = this._encodeWav(rendered);

      if (this._lastExportUrl) URL.revokeObjectURL(this._lastExportUrl);
      this._lastExportUrl = URL.createObjectURL(wavBlob);
      return this._lastExportUrl;
    }

    // ── HEADPHONE DETECTION ──

    async checkAudioOutputDevices() {
      try {
        const devices = await navigator.mediaDevices.enumerateDevices();
        const outputDevices = devices
          .filter(d => d.kind === 'audiooutput')
          .map(d => ({ label: d.label || 'Unknown output', deviceId: d.deviceId }));

        // Heuristic: check if any output device label suggests headphones
        const hasHeadphones = outputDevices.some(d => {
          const label = d.label.toLowerCase();
          return label.includes('headphone') || label.includes('earphone') ||
                 label.includes('airpod') || label.includes('earbud') ||
                 label.includes('headset');
        });

        return { hasHeadphones, outputDevices };
      } catch (e) {
        console.warn('[GrooveLabWebAudio] Could not enumerate audio devices:', e);
        return { hasHeadphones: false, outputDevices: [] };
      }
    }

    // ── PAD SYSTEM ──

    async loadPad(audioData, name, originalKey, originalTempo) {
      if (!this.ctx) return { success: false, error: 'AudioContext not initialized' };
      try {
        const copy = audioData.slice(0);
        const buffer = await this.ctx.decodeAudioData(copy);

        const gainNode = this.ctx.createGain();
        gainNode.gain.value = 1.0;

        const panNode = this.ctx.createStereoPanner();
        panNode.pan.value = 0;

        gainNode.connect(panNode);
        panNode.connect(this.padMasterGain);

        const padIndex = this.pads.length;
        this.pads.push({
          buffer: buffer,
          source: null,
          gainNode: gainNode,
          panNode: panNode,
          name: name || ('Pad ' + padIndex),
          key: originalKey || 'C',
          tempo: originalTempo || 120,
          volume: 1.0,
          playing: false,
          loop: false,
        });

        console.log('[GrooveLabWebAudio] Pad loaded:', name, 'index:', padIndex, 'duration:', buffer.duration);
        return { success: true, padIndex: padIndex, duration: buffer.duration };
      } catch (e) {
        console.error('[GrooveLabWebAudio] Failed to load pad:', e);
        return { success: false, error: e.message };
      }
    }

    async loadPadFromUrl(url, name, originalKey, originalTempo) {
      if (!this.ctx) return { success: false, error: 'AudioContext not initialized' };
      try {
        const response = await fetch(url);
        if (!response.ok) throw new Error('HTTP ' + response.status + ' fetching ' + url);
        const arrayBuffer = await response.arrayBuffer();
        return await this.loadPad(arrayBuffer, name, originalKey, originalTempo);
      } catch (e) {
        console.error('[GrooveLabWebAudio] Failed to load pad from URL:', url, e);
        return { success: false, error: e.message };
      }
    }

    playPad(index, loop) {
      if (index < 0 || index >= this.pads.length) return false;
      if (!this.ctx) return false;

      const pad = this.pads[index];

      // Stop any currently playing source for this pad
      if (pad.source) {
        try { pad.source.stop(); } catch (e) { /* already stopped */ }
        pad.source = null;
      }

      const source = this.ctx.createBufferSource();
      source.buffer = pad.buffer;
      source.loop = loop !== undefined ? loop : false;

      source.connect(pad.gainNode);
      pad.source = source;
      pad.playing = true;
      pad.loop = source.loop;

      source.onended = () => {
        if (pad.source === source) {
          pad.playing = false;
          pad.source = null;
        }
      };

      source.start(0);
      console.log('[GrooveLabWebAudio] Pad playing:', pad.name, 'loop:', source.loop);
      return true;
    }

    stopPad(index) {
      if (index < 0 || index >= this.pads.length) return false;
      const pad = this.pads[index];
      if (pad.source) {
        try { pad.source.stop(); } catch (e) { /* already stopped */ }
        pad.source = null;
      }
      pad.playing = false;
      return true;
    }

    stopAllPads() {
      for (let i = 0; i < this.pads.length; i++) {
        this.stopPad(i);
      }
    }

    setPadVolume(index, volume) {
      if (index < 0 || index >= this.pads.length) return false;
      const pad = this.pads[index];
      const v = Math.max(0, Math.min(1, volume));
      pad.volume = v;
      pad.gainNode.gain.value = v;
      return true;
    }

    setPadPan(index, pan) {
      if (index < 0 || index >= this.pads.length) return false;
      const pad = this.pads[index];
      pad.panNode.pan.value = Math.max(-1, Math.min(1, pan));
      return true;
    }

    setPadPitch(index, semitones) {
      if (index < 0 || index >= this.pads.length) return false;
      const pad = this.pads[index];
      const clamped = Math.max(-12, Math.min(12, semitones));
      const rate = Math.pow(2, clamped / 12);
      if (pad.source) {
        pad.source.playbackRate.value = rate;
      }
      return true;
    }

    setPadTempo(index, targetBpm) {
      if (index < 0 || index >= this.pads.length) return false;
      const pad = this.pads[index];
      if (!pad.tempo || pad.tempo <= 0) return false;
      const rate = targetBpm / pad.tempo;
      if (pad.source) {
        pad.source.playbackRate.value = rate;
      }
      return true;
    }

    removePad(index) {
      if (index < 0 || index >= this.pads.length) return false;
      this.stopPad(index);
      const pad = this.pads[index];
      try {
        pad.gainNode.disconnect();
        pad.panNode.disconnect();
      } catch (e) { /* already disconnected */ }
      this.pads.splice(index, 1);
      console.log('[GrooveLabWebAudio] Pad removed at index:', index);
      return true;
    }

    getPadState() {
      return this.pads.map((pad, i) => ({
        index: i,
        name: pad.name,
        key: pad.key,
        tempo: pad.tempo,
        volume: pad.volume,
        pan: pad.panNode ? pad.panNode.pan.value : 0,
        playing: pad.playing,
        loop: pad.loop,
        duration: pad.buffer ? pad.buffer.duration : 0,
      }));
    }

    setPadMasterVolume(volume) {
      if (!this.padMasterGain) return false;
      this.padMasterGain.gain.value = Math.max(0, Math.min(1, volume));
      return true;
    }

    setPadRouting(padPan, guidePan) {
      if (this.padPanNode) {
        this.padPanNode.pan.value = Math.max(-1, Math.min(1, padPan));
      }
      if (this.guidePanNode) {
        this.guidePanNode.pan.value = Math.max(-1, Math.min(1, guidePan));
      }
      console.log('[GrooveLabWebAudio] Pad routing set - pad:', padPan, 'guide:', guidePan);
      return true;
    }

    // ── PAD CROSSFADE ENGINE ──

    setActivePadSound(index) {
      if (index < 0 || index >= this.pads.length) return false;
      this._activePadIndex = index;
      console.log('[GrooveLabWebAudio] Active pad sound set to:', this.pads[index].name);
      return true;
    }

    getActivePadIndex() {
      return this._activePadIndex;
    }

    getActivePadKey() {
      return this._activePadKey;
    }

    setPadTransition(mode, time) {
      this._padTransitionMode = mode || 'smooth';
      this._padTransitionTime = time !== undefined ? time : 1.2;
      console.log('[GrooveLabWebAudio] Pad transition:', mode, time + 's');
    }

    setPadHold(hold) {
      this._padHold = !!hold;
      return true;
    }

    isPadHolding() {
      return this._padHold;
    }

    /**
     * Play the active pad sound at a specific musical key with crossfade.
     * This is the core method for the 12-key grid.
     * @param {string} targetKey - Musical key (C, C#, D, etc.)
     * @param {number} crossfadeTime - Override crossfade duration (optional)
     * @returns {boolean} success
     */
    playPadAtKey(targetKey, crossfadeTime) {
      if (this._activePadIndex < 0 || this._activePadIndex >= this.pads.length) return false;
      if (!this.ctx) return false;

      const pad = this.pads[this._activePadIndex];
      if (!pad || !pad.buffer) return false;

      const fadeTime = crossfadeTime !== undefined ? crossfadeTime : this._padTransitionTime;
      const keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
      const fromIdx = keys.indexOf(pad.key || 'C');
      const toIdx = keys.indexOf(targetKey);
      if (toIdx < 0) return false;

      let semitones = toIdx - fromIdx;
      if (semitones > 6) semitones -= 12;
      if (semitones < -6) semitones += 12;
      const playbackRate = Math.pow(2, semitones / 12);

      const now = this.ctx.currentTime;

      // If same key is already playing, do nothing
      if (this._activePadKey === targetKey && pad.playing) return true;

      // Fade out all currently playing crossfade sources
      this._fadeOutCrossfadeSources(fadeTime);

      // Create new source
      const source = this.ctx.createBufferSource();
      source.buffer = pad.buffer;
      source.loop = true;
      source.playbackRate.value = playbackRate;

      // Create individual gain for crossfade control
      const fadeGain = this.ctx.createGain();
      fadeGain.gain.setValueAtTime(0, now);
      fadeGain.gain.linearRampToValueAtTime(pad.volume, now + Math.max(fadeTime, 0.02));

      source.connect(fadeGain);
      fadeGain.connect(pad.gainNode);

      source.start(0);

      // Track this source for future crossfades
      const sourceEntry = { source, fadeGain, key: targetKey, startTime: now };
      this._padCrossfadeSources.push(sourceEntry);

      // Update state
      this._activePadKey = targetKey;
      pad.playing = true;

      // Cleanup old sources after fade completes
      setTimeout(() => {
        this._cleanupExpiredSources();
      }, (fadeTime + 0.5) * 1000);

      console.log('[GrooveLabWebAudio] Pad crossfade to key:', targetKey, 'semitones:', semitones, 'fade:', fadeTime + 's');
      return true;
    }

    _fadeOutCrossfadeSources(fadeTime) {
      if (!this.ctx) return;
      const now = this.ctx.currentTime;

      for (const entry of this._padCrossfadeSources) {
        if (entry._fading) continue;
        entry._fading = true;
        try {
          entry.fadeGain.gain.cancelScheduledValues(now);
          entry.fadeGain.gain.setValueAtTime(entry.fadeGain.gain.value, now);
          entry.fadeGain.gain.linearRampToValueAtTime(0, now + Math.max(fadeTime, 0.02));
          // Schedule stop after fade
          entry.source.stop(now + fadeTime + 0.1);
        } catch (e) { /* already stopped */ }
      }
    }

    _cleanupExpiredSources() {
      this._padCrossfadeSources = this._padCrossfadeSources.filter(entry => {
        if (entry._fading) {
          try {
            entry.fadeGain.disconnect();
          } catch (e) { /* already disconnected */ }
          return false;
        }
        return true;
      });
    }

    /**
     * Stop the pad with a fade out
     * @param {number} fadeTime - Fade out duration in seconds
     */
    fadeOutActivePad(fadeTime) {
      if (!this.ctx) return false;
      const ft = fadeTime !== undefined ? fadeTime : this._padTransitionTime;

      this._fadeOutCrossfadeSources(ft);

      // Update pad state
      if (this._activePadIndex >= 0 && this._activePadIndex < this.pads.length) {
        const pad = this.pads[this._activePadIndex];
        setTimeout(() => {
          pad.playing = false;
          this._activePadKey = null;
        }, ft * 1000);
      }

      console.log('[GrooveLabWebAudio] Pad fade out:', ft + 's');
      return true;
    }

    /**
     * Immediately stop the active pad (no fade)
     */
    stopActivePad() {
      for (const entry of this._padCrossfadeSources) {
        try {
          entry.source.stop();
          entry.fadeGain.disconnect();
        } catch (e) { /* already stopped */ }
      }
      this._padCrossfadeSources = [];

      if (this._activePadIndex >= 0 && this._activePadIndex < this.pads.length) {
        this.pads[this._activePadIndex].playing = false;
      }
      this._activePadKey = null;
      return true;
    }

    /**
     * Check if the active pad is currently playing
     */
    isActivePadPlaying() {
      if (this._activePadIndex < 0) return false;
      if (this._activePadIndex >= this.pads.length) return false;
      return this.pads[this._activePadIndex].playing;
    }

    // ══════════════════════════════════════════════════════
    // SONG LAB - Multi-track stem player with DSP controls
    // ══════════════════════════════════════════════════════

    async songLabLoadTrack(arrayBuffer, name, type) {
      try {
        await this.resumeContext();
        const audioBuffer = await this.ctx.decodeAudioData(arrayBuffer);

        const gainNode = this.ctx.createGain();
        gainNode.gain.value = 1.0;
        const panNode = this.ctx.createStereoPanner();
        panNode.pan.value = 0;
        gainNode.connect(panNode);
        panNode.connect(this.songLabMasterGain);

        const track = {
          buffer: audioBuffer,
          gainNode: gainNode,
          panNode: panNode,
          name: name,
          type: type,
          muted: false,
          solo: false,
          _prevGain: 1.0,
        };

        this.songLabTracks.push(track);

        // Set duration from longest track
        if (audioBuffer.duration > this.songLabDuration) {
          this.songLabDuration = audioBuffer.duration;
        }

        console.log('[SongLab] Track loaded:', name, type, audioBuffer.duration.toFixed(2) + 's');
        return {
          success: true,
          trackIndex: this.songLabTracks.length - 1,
          duration: audioBuffer.duration,
          sampleRate: audioBuffer.sampleRate,
        };
      } catch (e) {
        console.error('[SongLab] Track load failed:', e);
        return { success: false, error: e.message };
      }
    }

    songLabPlay() {
      if (this.songLabTracks.length === 0 || this.songLabDuration === 0) {
        console.warn('[SongLab] No tracks to play');
        return false;
      }

      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume();
      }

      this.songLabPlaying = true;
      this._songLabScheduleSources(this.songLabPauseOffset);
      this._songLabStartPositionTimer();

      console.log('[SongLab] Playing from', this.songLabPauseOffset.toFixed(2) + 's');

      // Start click track if enabled
      if (this._songLabClickEnabled) {
        this._startSongLabClick();
      }

      return true;
    }

    songLabPause() {
      if (!this.songLabPlaying) return;

      const combinedRate = this.songLabSpeed;
      const elapsed = (this.ctx.currentTime - this.songLabStartTime) * combinedRate;
      this.songLabPauseOffset = elapsed % this.songLabDuration;
      this.songLabPlaying = false;

      this._songLabStopSources();
      this._songLabStopPositionTimer();

      // Stop click track
      if (this._songLabClickInterval) {
        clearInterval(this._songLabClickInterval);
        this._songLabClickInterval = null;
      }

      console.log('[SongLab] Paused at', this.songLabPauseOffset.toFixed(2) + 's');
    }

    songLabStop() {
      this.songLabPlaying = false;
      this.songLabPauseOffset = 0;

      this._songLabStopSources();
      this._songLabStopPositionTimer();

      // Stop click track
      if (this._songLabClickInterval) {
        clearInterval(this._songLabClickInterval);
        this._songLabClickInterval = null;
      }

      if (this.onSongLabPositionCallback) {
        this.onSongLabPositionCallback(0);
      }

      console.log('[SongLab] Stopped');
    }

    songLabSeek(timeSeconds) {
      const clampedTime = Math.max(0, Math.min(timeSeconds, this.songLabDuration));
      this.songLabPauseOffset = clampedTime;

      if (this.songLabPlaying) {
        // _songLabScheduleSources handles stopping old sources and setting startTime
        this._songLabScheduleSources(clampedTime);
      }

      if (this.onSongLabPositionCallback) {
        this.onSongLabPositionCallback(clampedTime);
      }
    }

    songLabSetTrackVolume(index, vol) {
      if (index < 0 || index >= this.songLabTracks.length) return false;
      const track = this.songLabTracks[index];
      track._prevGain = Math.max(0, Math.min(1, vol));
      if (!track.muted && (!this._songLabSoloActive || track.solo)) {
        track.gainNode.gain.value = track._prevGain;
      }
      return true;
    }

    songLabSetTrackPan(index, pan) {
      if (index < 0 || index >= this.songLabTracks.length) return false;
      this.songLabTracks[index].panNode.pan.value = Math.max(-1, Math.min(1, pan));
      return true;
    }

    songLabSetTrackMute(index, muted) {
      if (index < 0 || index >= this.songLabTracks.length) return false;
      const track = this.songLabTracks[index];
      track.muted = muted;
      if (!this._songLabSoloActive) {
        track.gainNode.gain.value = muted ? 0 : track._prevGain;
      }
      return true;
    }

    songLabSetTrackSolo(index, solo) {
      if (index < 0 || index >= this.songLabTracks.length) return false;
      this.songLabTracks[index].solo = solo;
      this._songLabSoloActive = this.songLabTracks.some(t => t.solo);

      for (const track of this.songLabTracks) {
        if (this._songLabSoloActive) {
          track.gainNode.gain.value = track.solo ? track._prevGain : 0;
        } else {
          track.gainNode.gain.value = track.muted ? 0 : track._prevGain;
        }
      }
      return true;
    }

    songLabSetSpeed(rate) {
      this.songLabSpeed = Math.max(0.25, Math.min(2.0, rate));
      // Speed only changes playbackRate on active sources
      for (const source of this.songLabSources) {
        if (source && !source._stopped) {
          try { source.playbackRate.value = this.songLabSpeed; } catch(_) {}
        }
      }
      console.log('[SongLab] Speed set to', this.songLabSpeed);
    }

    songLabSetPitchShift(semitones) {
      const prev = this.songLabPitchShift;
      this.songLabPitchShift = Math.max(-12, Math.min(12, semitones));
      if (this.songLabPitchShift === prev) return;

      console.log('[SongLab] Pitch shift set to', this.songLabPitchShift, 'semitones');

      // Pre-render pitch-shifted buffers for each track
      this._songLabRebuildPitchedBuffers().then(() => {
        // If playing, restart with new buffers
        if (this.songLabPlaying) {
          const pos = this.songLabGetPosition();
          this._songLabScheduleSources(pos);
        }
      });
    }

    async _songLabRebuildPitchedBuffers() {
      if (this.songLabPitchShift === 0) {
        // Reset to original buffers
        for (const track of this.songLabTracks) {
          if (track._originalBuffer) {
            track.buffer = track._originalBuffer;
          }
        }
        console.log('[SongLab] Pitch reset — using original buffers');
        return;
      }

      const pitchRate = Math.pow(2, this.songLabPitchShift / 12);

      for (const track of this.songLabTracks) {
        if (!track.buffer) continue;

        // Save original buffer if not saved yet
        if (!track._originalBuffer) {
          track._originalBuffer = track.buffer;
        }

        const original = track._originalBuffer;
        const sampleRate = original.sampleRate;
        const channels = original.numberOfChannels;

        // Render at different playbackRate to shift pitch
        // Then resample back to original length to preserve duration
        const stretchedLength = Math.round(original.length / pitchRate);
        const offlineCtx = new OfflineAudioContext(channels, stretchedLength, sampleRate);
        const source = offlineCtx.createBufferSource();
        source.buffer = original;
        source.playbackRate.value = pitchRate;
        source.connect(offlineCtx.destination);
        source.start(0);

        try {
          const rendered = await offlineCtx.startRendering();

          // Resample back to original length to maintain duration
          const finalBuffer = this.ctx.createBuffer(channels, original.length, sampleRate);
          for (let ch = 0; ch < channels; ch++) {
            const src = rendered.getChannelData(ch);
            const dst = finalBuffer.getChannelData(ch);
            const ratio = src.length / dst.length;
            for (let i = 0; i < dst.length; i++) {
              const srcIdx = i * ratio;
              const lo = Math.floor(srcIdx);
              const hi = Math.min(lo + 1, src.length - 1);
              const frac = srcIdx - lo;
              dst[i] = src[lo] * (1 - frac) + src[hi] * frac;
            }
          }

          track.buffer = finalBuffer;
        } catch (e) {
          console.warn('[SongLab] Pitch rebuild failed for track:', e);
        }
      }

      console.log('[SongLab] Pitch-shifted buffers rebuilt at', this.songLabPitchShift, 'semitones');
    }

    songLabSetLoopRegion(startTime, endTime) {
      this.songLabLoopA = Math.max(0, startTime);
      this.songLabLoopB = Math.min(this.songLabDuration, endTime);
      console.log('[SongLab] Loop region:', this.songLabLoopA.toFixed(2), '-', this.songLabLoopB.toFixed(2));
    }

    songLabClearLoopRegion() {
      this.songLabLoopA = -1;
      this.songLabLoopB = -1;
    }

    songLabGetPosition() {
      if (!this.songLabPlaying) return this.songLabPauseOffset;
      const combinedRate = this.songLabSpeed;
      const elapsed = (this.ctx.currentTime - this.songLabStartTime) * combinedRate;
      return elapsed % this.songLabDuration;
    }

    songLabGetState() {
      return {
        trackCount: this.songLabTracks.length,
        duration: this.songLabDuration,
        isPlaying: this.songLabPlaying,
        position: this.songLabGetPosition(),
        speed: this.songLabSpeed,
        pitchShift: this.songLabPitchShift,
        loopA: this.songLabLoopA,
        loopB: this.songLabLoopB,
        tracks: this.songLabTracks.map((t, i) => ({
          name: t.name,
          type: t.type,
          volume: t._prevGain,
          pan: t.panNode ? t.panNode.pan.value : 0,
          muted: t.muted,
          solo: t.solo,
        })),
      };
    }

    songLabGetWaveform(trackIndex, numSamples) {
      if (trackIndex < 0 || trackIndex >= this.songLabTracks.length) return [];
      const buffer = this.songLabTracks[trackIndex].buffer;
      if (!buffer || numSamples <= 0) return [];

      const channelData = buffer.getChannelData(0);
      const totalSamples = channelData.length;
      const samplesPerChunk = totalSamples / numSamples;
      const peaks = new Array(numSamples);

      for (let i = 0; i < numSamples; i++) {
        const start = Math.floor(i * samplesPerChunk);
        const end = Math.min(Math.floor((i + 1) * samplesPerChunk), totalSamples);
        let max = 0;
        for (let j = start; j < end; j++) {
          const abs = Math.abs(channelData[j]);
          if (abs > max) max = abs;
        }
        peaks[i] = max;
      }
      return peaks;
    }

    songLabClearAll() {
      this.songLabStop();
      for (const track of this.songLabTracks) {
        if (track.panNode) track.panNode.disconnect();
        if (track.gainNode) track.gainNode.disconnect();
      }
      this.songLabTracks = [];
      this.songLabDuration = 0;
      this.songLabPauseOffset = 0;
      this.songLabSpeed = 1.0;
      this.songLabPitchShift = 0;
      this.songLabLoopA = -1;
      this.songLabLoopB = -1;
      this._songLabSoloActive = false;
      console.log('[SongLab] All tracks cleared');
    }

    // ── Stem Separation — tries API first, falls back to mock filters ──
    // Configure your Hugging Face Space URL here:
    // Example: 'https://YOUR-USERNAME-groovelab-stems.hf.space'
    static STEM_API_URL = 'https://groovelab-stems-stem-separator.hf.space';

    async songLabMockSeparate(trackIndexOrBuffer) {
      let sourceBuffer;
      if (typeof trackIndexOrBuffer === 'number') {
        if (trackIndexOrBuffer < 0 || trackIndexOrBuffer >= this.songLabTracks.length) return null;
        sourceBuffer = this.songLabTracks[trackIndexOrBuffer].buffer;
      } else {
        sourceBuffer = trackIndexOrBuffer;
      }
      if (!sourceBuffer) return null;

      // Try real API separation first
      if (GrooveLabWebAudio.STEM_API_URL) {
        try {
          console.log('[SongLab] Attempting real stem separation via API...');
          const result = await this._songLabSeparateViaAPI(sourceBuffer);
          if (result && result.success) return result;
          console.warn('[SongLab] API separation failed, falling back to mock');
        } catch (e) {
          console.warn('[SongLab] API unavailable:', e.message, '— using mock');
        }
      }

      // Fallback: mock separation with bandpass filters
      return await this._songLabMockSeparateLocal(sourceBuffer);
    }

    async _songLabSeparateViaAPI(sourceBuffer) {
      // Convert AudioBuffer to WAV blob
      const wavBlob = this._audioBufferToWavBlob(sourceBuffer);

      const formData = new FormData();
      formData.append('files', wavBlob, 'audio.wav');

      // Call Gradio API
      const apiUrl = GrooveLabWebAudio.STEM_API_URL.replace(/\/$/, '');
      console.log('[SongLab] Uploading to', apiUrl);

      // Step 1: Upload file
      const uploadResp = await fetch(`${apiUrl}/upload`, {
        method: 'POST',
        body: formData,
      });
      if (!uploadResp.ok) throw new Error('Upload failed: ' + uploadResp.status);
      const uploadResult = await uploadResp.json();
      const filePath = uploadResult[0]; // Gradio returns array of paths

      // Step 2: Call predict endpoint
      const predictResp = await fetch(`${apiUrl}/api/predict`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: [filePath] }),
      });
      if (!predictResp.ok) throw new Error('Predict failed: ' + predictResp.status);
      const predictResult = await predictResp.json();

      // Parse the JSON string response from Gradio
      const resultData = JSON.parse(predictResult.data[0]);
      if (!resultData.success) throw new Error(resultData.error || 'Separation failed');

      // Decode base64 WAV stems into AudioBuffers
      const stemNames = resultData.stemNames || Object.keys(resultData.stems);
      const stemTypeMap = {
        'vocals': 'vocals', 'drums': 'drums', 'bass': 'bass',
        'guitar': 'guitar', 'piano': 'piano', 'keys': 'piano',
        'other': 'other',
      };
      const stemDisplayNames = {
        'vocals': 'Vocals', 'drums': 'Drums', 'bass': 'Bass',
        'guitar': 'Guitar', 'piano': 'Keys', 'other': 'Other',
      };

      const stemIndices = [];
      for (const stemName of stemNames) {
        const b64 = resultData.stems[stemName];
        if (!b64) continue;

        // Decode base64 to ArrayBuffer
        const binary = atob(b64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
          bytes[i] = binary.charCodeAt(i);
        }

        const audioBuffer = await this.ctx.decodeAudioData(bytes.buffer.slice(0));

        const gainNode = this.ctx.createGain();
        gainNode.gain.value = 1.0;
        const panNode = this.ctx.createStereoPanner();
        panNode.pan.value = 0;
        gainNode.connect(panNode);
        panNode.connect(this.songLabMasterGain);

        const trackIdx = this.songLabTracks.length;
        this.songLabTracks.push({
          buffer: audioBuffer,
          name: stemDisplayNames[stemName] || stemName,
          type: stemTypeMap[stemName] || 'other',
          gainNode, panNode,
          muted: false, solo: false, _prevGain: 1.0,
        });
        stemIndices.push(trackIdx);
        console.log('[SongLab] Real stem loaded:', stemName, audioBuffer.duration.toFixed(1) + 's');
      }

      // Mute original track
      this._songLabMuteOriginal(stemIndices);

      console.log('[SongLab] Real separation complete:', stemIndices.length, 'stems');
      return { success: true, stemCount: stemIndices.length, stemIndices };
    }

    _audioBufferToWavBlob(audioBuffer) {
      const numChannels = audioBuffer.numberOfChannels;
      const sampleRate = audioBuffer.sampleRate;
      const length = audioBuffer.length;
      const bytesPerSample = 2; // 16-bit
      const dataSize = length * numChannels * bytesPerSample;
      const buffer = new ArrayBuffer(44 + dataSize);
      const view = new DataView(buffer);

      // WAV header
      const writeString = (offset, str) => { for (let i = 0; i < str.length; i++) view.setUint8(offset + i, str.charCodeAt(i)); };
      writeString(0, 'RIFF');
      view.setUint32(4, 36 + dataSize, true);
      writeString(8, 'WAVE');
      writeString(12, 'fmt ');
      view.setUint32(16, 16, true);
      view.setUint16(20, 1, true); // PCM
      view.setUint16(22, numChannels, true);
      view.setUint32(24, sampleRate, true);
      view.setUint32(28, sampleRate * numChannels * bytesPerSample, true);
      view.setUint16(32, numChannels * bytesPerSample, true);
      view.setUint16(34, 16, true);
      writeString(36, 'data');
      view.setUint32(40, dataSize, true);

      // Interleave channels
      const channels = [];
      for (let c = 0; c < numChannels; c++) channels.push(audioBuffer.getChannelData(c));
      let offset = 44;
      for (let i = 0; i < length; i++) {
        for (let c = 0; c < numChannels; c++) {
          const sample = Math.max(-1, Math.min(1, channels[c][i]));
          view.setInt16(offset, sample * 0x7FFF, true);
          offset += 2;
        }
      }

      return new Blob([buffer], { type: 'audio/wav' });
    }

    _songLabMuteOriginal(stemIndices) {
      if (this.songLabTracks.length > 0 && stemIndices.length > 0) {
        const originalTrack = this.songLabTracks[0];
        if (originalTrack && originalTrack.gainNode) {
          originalTrack.muted = true;
          originalTrack.gainNode.gain.value = 0;
          console.log('[SongLab] Original full mix (track 0) muted — stems only');
        }
      }
    }

    async _songLabMockSeparateLocal(sourceBuffer) {
      const sampleRate = sourceBuffer.sampleRate;
      const length = sourceBuffer.length;
      const numChannels = sourceBuffer.numberOfChannels;
      const results = [];

      const stemConfigs = [
        { name: 'Vocals', type: 'vocals', filters: [{ type: 'bandpass', frequency: 1200, Q: 0.7 }]},
        { name: 'Drums', type: 'drums', multiband: [
          [{ type: 'lowpass', frequency: 100, Q: 0.7 }],
          [{ type: 'highpass', frequency: 8000, Q: 0.7 }],
        ]},
        { name: 'Bass', type: 'bass', filters: [{ type: 'lowpass', frequency: 250, Q: 0.7 }]},
        { name: 'Guitar', type: 'guitar', filters: [{ type: 'bandpass', frequency: 800, Q: 0.5 }]},
        { name: 'Keys', type: 'piano', filters: [{ type: 'bandpass', frequency: 3000, Q: 0.5 }]},
        { name: 'Other', type: 'other', filters: [{ type: 'highpass', frequency: 6000, Q: 0.7 }]},
      ];

      for (const config of stemConfigs) {
        let rendered;
        if (config.multiband) {
          const bandBuffers = [];
          for (const band of config.multiband) {
            const offlineCtx = new OfflineAudioContext(numChannels, length, sampleRate);
            const source = offlineCtx.createBufferSource();
            source.buffer = sourceBuffer;
            let lastNode = source;
            for (const f of band) {
              const bq = offlineCtx.createBiquadFilter();
              bq.type = f.type; bq.frequency.value = f.frequency; bq.Q.value = f.Q;
              lastNode.connect(bq); lastNode = bq;
            }
            lastNode.connect(offlineCtx.destination);
            source.start(0);
            bandBuffers.push(await offlineCtx.startRendering());
          }
          const sumCtx = new OfflineAudioContext(numChannels, length, sampleRate);
          for (const buf of bandBuffers) {
            const src = sumCtx.createBufferSource(); src.buffer = buf;
            src.connect(sumCtx.destination); src.start(0);
          }
          rendered = await sumCtx.startRendering();
        } else {
          const offlineCtx = new OfflineAudioContext(numChannels, length, sampleRate);
          const source = offlineCtx.createBufferSource();
          source.buffer = sourceBuffer;
          let lastNode = source;
          for (const f of config.filters) {
            const bq = offlineCtx.createBiquadFilter();
            bq.type = f.type; bq.frequency.value = f.frequency; bq.Q.value = f.Q;
            lastNode.connect(bq); lastNode = bq;
          }
          lastNode.connect(offlineCtx.destination);
          source.start(0);
          rendered = await offlineCtx.startRendering();
        }
        results.push({ name: config.name, type: config.type, buffer: rendered });
        console.log('[SongLab] Mock stem generated:', config.name);
      }

      const stemIndices = [];
      for (const stemResult of results) {
        const gainNode = this.ctx.createGain();
        gainNode.gain.value = 1.0;
        const panNode = this.ctx.createStereoPanner();
        panNode.pan.value = 0;
        gainNode.connect(panNode);
        panNode.connect(this.songLabMasterGain);
        const trackIdx = this.songLabTracks.length;
        this.songLabTracks.push({
          buffer: stemResult.buffer, name: stemResult.name, type: stemResult.type,
          gainNode, panNode, muted: false, solo: false, _prevGain: 1.0,
        });
        stemIndices.push(trackIdx);
      }

      this._songLabMuteOriginal(stemIndices);
      console.log('[SongLab] Mock separation complete:', results.length, 'stems');
      return { success: true, stemCount: results.length, stemIndices };
    }

    async songLabExportMixdown(format) {
      if (this.songLabTracks.length === 0) return null;

      const combinedRate = this.songLabSpeed * Math.pow(2, this.songLabPitchShift / 12);
      const sampleRate = this.ctx.sampleRate;
      const duration = this.songLabDuration / combinedRate;
      const length = Math.ceil(duration * sampleRate);
      const offlineCtx = new OfflineAudioContext(2, length, sampleRate);

      const master = offlineCtx.createGain();
      master.gain.value = 1.0;
      master.connect(offlineCtx.destination);

      for (const track of this.songLabTracks) {
        if (this._songLabSoloActive && !track.solo) continue;
        if (!this._songLabSoloActive && track.muted) continue;

        const source = offlineCtx.createBufferSource();
        source.buffer = track.buffer;
        source.playbackRate.value = combinedRate;
        const gain = offlineCtx.createGain();
        gain.gain.value = track._prevGain;
        const pan = offlineCtx.createStereoPanner();
        pan.pan.value = track.panNode ? track.panNode.pan.value : 0;

        source.connect(gain);
        gain.connect(pan);
        pan.connect(master);
        source.start(0);
      }

      const rendered = await offlineCtx.startRendering();
      const wavBlob = this._encodeWav(rendered);

      if (this._lastExportUrl) URL.revokeObjectURL(this._lastExportUrl);
      this._lastExportUrl = URL.createObjectURL(wavBlob);
      console.log('[SongLab] Export complete, size:', wavBlob.size);
      return this._lastExportUrl;
    }

    async songLabExportStems() {
      const stems = [];
      for (let i = 0; i < this.songLabTracks.length; i++) {
        const track = this.songLabTracks[i];
        if (track.muted) continue;

        const combinedRate = this.songLabSpeed * Math.pow(2, this.songLabPitchShift / 12);
        const sampleRate = this.ctx.sampleRate;
        const duration = this.songLabDuration / combinedRate;
        const length = Math.ceil(duration * sampleRate);
        const offlineCtx = new OfflineAudioContext(2, length, sampleRate);

        const source = offlineCtx.createBufferSource();
        source.buffer = track.buffer;
        source.playbackRate.value = combinedRate;
        const gain = offlineCtx.createGain();
        gain.gain.value = track._prevGain;
        const pan = offlineCtx.createStereoPanner();
        pan.pan.value = track.panNode ? track.panNode.pan.value : 0;

        source.connect(gain);
        gain.connect(pan);
        pan.connect(offlineCtx.destination);
        source.start(0);

        const rendered = await offlineCtx.startRendering();
        const wavBlob = this._encodeWav(rendered);
        stems.push({
          index: i,
          name: track.name,
          type: track.type,
          url: URL.createObjectURL(wavBlob),
          size: wavBlob.size,
        });
      }
      return stems;
    }

    // Private helpers

    _songLabScheduleSources(offsetSeconds) {
      // Stop any existing sources first
      for (const source of this.songLabSources) {
        try { source._stopped = true; source.stop(0); } catch (_) {}
      }
      this.songLabSources = [];

      const combinedRate = this.songLabSpeed;

      // Schedule all stems to start at exactly the same future time for perfect sync
      const startTime = this.ctx.currentTime + 0.05;

      for (let i = 0; i < this.songLabTracks.length; i++) {
        const track = this.songLabTracks[i];
        if (!track.buffer) continue;

        const source = this.ctx.createBufferSource();
        source.buffer = track.buffer;
        source.playbackRate.value = combinedRate;
        source.connect(track.gainNode);
        source._stopped = false;

        // Apply mute/solo state
        if (this._songLabSoloActive) {
          track.gainNode.gain.value = track.solo ? track._prevGain : 0;
        } else {
          track.gainNode.gain.value = track.muted ? 0 : track._prevGain;
        }

        source.start(startTime, offsetSeconds);
        source.onended = () => { source._stopped = true; };
        this.songLabSources.push(source);
      }

      // Adjust startTime to account for the scheduling delay
      this.songLabStartTime = startTime - (offsetSeconds / combinedRate);
    }

    _songLabStopSources() {
      for (const source of this.songLabSources) {
        try {
          source._stopped = true;
          source.stop();
        } catch (_) {}
      }
      this.songLabSources = [];
    }

    _songLabStartPositionTimer() {
      this._songLabStopPositionTimer();
      const tick = () => {
        if (!this.songLabPlaying) return;

        const combinedRate = this.songLabSpeed;
        const elapsed = (this.ctx.currentTime - this.songLabStartTime) * combinedRate;
        let position = elapsed % this.songLabDuration;

        // A-B loop check
        if (this.songLabLoopA >= 0 && this.songLabLoopB > this.songLabLoopA) {
          if (position >= this.songLabLoopB) {
            this.songLabSeek(this.songLabLoopA);
            position = this.songLabLoopA;
          }
        }

        // End of track
        if (elapsed >= this.songLabDuration && this.songLabLoopA < 0) {
          this.songLabStop();
          return;
        }

        if (this.onSongLabPositionCallback) {
          this.onSongLabPositionCallback(position);
        }

        this._songLabPositionTimer = requestAnimationFrame(tick);
      };
      this._songLabPositionTimer = requestAnimationFrame(tick);
    }

    _songLabStopPositionTimer() {
      if (this._songLabPositionTimer != null) {
        cancelAnimationFrame(this._songLabPositionTimer);
        this._songLabPositionTimer = null;
      }
    }

    // ── Pitch Detection (YIN Autocorrelation) ──

    songLabDetectPitch(trackIndex) {
      if (!this.songLabTracks || this.songLabTracks.length === 0) return [];

      const idx = (typeof trackIndex === 'number' && trackIndex >= 0 && trackIndex < this.songLabTracks.length)
        ? trackIndex : 0;
      const track = this.songLabTracks[idx];
      if (!track || !track.buffer) return [];

      const buffer = track.buffer;
      const sampleRate = buffer.sampleRate;
      const channelData = buffer.getChannelData(0);
      console.log('[SongLab] Analyzing track', idx, '(' + (track.name || 'unknown') + '), samples:', channelData.length);

      const frameSize = 8192;
      const hopSize = Math.round(sampleRate * 0.25); // every 250ms
      const notes = [];
      const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

      const chordTemplates = {
        'maj':  [1,0,0,0,1,0,0,1,0,0,0,0],
        'm':    [1,0,0,1,0,0,0,1,0,0,0,0],
        '7':    [1,0,0,0,1,0,0,1,0,0,1,0],
        'maj7': [1,0,0,0,1,0,0,1,0,0,0,1],
        'm7':   [1,0,0,1,0,0,0,1,0,0,1,0],
        'dim':  [1,0,0,1,0,0,1,0,0,0,0,0],
        'aug':  [1,0,0,0,1,0,0,0,1,0,0,0],
        'sus4': [1,0,0,0,0,1,0,1,0,0,0,0],
        'sus2': [1,0,1,0,0,0,0,1,0,0,0,0],
      };

      for (let i = 0; i + frameSize < channelData.length; i += hopSize) {
        const frame = channelData.slice(i, i + frameSize);
        const time = i / sampleRate;

        // 1. Detect fundamental pitch via YIN
        const freq = this._detectPitchYIN(frame, sampleRate);
        let noteName = '';
        let octave = 4;
        let midi = 0;

        if (freq > 0 && freq >= 60 && freq <= 2000) {
          const noteNum = 12 * (Math.log2(freq / 440)) + 69;
          const noteIndex = Math.round(noteNum) % 12;
          octave = Math.floor(Math.round(noteNum) / 12) - 1;
          noteName = noteNames[noteIndex < 0 ? noteIndex + 12 : noteIndex];
          midi = Math.round(noteNum);
        }

        // 2. Detect chord via chroma vector (FFT-based)
        const chord = this._detectChordFromFrame(frame, sampleRate, frameSize, noteNames, chordTemplates);

        if (noteName || chord) {
          notes.push({
            time: time,
            endTime: time + (hopSize / sampleRate),
            frequency: freq > 0 ? Math.round(freq * 10) / 10 : 0,
            note: noteName || '',
            octave: octave,
            midi: midi,
            chord: chord || '',
            confidence: 0.8
          });
        }
      }

      console.log('[SongLab] Detected', notes.length, 'note/chord events');
      return notes;
    }

    _detectChordFromFrame(frame, sampleRate, fftSize, noteNames, chordTemplates) {
      // Compute FFT magnitude spectrum using a simple DFT on the frame
      // For performance, we use a reduced resolution approach
      const N = Math.min(frame.length, fftSize);
      const chroma = new Array(12).fill(0);

      // Apply Hann window
      const windowed = new Float32Array(N);
      for (let i = 0; i < N; i++) {
        windowed[i] = frame[i] * (0.5 - 0.5 * Math.cos(2 * Math.PI * i / N));
      }

      // Compute power spectrum for musically relevant frequency bins
      // Only compute bins for frequencies 60Hz - 4200Hz
      const minBin = Math.ceil(60 * N / sampleRate);
      const maxBin = Math.floor(4200 * N / sampleRate);

      for (let bin = minBin; bin <= maxBin; bin++) {
        // Goertzel algorithm for specific bins (much faster than full FFT)
        const freq = bin * sampleRate / N;
        const k = bin;
        const w = 2 * Math.PI * k / N;
        const coeff = 2 * Math.cos(w);
        let s0 = 0, s1 = 0, s2 = 0;

        for (let i = 0; i < N; i++) {
          s0 = windowed[i] + coeff * s1 - s2;
          s2 = s1;
          s1 = s0;
        }

        const power = s1 * s1 + s2 * s2 - coeff * s1 * s2;
        if (power > 0) {
          const midi = 12 * Math.log2(freq / 440) + 69;
          const pitchClass = Math.round(midi) % 12;
          if (pitchClass >= 0 && pitchClass < 12) {
            chroma[pitchClass] += Math.sqrt(Math.abs(power));
          }
        }
      }

      // Normalize chroma
      const maxChroma = Math.max(...chroma);
      if (maxChroma < 0.001) return ''; // silence
      const normalized = chroma.map(v => v / maxChroma);

      // Match against chord templates
      let bestScore = -1;
      let bestChord = '';

      for (let rootIdx = 0; rootIdx < 12; rootIdx++) {
        for (const [quality, template] of Object.entries(chordTemplates)) {
          let score = 0;
          for (let j = 0; j < 12; j++) {
            const chromaIdx = (j + rootIdx) % 12;
            score += template[j] * normalized[chromaIdx];
          }
          if (score > bestScore) {
            bestScore = score;
            bestChord = quality === 'maj' ? noteNames[rootIdx] : noteNames[rootIdx] + quality;
          }
        }
      }

      // Only return chord if confidence is reasonable
      return bestScore > 2.0 ? bestChord : '';
    }

    _detectPitchYIN(buffer, sampleRate) {
      const threshold = 0.15;
      const bufferSize = buffer.length;
      const halfSize = Math.floor(bufferSize / 2);

      // Step 1: Compute difference function
      const diff = new Float32Array(halfSize);
      for (let tau = 0; tau < halfSize; tau++) {
        let sum = 0;
        for (let i = 0; i < halfSize; i++) {
          const delta = buffer[i] - buffer[i + tau];
          sum += delta * delta;
        }
        diff[tau] = sum;
      }

      // Step 2: Cumulative mean normalized difference
      const cmndf = new Float32Array(halfSize);
      cmndf[0] = 1;
      let runningSum = 0;
      for (let tau = 1; tau < halfSize; tau++) {
        runningSum += diff[tau];
        cmndf[tau] = diff[tau] * tau / runningSum;
      }

      // Step 3: Find the first dip below threshold
      let tau = 2;
      while (tau < halfSize && cmndf[tau] > threshold) {
        tau++;
      }

      // Step 4: Find the minimum in the dip
      if (tau >= halfSize) return -1;

      let minTau = tau;
      let minVal = cmndf[tau];
      while (tau < halfSize && cmndf[tau] < threshold + 0.1) {
        if (cmndf[tau] < minVal) {
          minVal = cmndf[tau];
          minTau = tau;
        }
        tau++;
      }

      // Parabolic interpolation
      if (minTau > 0 && minTau < halfSize - 1) {
        const s0 = cmndf[minTau - 1];
        const s1 = cmndf[minTau];
        const s2 = cmndf[minTau + 1];
        const betterTau = minTau + (s0 - s2) / (2 * (s0 - 2 * s1 + s2));
        return sampleRate / betterTau;
      }

      return sampleRate / minTau;
    }

    // ── Click Track Playback ──

    songLabToggleClick(enabled, bpm) {
      // Stop existing click
      if (this._songLabClickInterval) {
        clearInterval(this._songLabClickInterval);
        this._songLabClickInterval = null;
      }

      this._songLabClickEnabled = enabled;
      this._songLabClickBpm = bpm || 120;

      if (!enabled || !this.songLabPlaying) return;

      this._startSongLabClick();
    }

    _startSongLabClick() {
      if (!this._songLabClickEnabled || !this.songLabPlaying) return;

      const interval = 60000 / this._songLabClickBpm; // ms per beat

      this._songLabClickInterval = setInterval(() => {
        if (!this.songLabPlaying) {
          clearInterval(this._songLabClickInterval);
          this._songLabClickInterval = null;
          return;
        }
        this._playClickSound();
      }, interval);

      // Play first click immediately
      this._playClickSound();
    }

    _playClickSound() {
      try {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.frequency.value = 1000; // 1kHz click
        osc.type = 'sine';
        gain.gain.setValueAtTime(0.3, this.ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.05);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(this.ctx.currentTime);
        osc.stop(this.ctx.currentTime + 0.05);
      } catch(e) {
        // ignore click errors
      }
    }

    // ═══════════════════════════════════════════════════════════════
    //  PEDALERA — Real-time Guitar Effects Signal Chain
    // ═══════════════════════════════════════════════════════════════

    async initPedalera() {
      if (!this.ctx) await this.init();
      if (this.pedalInput) return; // already initialized

      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false, latencyHint: 'interactive' }
        });
        this.pedalInputStream = stream;
        this.pedalInput = this.ctx.createMediaStreamSource(stream);
        this.pedalOutputGain = this.ctx.createGain();
        this.pedalOutputGain.gain.value = 1.0;
        this.pedalOutputGain.connect(this.ctx.destination);
        this.pedalChainNodes = [];
        this.pedalActive = false;
        console.log('Pedalera: initialized');
      } catch (e) {
        console.error('Pedalera: mic access failed', e);
      }
    }

    async setPedalChain(chainConfig) {
      if (!this.ctx || !this.pedalInput) return;

      // Disconnect existing chain
      this._disconnectPedalChain();

      const nodes = [];
      for (const pedal of chainConfig) {
        if (!pedal.enabled) continue;
        const node = this._createPedalNode(pedal.type, pedal.params);
        if (node) nodes.push({ type: pedal.type, node: node, enabled: true });
      }

      this.pedalChainNodes = nodes;
      this._reconnectPedalChain();
    }

    _createPedalNode(type, params) {
      switch (type) {
        case 'noiseGate':
          // Noise gate: use DynamicsCompressor with extreme settings
          const gate = this.ctx.createDynamicsCompressor();
          gate.threshold.value = params.threshold || -40;
          gate.ratio.value = 20;
          gate.attack.value = 0.001;
          gate.release.value = (params.release || 50) / 1000;
          return gate;

        case 'compressor':
          const comp = this.ctx.createDynamicsCompressor();
          comp.threshold.value = params.threshold || -24;
          comp.ratio.value = params.ratio || 4;
          comp.attack.value = (params.attack || 3) / 1000;
          comp.release.value = (params.release || 250) / 1000;
          return comp;

        case 'drive':
          const ws = this.ctx.createWaveShaper();
          ws.curve = this._makeDriveCurve(params.gain || 50);
          ws.oversample = '4x';
          // Wrap with tone control: drive → filter → gain
          const driveGain = this.ctx.createGain();
          driveGain.gain.value = (params.level || 70) / 100;
          const toneFilter = this.ctx.createBiquadFilter();
          toneFilter.type = 'lowpass';
          toneFilter.frequency.value = 800 + (params.tone || 50) * 80; // 800-8800 Hz
          toneFilter.Q.value = 0.7;
          ws.connect(toneFilter);
          toneFilter.connect(driveGain);
          // Return first node; chain continues from driveGain
          ws._chainEnd = driveGain;
          return ws;

        case 'eq':
          // 5-band parametric EQ
          const bands = [
            { type: 'lowshelf',  freq: 100,   gain: params.low || 0 },
            { type: 'peaking',   freq: 300,   gain: params.lowMid || 0, Q: 1 },
            { type: 'peaking',   freq: 1000,  gain: params.mid || 0, Q: 1 },
            { type: 'peaking',   freq: 3500,  gain: params.hiMid || 0, Q: 1 },
            { type: 'highshelf', freq: 10000, gain: params.high || 0 },
          ];
          let firstEq = null;
          let prevEq = null;
          for (const b of bands) {
            const eq = this.ctx.createBiquadFilter();
            eq.type = b.type;
            eq.frequency.value = b.freq;
            eq.gain.value = b.gain;
            if (b.Q) eq.Q.value = b.Q;
            if (!firstEq) firstEq = eq;
            if (prevEq) prevEq.connect(eq);
            prevEq = eq;
          }
          if (firstEq) firstEq._chainEnd = prevEq;
          return firstEq;

        case 'chorus':
          // Chorus: short modulated delay mixed with dry signal
          const chorusDry = this.ctx.createGain();
          const chorusWet = this.ctx.createGain();
          const chorusDelay = this.ctx.createDelay(0.05);
          const chorusLFO = this.ctx.createOscillator();
          const chorusLFOGain = this.ctx.createGain();
          const mix = (params.mix || 40) / 100;
          chorusDry.gain.value = 1.0 - mix * 0.5;
          chorusWet.gain.value = mix;
          chorusDelay.delayTime.value = 0.015;
          chorusLFO.frequency.value = (params.rate || 40) / 100 * 3; // 0-3 Hz
          chorusLFO.type = 'sine';
          chorusLFOGain.gain.value = (params.depth || 50) / 100 * 0.005;
          chorusLFO.connect(chorusLFOGain);
          chorusLFOGain.connect(chorusDelay.delayTime);
          chorusLFO.start();
          // Merger for dry+wet
          const chorusMerge = this.ctx.createGain();
          chorusDry.connect(chorusMerge);
          chorusDelay.connect(chorusWet);
          chorusWet.connect(chorusMerge);
          // Input splits to dry + delay
          const chorusSplit = this.ctx.createGain();
          chorusSplit.connect(chorusDry);
          chorusSplit.connect(chorusDelay);
          chorusSplit._chainEnd = chorusMerge;
          chorusSplit._lfo = chorusLFO;
          return chorusSplit;

        case 'delay':
          const delayNode = this.ctx.createDelay(5.0);
          delayNode.delayTime.value = (params.time || 400) / 1000;
          const feedbackGain = this.ctx.createGain();
          feedbackGain.gain.value = (params.feedback || 35) / 100;
          const delayWet = this.ctx.createGain();
          delayWet.gain.value = (params.mix || 30) / 100;
          const delayDry = this.ctx.createGain();
          delayDry.gain.value = 1.0;
          const delayMerge = this.ctx.createGain();
          // Feedback loop
          delayNode.connect(feedbackGain);
          feedbackGain.connect(delayNode);
          delayNode.connect(delayWet);
          delayWet.connect(delayMerge);
          // Dry path
          const delaySplit = this.ctx.createGain();
          delaySplit.connect(delayDry);
          delaySplit.connect(delayNode);
          delayDry.connect(delayMerge);
          delaySplit._chainEnd = delayMerge;
          return delaySplit;

        case 'reverb':
          // Algorithmic reverb using IIR approximation
          const reverbConv = this.ctx.createConvolver();
          const decay = (params.decay || 50) / 100;
          const reverbLen = 1.0 + decay * 3.0; // 1-4 seconds
          reverbConv.buffer = this._generateReverbIR(reverbLen, decay);
          const revWet = this.ctx.createGain();
          revWet.gain.value = (params.mix || 30) / 100;
          const revDry = this.ctx.createGain();
          revDry.gain.value = 1.0;
          const revMerge = this.ctx.createGain();
          const revSplit = this.ctx.createGain();
          revSplit.connect(revDry);
          revSplit.connect(reverbConv);
          reverbConv.connect(revWet);
          revWet.connect(revMerge);
          revDry.connect(revMerge);
          revSplit._chainEnd = revMerge;
          return revSplit;

        case 'amp':
          // Amp sim: waveshaper + tone stack (bass/mid/treble)
          const ampWs = this.ctx.createWaveShaper();
          ampWs.curve = this._makeDriveCurve(params.gain || 50);
          ampWs.oversample = '4x';
          const bass = this.ctx.createBiquadFilter();
          bass.type = 'lowshelf'; bass.frequency.value = 200; bass.gain.value = ((params.bass || 50) - 50) / 5;
          const mid = this.ctx.createBiquadFilter();
          mid.type = 'peaking'; mid.frequency.value = 1000; mid.Q.value = 0.8; mid.gain.value = ((params.mid || 50) - 50) / 5;
          const treble = this.ctx.createBiquadFilter();
          treble.type = 'highshelf'; treble.frequency.value = 3500; treble.gain.value = ((params.treble || 50) - 50) / 5;
          const ampVol = this.ctx.createGain();
          ampVol.gain.value = (params.volume || 70) / 100;
          ampWs.connect(bass); bass.connect(mid); mid.connect(treble); treble.connect(ampVol);
          ampWs._chainEnd = ampVol;
          return ampWs;

        case 'cabinet':
          // Cabinet IR (use generated short IR as placeholder)
          const cabConv = this.ctx.createConvolver();
          cabConv.buffer = this._generateCabinetIR();
          const cabMix = this.ctx.createGain();
          cabMix.gain.value = (params.mix || 100) / 100;
          cabConv.connect(cabMix);
          cabConv._chainEnd = cabMix;
          return cabConv;

        default:
          return null;
      }
    }

    _makeDriveCurve(amount) {
      const samples = 256;
      const curve = new Float32Array(samples);
      const k = amount / 100 * 50 + 1;
      for (let i = 0; i < samples; i++) {
        const x = (i * 2) / samples - 1;
        curve[i] = (Math.PI + k) * x / (Math.PI + k * Math.abs(x));
      }
      return curve;
    }

    _generateReverbIR(length, decay) {
      const sr = this.ctx.sampleRate;
      const samples = Math.floor(sr * length);
      const buffer = this.ctx.createBuffer(2, samples, sr);
      for (let ch = 0; ch < 2; ch++) {
        const data = buffer.getChannelData(ch);
        for (let i = 0; i < samples; i++) {
          data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / samples, 2 + decay * 3);
        }
      }
      return buffer;
    }

    _generateCabinetIR() {
      // Short cabinet impulse response (~50ms)
      const sr = this.ctx.sampleRate;
      const samples = Math.floor(sr * 0.05);
      const buffer = this.ctx.createBuffer(1, samples, sr);
      const data = buffer.getChannelData(0);
      // Simple low-pass characteristic
      for (let i = 0; i < samples; i++) {
        const t = i / sr;
        data[i] = Math.exp(-t * 80) * Math.sin(2 * Math.PI * 800 * t) * 0.5
                + Math.exp(-t * 120) * (Math.random() * 0.3 - 0.15);
      }
      return buffer;
    }

    _reconnectPedalChain() {
      if (!this.pedalInput || !this.pedalOutputGain) return;
      let current = this.pedalInput;
      for (const item of (this.pedalChainNodes || [])) {
        if (!item.enabled || !item.node) continue;
        current.connect(item.node);
        // Use _chainEnd if the node has internal routing (e.g., drive→tone→gain)
        current = item.node._chainEnd || item.node;
      }
      current.connect(this.pedalOutputGain);
      this.pedalActive = true;
    }

    _disconnectPedalChain() {
      try { this.pedalInput?.disconnect(); } catch(e) {}
      for (const item of (this.pedalChainNodes || [])) {
        try { item.node?.disconnect(); } catch(e) {}
        try { item.node?._chainEnd?.disconnect(); } catch(e) {}
        if (item.node?._lfo) { try { item.node._lfo.stop(); } catch(e) {} }
      }
      try { this.pedalOutputGain?.disconnect(); this.pedalOutputGain?.connect(this.ctx.destination); } catch(e) {}
      this.pedalActive = false;
    }

    setPedalParam(pedalIndex, paramName, value) {
      // For real-time parameter updates, rebuild the specific node
      // This is a simplified approach; a production version would use AudioParam automation
      const chain = this.pedalChainNodes || [];
      if (pedalIndex < 0 || pedalIndex >= chain.length) return;
      // Trigger full chain rebuild on next setPedalChain call
    }

    setPedalBypass(pedalIndex, bypassed) {
      const chain = this.pedalChainNodes || [];
      if (pedalIndex >= 0 && pedalIndex < chain.length) {
        chain[pedalIndex].enabled = !bypassed;
        this._disconnectPedalChain();
        this._reconnectPedalChain();
      }
    }

    stopPedalera() {
      this._disconnectPedalChain();
      if (this.pedalInputStream) {
        this.pedalInputStream.getTracks().forEach(t => t.stop());
        this.pedalInputStream = null;
      }
      this.pedalInput = null;
      this.pedalActive = false;
    }

    getPedalLatency() {
      if (!this.ctx) return 0;
      return (this.ctx.baseLatency || 0) * 1000 + (this.ctx.outputLatency || 0) * 1000;
    }

    // ── CLEANUP ──

    dispose() {
      this.stopPedalera();
      this.stopMetronome();
      this.stopWebRecording();
      this.stopPlayback();
      this.discardRecording();
      this.clearLoop();
      this.stopInputMonitoring();
      this.stopInputLevelMeter();
      this._stopLoopPositionTimer();
      this.disconnectMidi();
      this.stopAllPads();
      this.pads = [];
      this.songLabClearAll();
      if (this._lastExportUrl) {
        URL.revokeObjectURL(this._lastExportUrl);
        this._lastExportUrl = null;
      }
      this.buffers = {};
      if (this.ctx) {
        this.ctx.close();
        this.ctx = null;
      }
    }
  }

  // Expose to global scope for Dart interop
  window.GrooveLabWebAudio = GrooveLabWebAudio;
  window.grooveLabAudio = new GrooveLabWebAudio();

})();
