import AVFoundation

/// Song Lab engine for macOS — loads audio files and provides playback,
/// seeking, speed control, and waveform generation.
/// Uses AVAudioEngine for low-latency playback with real-time position reporting.
final class SongLabEngine {

    // MARK: - Types

    enum PlaybackState: String {
        case idle
        case loading
        case ready
        case playing
        case paused
    }

    // MARK: - Properties

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var speedControl: AVAudioUnitVarispeed?
    private var pitchShift: AVAudioUnitTimePitch?
    private var audioFile: AVAudioFile?
    private var audioBuffer: AVAudioPCMBuffer?

    private var state: PlaybackState = .idle
    private var duration: Double = 0.0
    private var sampleRate: Double = 44100.0
    private var totalFrames: AVAudioFrameCount = 0
    private var volume: Float = 1.0
    private var speed: Float = 1.0
    private var pan: Float = 0.0
    private var isMuted: Bool = false
    private var isSolo: Bool = false
    private var pitchSemitones: Float = 0.0

    // Loop region
    private var loopRegionEnabled: Bool = false
    private var loopStartFrame: AVAudioFramePosition = 0
    private var loopEndFrame: AVAudioFramePosition = 0

    private var positionTimer: Timer?
    private var seekFrame: AVAudioFramePosition = 0
    private var lastPlayStartTime: Date?

    /// Cached waveform data for UI display
    private var waveformData: [Float] = []

    private let onEvent: (([String: Any]) -> Void)?

    // MARK: - Init

    init(onEvent: (([String: Any]) -> Void)? = nil) {
        self.onEvent = onEvent
    }

    // MARK: - Public API

