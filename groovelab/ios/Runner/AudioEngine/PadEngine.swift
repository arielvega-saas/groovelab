import AVFoundation

/// Pad engine for iOS — loads audio samples into pads and provides
/// polyphonic playback with per-pad volume/pan, crossfade, and master volume.
/// Uses AVAudioEngine with a pool of AVAudioPlayerNode for low-latency triggering.
/// iOS version: relies on AVAudioSession configured by AudioSessionManager.
final class PadEngine {

    // MARK: - Pad State

    private struct PadState {
        var buffer: AVAudioPCMBuffer
        var volume: Float = 1.0
        var pan: Float = 0.0       // -1.0 (left) to 1.0 (right)
        var isPlaying: Bool = false
        var playerIndex: Int = -1  // index into playerPool currently playing this pad
    }

    // MARK: - Audio Graph

    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var sampleRate: Double = 44100.0

    // Pool of player nodes for polyphonic playback
    private let playerPoolSize = 8
    private var playerPool: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0

    // Track which pad is using which player
    private var playerToPad: [Int: String] = [:]

    // Loaded pads keyed by string identifier
    private var pads: [String: PadState] = [:]

    // Master volume for all pads
    private var masterVolume: Float = 1.0

    // Crossfade state
    private var crossfadeTimer: Timer?

    private let onEvent: (([String: Any]) -> Void)?

    // MARK: - Init

    init(onEvent: (([String: Any]) -> Void)? = nil) {
        self.onEvent = onEvent
    }

    // MARK: - Setup

    func initialize() {
        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)

        // On iOS, get sample rate from the audio session / output node
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if sampleRate == 0 { sampleRate = 44100.0 }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        for _ in 0..<playerPoolSize {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
            playerPool.append(player)
        }

        engine.connect(mixer, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("PadEngine: AVAudioEngine start error: \(error)")
        }

        self.audioEngine = engine
        self.mixerNode = mixer
    }

    // MARK: - Sound Loading

    func loadPadSound(key: String, wavData: Data) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }
        guard wavData.count > 44 else { return }

        // Parse WAV header to determine source format
        let headerChannels = wavData.withUnsafeBytes { ptr -> Int in
            guard ptr.count > 22 else { return 1 }
            return Int(ptr.load(fromByteOffset: 22, as: UInt16.self))
        }

        let pcmData = wavData.subdata(in: 44..<wavData.count)
        let bytesPerSample = 2 // 16-bit
        let srcSampleCount = pcmData.count / (bytesPerSample * headerChannels)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(srcSampleCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(srcSampleCount)

        guard let floatData = buffer.floatChannelData else { return }
        pcmData.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
            let int16Ptr = rawPtr.bindMemory(to: Int16.self)
            if headerChannels == 2 {
                // Stereo: deinterleave
                for i in 0..<srcSampleCount {
                    floatData[0][i] = Float(int16Ptr[i * 2]) / 32768.0
                    floatData[1][i] = Float(int16Ptr[i * 2 + 1]) / 32768.0
                }
            } else {
                // Mono: duplicate to both channels
                for i in 0..<srcSampleCount {
                    let val = Float(int16Ptr[i]) / 32768.0
                    floatData[0][i] = val
                    floatData[1][i] = val
                }
            }
        }

        pads[key] = PadState(buffer: buffer)
    }

    // MARK: - Playback

    func playPad(key: String) {
        guard let pad = pads[key], let engine = audioEngine, engine.isRunning else { return }

        // Stop any currently playing instance of this pad
        stopPad(key: key)

        let playerIdx = nextPlayerIndex % playerPoolSize
        nextPlayerIndex += 1

        // If this player was playing another pad, mark that pad as stopped
        if let oldPadKey = playerToPad[playerIdx] {
            pads[oldPadKey]?.isPlaying = false
            pads[oldPadKey]?.playerIndex = -1
        }

        let player = playerPool[playerIdx]
        if !player.isPlaying { player.play() }

        // Apply volume and pan
        let effectiveVolume = pad.volume * masterVolume
        player.volume = effectiveVolume
        player.pan = pad.pan

        player.scheduleBuffer(pad.buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                self?.pads[key]?.isPlaying = false
                self?.pads[key]?.playerIndex = -1
                self?.playerToPad.removeValue(forKey: playerIdx)
            }
        }

        pads[key]?.isPlaying = true
        pads[key]?.playerIndex = playerIdx
        playerToPad[playerIdx] = key
    }

    func stopPad(key: String) {
        guard let pad = pads[key], pad.isPlaying, pad.playerIndex >= 0 else { return }
        let player = playerPool[pad.playerIndex]
        player.stop()
        player.play() // Re-ready the player for next use
        playerToPad.removeValue(forKey: pad.playerIndex)
        pads[key]?.isPlaying = false
        pads[key]?.playerIndex = -1
    }

    func stopAllPads() {
        for key in pads.keys {
            stopPad(key: key)
        }
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
    }

    // MARK: - Volume & Pan

    func setPadVolume(key: String, volume: Double) {
        pads[key]?.volume = Float(max(0, min(1, volume)))
        // Update live if currently playing
        if let pad = pads[key], pad.isPlaying, pad.playerIndex >= 0 {
            playerPool[pad.playerIndex].volume = pad.volume * masterVolume
        }
    }

    func setPadPan(key: String, pan: Double) {
        pads[key]?.pan = Float(max(-1, min(1, pan)))
        if let pad = pads[key], pad.isPlaying, pad.playerIndex >= 0 {
            playerPool[pad.playerIndex].pan = pad.pan
        }
    }

    func setMasterVolume(_ volume: Double) {
        masterVolume = Float(max(0, min(1, volume)))
        // Update all currently playing pads
        for (key, pad) in pads where pad.isPlaying && pad.playerIndex >= 0 {
            playerPool[pad.playerIndex].volume = pad.volume * masterVolume
            _ = key // suppress unused warning
        }
    }

    // MARK: - Crossfade

    func crossfade(fromKey: String, toKey: String, duration: Double) {
        guard pads[toKey] != nil else { return }

        crossfadeTimer?.invalidate()

        let steps = 20
        let interval = duration / Double(steps)
        var currentStep = 0

        // Start the new pad at zero volume
        let originalToVolume = pads[toKey]?.volume ?? 1.0
        let originalFromVolume = pads[fromKey]?.volume ?? 1.0
        setPadVolume(key: toKey, volume: 0)
        playPad(key: toKey)

        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)

            // Fade out 'from', fade in 'to'
            let fromVol = Double(originalFromVolume * (1.0 - progress))
            let toVol = Double(originalToVolume * progress)

            self.setPadVolume(key: fromKey, volume: fromVol)
            self.setPadVolume(key: toKey, volume: toVol)

            if currentStep >= steps {
                timer.invalidate()
                self.crossfadeTimer = nil
                self.stopPad(key: fromKey)
                // Restore original volume on the destination pad
                self.setPadVolume(key: fromKey, volume: Double(originalFromVolume))
                self.setPadVolume(key: toKey, volume: Double(originalToVolume))
            }
        }
    }

    // MARK: - Cleanup

    func dispose() {
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        stopAllPads()
        for player in playerPool { player.stop() }
        audioEngine?.stop()
        audioEngine = nil
        mixerNode = nil
        pads.removeAll()
        playerToPad.removeAll()
    }
}
