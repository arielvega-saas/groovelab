import AVFoundation

/// Loop recording engine with multi-layer overdub support.
/// Uses AVAudioEngine for low-latency recording and playback.
/// First layer defines loop length; subsequent layers are constrained to it.
final class LoopRecordingEngine {

    // MARK: - Types

    enum LoopState: String {
        case idle
        case recording
        case overdubbing
        case playing
    }

    struct Layer {
        let id: String
        var name: String
        var buffer: AVAudioPCMBuffer
        var volume: Float = 1.0
        var pan: Float = 0.0
        var isMuted: Bool = false
        var isSolo: Bool = false
    }

    // MARK: - Properties

    private let queue = DispatchQueue(label: "com.groovelab.looprecording", qos: .userInteractive)

    private var audioEngine: AVAudioEngine?
    private var playerNodes: [AVAudioPlayerNode] = []
    private var layers: [Layer] = []
    private var recordingBuffer: AVAudioPCMBuffer?
    private var recordingBufferFramePosition: AVAudioFrameCount = 0

    private var loopLengthFrames: AVAudioFrameCount = 0
    private var loopSampleRate: Double = 44100.0
    private var loopFormat: AVAudioFormat?

    private var state: LoopState = .idle
    private var playbackTimer: Timer?
    private var recordingStartTime: Date?

    private let onEvent: (([String: Any]) -> Void)?

    // MARK: - Init

    init(onEvent: (([String: Any]) -> Void)? = nil) {
        self.onEvent = onEvent
    }

    // MARK: - Public API

    func initialize() {
        queue.sync {
            _configureAudioSession()
        }
    }

    func stop() {
        queue.sync {
            _stopPlaybackInternal()
            _stopRecordingInternal()
            _tearDownEngine()
            state = .idle
            _sendStateEvent()
        }
    }

    func startRecording() -> String {
        return queue.sync {
            guard state == .idle || state == .playing else {
                return state.rawValue
            }

            let isOverdub = !layers.isEmpty

            // Stop current playback if playing
            if state == .playing {
                _stopPlaybackInternal()
            }

            // Set up engine for recording
            _tearDownEngine()
            _configureAudioSession()

            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            if loopFormat == nil {
                loopFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: inputFormat.sampleRate,
                    channels: 1,
                    interleaved: false
                )
                loopSampleRate = inputFormat.sampleRate
            }

            guard let format = loopFormat else { return "idle" }

            // Allocate recording buffer - if first layer, allow up to 5 minutes
            // If overdub, constrain to loop length
            let maxFrames: AVAudioFrameCount
            if isOverdub && loopLengthFrames > 0 {
                maxFrames = loopLengthFrames
            } else {
                maxFrames = AVAudioFrameCount(loopSampleRate * 300) // 5 min max
            }

            guard let recBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrames) else {
                print("LoopRecordingEngine: Failed to create recording buffer")
                return "idle"
            }
            recBuffer.frameLength = 0
            recordingBuffer = recBuffer
            recordingBufferFramePosition = 0

            // If overdubbing, set up player nodes for existing layers to play back
            if isOverdub {
                _attachPlayersToEngine(engine, format: format)
            }

            // Connect mixer to mainMixer so we hear playback while recording
            let mixerNode = engine.mainMixerNode
            _ = mixerNode // force initialization