    func loadTrack(audioData: Data, name: String) -> [String: Any] {
        // Clean up any existing playback
        stop()
        _tearDown()

        state = .loading

        // Write data to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let ext = _extensionFromName(name)
        let tempFile = tempDir.appendingPathComponent("songlab_track_\(UUID().uuidString).\(ext)")

        do {
            try audioData.write(to: tempFile)
        } catch {
            print("SongLabEngine: Failed to write temp file: \(error)")
            state = .idle
            return ["error": "write_failed"]
        }

        // Load audio file
        do {
            let file = try AVAudioFile(forReading: tempFile)
            self.audioFile = file
            self.sampleRate = file.processingFormat.sampleRate
            self.totalFrames = AVAudioFrameCount(file.length)
            self.duration = Double(file.length) / file.processingFormat.sampleRate

            // Read entire file into buffer for playback and waveform generation
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: totalFrames
            ) else {
                state = .idle
                return ["error": "buffer_alloc_failed"]
            }
            try file.read(into: buffer)
            self.audioBuffer = buffer

            // Generate waveform
            _generateWaveform(from: buffer, numSamples: 200)

            state = .ready
            seekFrame = 0

            return [
                "duration": duration,
                "sampleRate": sampleRate,
                "channels": Int(file.processingFormat.channelCount),
                "name": name,
            ]
        } catch {
            print("SongLabEngine: Failed to load audio: \(error)")
            state = .idle
            return ["error": "load_failed: \(error.localizedDescription)"]
        }
    }

    func play() {
        guard state == .ready || state == .paused else { return }
        guard let buffer = audioBuffer else { return }

        if state == .paused, let _ = audioEngine, let player = playerNode {
            // Resume from pause
            player.play()
            state = .playing
            _startPositionTimer()
            _sendStateEvent()
            return
        }

        // Fresh start or play from seek position
        _tearDown()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let varipitch = AVAudioUnitVarispeed()
        let timePitch = AVAudioUnitTimePitch()

        engine.attach(player)
        engine.attach(varipitch)
        engine.attach(timePitch)

        let format = buffer.format
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: varipitch, format: format)
        engine.connect(varipitch, to: engine.mainMixerNode, format: format)

        varipitch.rate = speed
        timePitch.pitch = pitchSemitones * 100.0 // AVAudioUnitTimePitch uses cents
        timePitch.rate = 1.0 // Speed is handled by varipitch
        player.volume = isMuted ? 0 : volume
        player.pan = pan

        do {
            try engine.start()
        } catch {
            print("SongLabEngine: Engine start error: \(error)")
            return
        }

        self.audioEngine = engine
        self.playerNode = player
        self.speedControl = varipitch
        self.pitchShift = timePitch

        // Schedule from seek position (or loop region)
        let startFrame: AVAudioFramePosition
        let endFrame: AVAudioFramePosition
        if loopRegionEnabled && loopEndFrame > loopStartFrame {
            startFrame = max(seekFrame, loopStartFrame)
            endFrame = loopEndFrame
        } else {
            startFrame = seekFrame
            endFrame = AVAudioFramePosition(totalFrames)
        }
        let remainingFrames = AVAudioFrameCount(endFrame - startFrame)
        guard remainingFrames > 0 else { return }

        guard let segmentBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: remainingFrames
        ) else { return }

        // Copy from startFrame to endFrame
        if let src = buffer.floatChannelData, let dst = segmentBuffer.floatChannelData {
            for ch in 0..<Int(format.channelCount) {
                memcpy(dst[ch], src[ch].advanced(by: Int(startFrame)), Int(remainingFrames) * MemoryLayout<Float>.size)
            }
        }
        segmentBuffer.frameLength = remainingFrames

        player.scheduleBuffer(segmentBuffer) { [weak self] in
            DispatchQueue.main.async {
                self?._onPlaybackComplete()
            }
        }
        player.play()

        lastPlayStartTime = Date()
        state = .playing
        _startPositionTimer()
        _sendStateEvent()
    }

    func pause() {
        guard state == .playing, let player = playerNode else { return }

        // Save current position before pausing
        seekFrame = _currentFrame()

        player.pause()
        state = .paused
        _stopPositionTimer()
        _sendStateEvent()
    }

    func stop() {
        _stopPositionTimer()
        playerNode?.stop()
        audioEngine?.stop()
        seekFrame = 0
        if state != .idle {
            state = .ready
        }
        _sendStateEvent()
        _sendPositionEvent(position: 0)
    }

    func seek(position: Double) {
        guard duration > 0 else { return }
        let clampedPos = max(0, min(1, position))
        seekFrame = AVAudioFramePosition(clampedPos * Double(totalFrames))

        let wasPlaying = state == .playing
        if wasPlaying {
            playerNode?.stop()
            audioEngine?.stop()
            _tearDown()
            state = .ready
            play()
        } else {
            _sendPositionEvent(position: clampedPos)
        }
    }

    func setVolume(_ vol: Double) {
        volume = Float(max(0, min(1, vol)))
        playerNode?.volume = isMuted ? 0 : volume
    }

    func setSpeed(_ spd: Double) {
        speed = Float(max(0.25, min(4.0, spd)))
        speedControl?.rate = speed
    }

    func setPan(_ p: Double) {
        pan = Float(max(-1, min(1, p)))
        playerNode?.pan = pan
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        playerNode?.volume = muted ? 0 : volume
    }

    func setSolo(_ solo: Bool) {
        isSolo = solo
        // Solo is managed at a higher level if multiple tracks exist
    }

    func setPitchShift(semitones: Double) {
        pitchSemitones = Float(max(-24, min(24, semitones)))
        pitchShift?.pitch = pitchSemitones * 100.0
    }

    func setLoopRegion(startTime: Double, endTime: Double) {
        guard duration > 0 else { return }
        let startPos = max(0, min(1, startTime / duration))
        let endPos = max(0, min(1, endTime / duration))
        guard endPos > startPos else { return }
        loopRegionEnabled = true
        loopStartFrame = AVAudioFramePosition(startPos * Double(totalFrames))
        loopEndFrame = AVAudioFramePosition(endPos * Double(totalFrames))
    }

    func clearLoopRegion() {
        loopRegionEnabled = false
        loopStartFrame = 0
        loopEndFrame = 0
    }

    func getPosition() -> Double {
        guard totalFrames > 0 else { return 0 }
        let currentFrame = _currentFrame()
        return Double(currentFrame) / Double(totalFrames) * duration
    }

    func getState() -> [String: Any] {
        return [
            "state": state.rawValue,
            "duration": duration,
            "position": getPosition(),
            "volume": Double(volume),
            "speed": Double(speed),
            "pan": Double(pan),
            "isMuted": isMuted,
            "pitchSemitones": Double(pitchSemitones),
            "loopRegionEnabled": loopRegionEnabled,
            "loopStart": loopRegionEnabled ? Double(loopStartFrame) / Double(max(1, totalFrames)) * duration : 0,
            "loopEnd": loopRegionEnabled ? Double(loopEndFrame) / Double(max(1, totalFrames)) * duration : 0,
        ]
    }

    func exportMixdown() -> String? {
        guard let buffer = audioBuffer, let format = buffer.format as AVAudioFormat? else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let outFile = tempDir.appendingPathComponent("songlab_mixdown_\(UUID().uuidString).wav")

        do {
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ]
            let file = try AVAudioFile(forWriting: outFile, settings: settings)
            try file.write(from: buffer)
            return outFile.path
        } catch {
            print("SongLabEngine: Export mixdown failed: \(error)")
            return nil
        }
    }

    func getWaveform(numSamples: Int) -> [Double] {
        if waveformData.isEmpty { return Array(repeating: 0.0, count: numSamples) }
        return waveformData.map { Double($0) }
    }

    func clearAll() {
        stop()
        _tearDown()
        audioFile = nil
        audioBuffer = nil
        waveformData = []
        duration = 0
        totalFrames = 0
        seekFrame = 0
        state = .idle
    }

    // MARK: - Private

    private func _currentFrame() -> AVAudioFramePosition {
        guard let player = playerNode, let lastRender = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: lastRender) else {
            return seekFrame
        }
        return seekFrame + playerTime.sampleTime
    }

    private func _onPlaybackComplete() {
        if loopRegionEnabled {
            // Loop: restart from loop start
            seekFrame = loopStartFrame
            _tearDown()
            state = .ready
            play()
            return
        }
        state = .ready
        seekFrame = 0
        _stopPositionTimer()
        _sendStateEvent()
        _sendPositionEvent(position: 0)
    }

    private func _tearDown() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        speedControl = nil
        pitchShift = nil
    }

    private func _startPositionTimer() {
        _stopPositionTimer()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?._updatePosition()
        }
    }

    private func _stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    private func _updatePosition() {
        guard totalFrames > 0 else { return }
        let currentFrame = _currentFrame()
        let pos = Double(currentFrame) / Double(totalFrames)
        let clampedPos = max(0, min(1, pos))
        _sendPositionEvent(position: clampedPos * duration)
    }

    private func _sendPositionEvent(position: Double) {
        let info: [String: Any] = [
            "type": "songLabPosition",
            "position": position,
        ]
        onEvent?(info)
    }

    private func _sendStateEvent() {
        let info: [String: Any] = [
            "type": "songLabState",
            "state": state.rawValue,
            "duration": duration,
        ]
        onEvent?(info)
    }

    private func _generateWaveform(from buffer: AVAudioPCMBuffer, numSamples: Int) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0, numSamples > 0 else { return }

        let samplesPerBin = frames / numSamples
        guard samplesPerBin > 0 else { return }

        var result = [Float](repeating: 0, count: numSamples)
        let ptr = data[0]

        for i in 0..<numSamples {
            let start = i * samplesPerBin
            let end = min(start + samplesPerBin, frames)
            var maxVal: Float = 0
            for j in start..<end {
                maxVal = max(maxVal, abs(ptr[j]))
            }
            result[i] = maxVal
        }

        waveformData = result
    }

    private func _extensionFromName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.hasSuffix(".mp3") { return "mp3" }
        if lower.hasSuffix(".wav") { return "wav" }
        if lower.hasSuffix(".m4a") { return "m4a" }
        if lower.hasSuffix(".aac") { return "aac" }
        if lower.hasSuffix(".flac") { return "flac" }
        if lower.hasSuffix(".aiff") || lower.hasSuffix(".aif") { return "aiff" }
        if lower.hasSuffix(".ogg") { return "ogg" }
        return "wav"
    }
}
