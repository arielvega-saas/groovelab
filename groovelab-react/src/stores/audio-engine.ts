/**
 * Core Audio Engine — Singleton wrapper around Tone.js + Web Audio API
 * Provides low-latency (<10ms) audio scheduling, synthesis, routing,
 * convolution reverb send, 3-band master EQ, effect chain builder,
 * offline mix export, and WAV encoding.
 */
import * as Tone from 'tone'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type WaveShape = 'sine' | 'sawtooth' | 'square' | 'triangle'

export type EffectName =
  | 'reverb'
  | 'delay'
  | 'chorus'
  | 'distortion'
  | 'compressor'
  | 'eq3'
  | 'phaser'
  | 'tremolo'
  | 'bitcrusher'
  | 'pitchshift'
  | 'filter'
  | 'autowah'
  | 'vibrato'
  | 'chebyshev'
  | 'freeverb'
  | 'pingpong'

export interface EQBands {
  low: number   // gain in dB  (default 0)
  mid: number   // gain in dB  (default 0)
  high: number  // gain in dB  (default 0)
}

export interface LatencyReport {
  baseLatency: number      // seconds — hardware output latency
  outputLatency: number    // seconds — OS-level output latency (if available)
  lookAhead: number        // seconds — scheduling lookahead
  totalEstimate: number    // seconds — best-effort round-trip estimate
  sampleRate: number
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

class AudioEngine {
  private static instance: AudioEngine
  private initialized = false

  // Master signal chain: source → masterGain → masterEQ → reverbSend (parallel) → limiter → destination
  private masterGain!: Tone.Gain
  private limiter!: Tone.Limiter

  // 3-band master EQ
  private eqLow!: Tone.Filter
  private eqMid!: Tone.Filter
  private eqHigh!: Tone.Filter
  private eqLowGain!: Tone.Gain
  private eqMidGain!: Tone.Gain
  private eqHighGain!: Tone.Gain
  private eqMerge!: Tone.Gain

  // Convolution reverb send bus
  private reverbSend!: Tone.Gain
  private reverb!: Tone.Reverb

  // -----------------------------------------------------------------------
  // Singleton
  // -----------------------------------------------------------------------

  static getInstance(): AudioEngine {
    if (!AudioEngine.instance) {
      AudioEngine.instance = new AudioEngine()
    }
    return AudioEngine.instance
  }

  // -----------------------------------------------------------------------
  // Initialisation
  // -----------------------------------------------------------------------

  async init() {
    if (this.initialized) return

    // Request 48 kHz sample rate where supported
    const rawCtx = Tone.getContext().rawContext as AudioContext
    if (rawCtx.sampleRate !== 48_000) {
      try {
        const newCtx = new AudioContext({ sampleRate: 48_000 })
        Tone.setContext(new Tone.Context(newCtx))
      } catch {
        // Browser may not support 48 kHz — fall back to default
      }
    }

    await Tone.start()

    // Low latency: 5 ms lookahead
    Tone.getContext().lookAhead = 0.005

    // --- Build master signal chain ---

    this.limiter = new Tone.Limiter(-1).toDestination()

    // 3-band parametric EQ (low shelf → band pass → high shelf)
    this.eqMerge = new Tone.Gain(1).connect(this.limiter)

    this.eqLow = new Tone.Filter({ type: 'lowshelf', frequency: 320, rolloff: -12 })
    this.eqMid = new Tone.Filter({ type: 'peaking', frequency: 1000, rolloff: -12 })
    this.eqHigh = new Tone.Filter({ type: 'highshelf', frequency: 3200, rolloff: -12 })

    this.eqLowGain = new Tone.Gain(1)
    this.eqMidGain = new Tone.Gain(1)
    this.eqHighGain = new Tone.Gain(1)

    // Each band: split → filter → gain → merge
    this.eqLow.connect(this.eqLowGain)
    this.eqLowGain.connect(this.eqMerge)

    this.eqMid.connect(this.eqMidGain)
    this.eqMidGain.connect(this.eqMerge)

    this.eqHigh.connect(this.eqHighGain)
    this.eqHighGain.connect(this.eqMerge)

    // Master gain feeds into the three EQ bands (parallel split)
    this.masterGain = new Tone.Gain(0.8)
    this.masterGain.connect(this.eqLow)
    this.masterGain.connect(this.eqMid)
    this.masterGain.connect(this.eqHigh)

    // --- Convolution reverb send bus ---
    this.reverb = new Tone.Reverb({ decay: 3.5, preDelay: 0.025, wet: 1 })
    await this.reverb.generate()
    this.reverb.connect(this.eqMerge)

    this.reverbSend = new Tone.Gain(0) // default: dry (0 = no send)
    this.reverbSend.connect(this.reverb)
    this.masterGain.connect(this.reverbSend)

    this.initialized = true
  }