            // Install tap on input
            let tapFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: inputFormat.sampleRate,
                channels: 1,
                interleaved: false
            )

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
                self?._handleRecordingBuffer(buffer)
            }

            do {
                try engine.start()
            } catch {
                print("LoopRecordingEngine: Engine start error: \(error)")
                return "idle"
            }

            // Start playback of existing layers during overdub
            if isOverdub {
                _schedulePlayersForOverdub()
            }

            self.audioEngine = engine
            self.recordingStartTime = Date()
            state = isOverdub ? .overdubbing : .recording
            _sendStateEvent()

            return state.rawValue
        }
    }

    func stopRecording() -> [String: Any] {
        return queue.sync {
            guard state == .recording || state == .overdubbing else {
                return ["success": false, "error": "Not recording"]
            }

            // Stop engine and remove tap
            audioEngine?.inputNode.removeTap(onBus: 0)
            _stopAllPlayers()
            audioEngine?.stop()

            guard let recBuffer = recordingBuffer, recordingBufferFramePosition > 0 else {
                audioEngine = nil
                state = .idle
                _sendStateEvent()
                return ["success": false, "error": "No audio captured"]
            }

            // Trim buffer to actual recorded length
            let actualFrames = min(recordingBufferFramePosition, recBuffer.frameCapacity)
            guard let format = loopFormat,
                  let trimmedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: actualFrames) else {
                audioEngine = nil
                state = .idle
                _sendStateEvent()
                return ["success": false, "error": "Buffer trim failed"]
            }

            trimmedBuffer.frameLength = actualFrames
            if let src = recBuffer.floatChannelData, let dst = trimmedBuffer.floatChannelData {
                for ch in 0..<Int(format.channelCount) {
                    memcpy(dst[ch], src[ch], Int(actualFrames) * MemoryLayout<Float>.size)
                }
            }

            // If first layer, set loop length
            if layers.isEmpty {
                loopLengthFrames = actualFrames
            }

            let layerIndex = layers.count
            let layer = Layer(
                id: UUID().uuidString,
                name: "Layer \(layerIndex + 1)",
                buffer: trimmedBuffer
            )
            layers.append(layer)

            audioEngine = nil
            recordingBuffer = nil
            recordingBufferFramePosition = 0

            let duration = Double(loopLengthFrames) / loopSampleRate
            state = .idle
            _sendStateEvent()
            _sendLayerCountEvent()

            return [
                "success": true,
                "layerCount": layers.count,
                "duration": duration,
            ]
        }
    }

    func startPlayback() {
        queue.sync {
            guard state == .idle, !layers.isEmpty else { return }

            _tearDownEngine()

            let engine = AVAudioEngine()
            guard let format = loopFormat else { return }

            _attachPlayersToEngine(engine, format: format)

            do {
                try engine.start()
            } catch {
                print("LoopRecordingEngine: Playback engine start error: \(error)")
                return
            }

            self.audioEngine = engine
            _scheduleLoopingPlayback()
            state = .playing
            _sendStateEvent()
        }
    }

    func stopPlayback() {
        queue.sync {
            guard state == .playing else { return }
            _stopPlaybackInternal()
            _tearDownEngine()
            state = .idle
            _sendStateEvent()
        }
    }

    func undoLayer() {
        queue.sync {
            guard !layers.isEmpty else { return }
            let wasPlaying = state == .playing
            if wasPlaying { _stopPlaybackInternal(); _tearDownEngine() }

            layers.removeLast()

            if layers.isEmpty {
                loopLengthFrames = 0
            }

            if wasPlaying && !layers.isEmpty {
                state = .idle
                // Restart playback outside the current sync block would be re-entrant,
                // so just go idle and let the caller restart.
            } else {
                state = .idle
            }
            _sendStateEvent()
            _sendLayerCountEvent()
        }
    }

    func clearLoop() {
        queue.sync {
            _stopPlaybackInternal()
            _stopRecordingInternal()
            _tearDownEngine()

            layers.removeAll()
            playerNodes.removeAll()
            loopLengthFrames = 0
            loopFormat = nil
            recordingBuffer = nil
            recordingBufferFramePosition = 0

            state = .idle
            _sendStateEvent()
            _sendLayerCountEvent()
        }
    }

    func setLayerVolume(index: Int, volume: Double) {
        queue.sync {
            guard index >= 0, index < layers.count else { return }
            layers[index].volume = Float(max(0, min(1, volume)))
            _updatePlayerParameters()
        }
    }

    func setLayerMute(index: Int, muted: Bool) {
        queue.sync {
            guard index >= 0, index < layers.count else { return }
            layers[index].isMuted = muted
            _updatePlayerParameters()
        }
    }

    func setLayerSolo(index: Int, solo: Bool) {
        queue.sync {
            guard index >= 0, index < layers.count else { return }
            layers[index].isSolo = solo
            _updatePlayerParameters()
        }
    }

    func setLayerPan(index: Int, pan: Double) {
        queue.sync {
            guard index >= 0, index < layers.count else { return }
            layers[index].pan = Float(max(-1, min(1, pan)))
            _updatePlayerParameters()
        }
    }

    func deleteLayer(index: Int) {
        queue.sync {
            guard index >= 0, index < layers.count else { return }
            let wasPlaying = state == .playing
            if wasPlaying { _stopPlaybackInternal(); _tearDownEngine() }

            layers.remove(at: index)

            if layers.isEmpty {
                loopLengthFrames = 0
            }

            state = .idle
            _sendStateEvent()
            _sendLayerCountEvent()
        }
    }

    func renameLayer(index: Int, name: String) {
        queue.sync {
            guard index >= 0, index < layers.count else { return }
            layers[index].name = name
        }
    }

    func getState() -> [String: Any] {
        return queue.sync {
            let duration = loopLengthFrames > 0 ? Double(loopLengthFrames) / loopSampleRate : 0.0
            let layerList: [[String: Any]] = layers.enumerated().map { index, layer in
                [
                    "index": index,
                    "id": layer.id,
                    "name": layer.name,
                    "volume": Double(layer.volume),
                    "pan": Double(layer.pan),
                    "isMuted": layer.isMuted,
                    "isSolo": layer.isSolo,
                ]
            }
            return [
                "state": state.rawValue,
                "layerCount": layers.count,
                "loopDuration": duration,
                "sampleRate": loopSampleRate,
                "layers": layerList,
            ]
        }
    }

    // MARK: - Private: Audio Session

    private func _configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("LoopRecordingEngine: AudioSession error: \(error)")
        }
    }

    // MARK: - Private: Recording

    private func _handleRecordingBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.sync {
            guard let recBuffer = recordingBuffer, let format = loopFormat else { return }

            let framesToCopy: AVAudioFrameCount
            let remaining = recBuffer.frameCapacity - recordingBufferFramePosition
            if remaining == 0 { return }
            framesToCopy = min(buffer.frameLength, remaining)

            if let src = buffer.floatChannelData, let dst = recBuffer.floatChannelData {
                for ch in 0..<Int(format.channelCount) {
                    let srcPtr = src[ch]
                    let dstPtr = dst[ch].advanced(by: Int(recordingBufferFramePosition))
                    memcpy(dstPtr, srcPtr, Int(framesToCopy) * MemoryLayout<Float>.size)
                }
            }

            recordingBufferFramePosition += framesToCopy
            recBuffer.frameLength = recordingBufferFramePosition

            // Auto-stop overdub when loop length reached
            if state == .overdubbing && loopLengthFrames > 0 && recordingBufferFramePosition >= loopLengthFrames {
                // Signal via event; actual stop must happen on main thread
                DispatchQueue.main.async { [weak self] in
                    _ = self?.stopRecording()
                }
            }
        }
    }

    private func _stopRecordingInternal() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        recordingBuffer = nil
        recordingBufferFramePosition = 0
    }

    // MARK: - Private: Playback

    private func _attachPlayersToEngine(_ engine: AVAudioEngine, format: AVAudioFormat) {
        playerNodes.removeAll()
        for _ in layers {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            playerNodes.append(player)
        }
        _updatePlayerParameters()
    }

    private func _schedulePlayersForOverdub() {
        for (i, player) in playerNodes.enumerated() {
            guard i < layers.count else { break }
            let layer = layers[i]
            if _isLayerAudible(index: i) {
                player.scheduleBuffer(layer.buffer, at: nil, options: [], completionHandler: nil)
                player.play()
            }
        }
    }

    private func _scheduleLoopingPlayback() {
        for (i, player) in playerNodes.enumerated() {
            guard i < layers.count else { break }
            let layer = layers[i]
            if _isLayerAudible(index: i) {
                player.scheduleBuffer(layer.buffer, at: nil, options: .loops, completionHandler: nil)
                player.play()
            }
        }
    }

    private func _stopPlaybackInternal() {
        _stopAllPlayers()
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func _stopAllPlayers() {
        for player in playerNodes {
            player.stop()
        }
    }

    private func _tearDownEngine() {
        _stopAllPlayers()
        audioEngine?.stop()
        audioEngine = nil
        playerNodes.removeAll()
    }

    private func _updatePlayerParameters() {
        let hasSolo = layers.contains { $0.isSolo }
        for (i, player) in playerNodes.enumerated() {
            guard i < layers.count else { break }
            let layer = layers[i]
            let audible = _isLayerAudible(index: i)
            player.volume = audible ? layer.volume : 0.0
            player.pan = layer.pan
        }
        // Also update engine main mixer if needed
        _ = hasSolo // suppress unused warning
    }

    private func _isLayerAudible(index: Int) -> Bool {
        guard index >= 0, index < layers.count else { return false }
        let layer = layers[index]
        if layer.isMuted { return false }
        let hasSolo = layers.contains { $0.isSolo }
        if hasSolo && !layer.isSolo { return false }
        return true
    }

    // MARK: - Private: Events

    private func _sendStateEvent() {
        let info: [String: Any] = [
            "type": "loopState",
            "state": state.rawValue,
            "layerCount": layers.count,
            "loopDuration": loopLengthFrames > 0 ? Double(loopLengthFrames) / loopSampleRate : 0.0,
        ]
        onEvent?(info)
    }

    private func _sendLayerCountEvent() {
        let info: [String: Any] = [
            "type": "layerCount",
            "count": layers.count,
        ]
        onEvent?(info)
    }
}