  // -----------------------------------------------------------------------
  // Accessors
  // -----------------------------------------------------------------------

  get isReady(): boolean { return this.initialized }
  get master(): Tone.Gain { return this.masterGain }
  get context(): Tone.BaseContext { return Tone.getContext() }
  get now(): number { return Tone.now() }
  get transport() { return Tone.getTransport() }

  // -----------------------------------------------------------------------
  // Reverb send
  // -----------------------------------------------------------------------

  /** Set the reverb send level (0 = fully dry, 1 = fully wet). */
  setReverbSend(amount: number): void {
    this.reverbSend.gain.rampTo(Math.max(0, Math.min(1, amount)), 0.05)
  }

  getReverbSend(): number {
    return this.reverbSend.gain.value
  }

  // -----------------------------------------------------------------------
  // Master EQ
  // -----------------------------------------------------------------------

  /** Set 3-band master EQ gains in dB (e.g. { low: 3, mid: 0, high: -2 }). */
  setMasterEQ(bands: Partial<EQBands>): void {
    if (bands.low !== undefined) {
      this.eqLowGain.gain.rampTo(Tone.dbToGain(bands.low), 0.05)
    }
    if (bands.mid !== undefined) {
      this.eqMidGain.gain.rampTo(Tone.dbToGain(bands.mid), 0.05)
    }
    if (bands.high !== undefined) {
      this.eqHighGain.gain.rampTo(Tone.dbToGain(bands.high), 0.05)
    }
  }

  getMasterEQ(): EQBands {
    return {
      low: Tone.gainToDb(this.eqLowGain.gain.value),
      mid: Tone.gainToDb(this.eqMidGain.gain.value),
      high: Tone.gainToDb(this.eqHighGain.gain.value),
    }
  }

  // -----------------------------------------------------------------------
  // Existing playback methods (preserved API)
  // -----------------------------------------------------------------------

  /** Play a click sound for metronome */
  playClick(freq: number, volume: number, duration = 0.05): void {
    const synth = new Tone.Synth({
      oscillator: { type: 'sine' },
      envelope: { attack: 0.001, decay: duration, sustain: 0, release: 0.01 },
    }).connect(this.masterGain)
    synth.triggerAttackRelease(freq, duration, undefined, volume)
    setTimeout(() => synth.dispose(), 200)
  }

  /** Play a noise burst (hi-hat, shaker) */
  playNoise(duration: number, volume: number, filterFreq = 8000): void {
    const noise = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: duration, sustain: 0, release: 0.01 },
    }).connect(this.masterGain)
    const filter = new Tone.Filter(filterFreq, 'highpass')
    noise.connect(filter)
    filter.connect(this.masterGain)
    noise.triggerAttackRelease(duration, undefined, volume)
    setTimeout(() => { noise.dispose(); filter.dispose() }, 500)
  }

  /** Play a drum sample from buffer */
  playBuffer(buffer: Tone.ToneAudioBuffer, volume = 1, _pan = 0): void {
    const player = new Tone.Player(buffer).connect(this.masterGain)
    player.volume.value = Tone.gainToDb(volume)
    player.start()
    player.onstop = () => player.dispose()
  }

  /** Generate a reference tone */
  playTone(freq: number, shape: WaveShape = 'sine', volume = 0.3): Tone.Synth {
    const synth = new Tone.Synth({
      oscillator: { type: shape },
      envelope: { attack: 0.01, decay: 0.1, sustain: 0.8, release: 0.3 },
    }).connect(this.masterGain)
    synth.triggerAttack(freq, undefined, volume)
    return synth
  }

  /** Create an analyser for visualizations */
  createAnalyser(fftSize = 2048): AnalyserNode {
    const analyser = Tone.getContext().rawContext.createAnalyser()
    analyser.fftSize = fftSize
    this.masterGain.connect(analyser as unknown as AudioNode)
    return analyser
  }

  /** Create a mic input stream */
  async createMicInput(): Promise<Tone.UserMedia> {
    const mic = new Tone.UserMedia()
    await mic.open()
    return mic
  }

  // -----------------------------------------------------------------------
  // Effect chain builder (pedalboard)
  // -----------------------------------------------------------------------

  /**
   * Create a serial chain of Tone.js effects by name.
   * Returns the instantiated nodes so the caller can tweak parameters and
   * connect source → chain[0], chain[n-1] → destination.
   */
  createEffectChain(effects: EffectName[]): Tone.ToneAudioNode[] {
    const nodes: Tone.ToneAudioNode[] = effects.map((name) => {
      switch (name) {
        case 'reverb':      return new Tone.Reverb({ decay: 2.5, preDelay: 0.01 })
        case 'delay':       return new Tone.FeedbackDelay('8n', 0.4)
        case 'chorus':      return new Tone.Chorus(4, 2.5, 0.5).start()
        case 'distortion':  return new Tone.Distortion(0.4)
        case 'compressor':  return new Tone.Compressor(-24, 4)
        case 'eq3':         return new Tone.EQ3(0, 0, 0)
        case 'phaser':      return new Tone.Phaser({ frequency: 1, octaves: 3, baseFrequency: 350 })
        case 'tremolo':     return new Tone.Tremolo(9, 0.75).start()
        case 'bitcrusher':  return new Tone.BitCrusher(8)
        case 'pitchshift':  return new Tone.PitchShift(0)
        case 'filter':      return new Tone.Filter(1000, 'lowpass')
        case 'autowah':     return new Tone.AutoWah(50, 6, -30)
        case 'vibrato':     return new Tone.Vibrato(5, 0.1)
        case 'chebyshev':   return new Tone.Chebyshev(50)
        case 'freeverb':    return new Tone.Freeverb(0.7, 3000)
        case 'pingpong':    return new Tone.PingPongDelay('4n', 0.3)
        default: {
          const _exhaustive: never = name
          throw new Error(`Unknown effect: ${_exhaustive}`)
        }
      }
    })

    // Wire nodes in series
    for (let i = 0; i < nodes.length - 1; i++) {
      nodes[i].connect(nodes[i + 1])
    }

    return nodes
  }

  // -----------------------------------------------------------------------
  // Offline mix export
  // -----------------------------------------------------------------------

  /**
   * Render an array of AudioBuffers into a single mixed-down AudioBuffer
   * using an OfflineAudioContext (non-realtime, deterministic).
   */
  async exportMix(buffers: AudioBuffer[], duration: number): Promise<AudioBuffer> {
    if (buffers.length === 0) {
      throw new Error('exportMix: at least one buffer is required')
    }

    const sampleRate = buffers[0].sampleRate
    const channels = Math.max(...buffers.map((b) => b.numberOfChannels))
    const length = Math.ceil(duration * sampleRate)

    const offline = new OfflineAudioContext(channels, length, sampleRate)

    for (const buf of buffers) {
      const source = offline.createBufferSource()
      source.buffer = buf
      source.connect(offline.destination)
      source.start(0)
    }

    return offline.startRendering()
  }

  // -----------------------------------------------------------------------
  // WAV export
  // -----------------------------------------------------------------------

  /**
   * Encode an AudioBuffer into a 16-bit PCM WAV Blob.
   * Works entirely in-memory — no external dependencies.
   */
  audioBufferToWav(buffer: AudioBuffer): Blob {
    const numChannels = buffer.numberOfChannels
    const sampleRate = buffer.sampleRate
    const length = buffer.length
    const bytesPerSample = 2 // 16-bit
    const blockAlign = numChannels * bytesPerSample
    const dataSize = length * blockAlign
    const headerSize = 44
    const totalSize = headerSize + dataSize

    const arrayBuffer = new ArrayBuffer(totalSize)
    const view = new DataView(arrayBuffer)

    // Helper: write ASCII string
    const writeString = (offset: number, str: string) => {
      for (let i = 0; i < str.length; i++) {
        view.setUint8(offset + i, str.charCodeAt(i))
      }
    }

    // RIFF header
    writeString(0, 'RIFF')
    view.setUint32(4, totalSize - 8, true)
    writeString(8, 'WAVE')

    // fmt sub-chunk
    writeString(12, 'fmt ')
    view.setUint32(16, 16, true)               // sub-chunk size
    view.setUint16(20, 1, true)                 // PCM format
    view.setUint16(22, numChannels, true)
    view.setUint32(24, sampleRate, true)
    view.setUint32(28, sampleRate * blockAlign, true) // byte rate
    view.setUint16(32, blockAlign, true)
    view.setUint16(34, bytesPerSample * 8, true) // bits per sample

    // data sub-chunk
    writeString(36, 'data')
    view.setUint32(40, dataSize, true)

    // Interleave channel data and convert float32 → int16
    const channelData: Float32Array[] = []
    for (let ch = 0; ch < numChannels; ch++) {
      channelData.push(buffer.getChannelData(ch))
    }

    let offset = headerSize
    for (let i = 0; i < length; i++) {
      for (let ch = 0; ch < numChannels; ch++) {
        const sample = channelData[ch][i]
        // Clamp to [-1, 1] then scale to Int16 range
        const clamped = Math.max(-1, Math.min(1, sample))
        const int16 = clamped < 0 ? clamped * 0x8000 : clamped * 0x7FFF
        view.setInt16(offset, int16, true)
        offset += bytesPerSample
      }
    }

    return new Blob([arrayBuffer], { type: 'audio/wav' })
  }

  // -----------------------------------------------------------------------
  // Latency measurement
  // -----------------------------------------------------------------------

  /**
   * Return a snapshot of the current audio-path latency.
   * `totalEstimate` is a best-effort sum of all measurable contributors.
   */
  measureLatency(): LatencyReport {
    const ctx = Tone.getContext().rawContext as AudioContext
    const baseLatency = ctx.baseLatency ?? 0
    const outputLatency = (ctx as unknown as { outputLatency?: number }).outputLatency ?? 0
    const lookAhead = Tone.getContext().lookAhead

    return {
      baseLatency,
      outputLatency,
      lookAhead,
      totalEstimate: baseLatency + outputLatency + lookAhead,
      sampleRate: ctx.sampleRate,
    }
  }

  // -----------------------------------------------------------------------
  // Cleanup
  // -----------------------------------------------------------------------

  dispose(): void {
    this.reverbSend?.dispose()
    this.reverb?.dispose()
    this.eqLow?.dispose()
    this.eqMid?.dispose()
    this.eqHigh?.dispose()
    this.eqLowGain?.dispose()
    this.eqMidGain?.dispose()
    this.eqHighGain?.dispose()
    this.eqMerge?.dispose()
    this.masterGain?.dispose()
    this.limiter?.dispose()
    this.initialized = false
  }
}

export const audioEngine = AudioEngine.getInstance()
