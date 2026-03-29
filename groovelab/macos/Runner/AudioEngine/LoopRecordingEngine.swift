import AVFoundation

/// Loop recording engine with multi-layer overdub support for macOS.
/// Uses AVAudioEngine for low-latency recording and playback.
/// First layer defines loop length; subsequent layers are constrained to it.
/// macOS port — no AVAudioSession, no haptics.
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
        // macOS: no AVAudioSession to configure.
        // Engine is set up on demand in startRecording / startPlayback.
    }

    func stop() {
        queue.sync {
            _stopPlaybackInternal()
            _stopRecordingInternal()
            _tearDownEngine()
            state = .idle
            _sendStateEvent()
        }
        _stopPositionTimer()
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

            // Start position tracking during overdub
            if isOverdub {
                DispatchQueue.main.async { [weak self] in
                    self?._startPositionTimer()
                }
            }

            return state.rawValue
        }
    }

    func stopRecording() -> [String: Any] {
        _stopPositionTimer()
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
            _startPositionTimer()
        }
    }

    func stopPlayback() {
        queue.sync {
            guard state == .playing else { return }
            _stopPlaybackInternal()
            _tearDownEngine()
            state = .idle
            _sendStateEvent()
            _stopPositionTimer()
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

            state = .idle
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

    func getLayerWaveform(index: Int, numSamples: Int) -> [Double] {
        return queue.sync {
            guard index >= 0, index < layers.count else {
                return Array(repeating: 0.0, count: numSamples)
            }
            let buffer = layers[index].buffer
            guard let data = buffer.floatChannelData else {
                return Array(repeating: 0.0, count: numSamples)
            }
            let frames = Int(buffer.frameLength)
            guard frames > 0, numSamples > 0 else {
                return Array(repeating: 0.0, count: numSamples)
            }
            let samplesPerBin = frames / numSamples
            guard samplesPerBin > 0 else {
                return Array(repeating: 0.0, count: numSamples)
            }
            var result = [Double](repeating: 0, count: numSamples)
            let ptr = data[0]
            for i in 0..<numSamples {
                let start = i * samplesPerBin
                let end = min(start + samplesPerBin, frames)
                var maxVal: Float = 0
                for j in start..<end {
                    maxVal = max(maxVal, abs(ptr[j]))
                }
                result[i] = Double(maxVal)
            }
            return result
        }
    }

    // MARK: - Input Monitoring

    private var monitorNode: AVAudioPlayerNode?
    private var monitorMixerNode: AVAudioMixerNode?
    private var isMonitoring: Bool = false
    private var monitorVolume: Float = 1.0
    private var masterVolume: Float = 1.0

    /// Start monitoring audio input through speakers (for live playback monitoring)
    func startInputMonitoring() {
        guard !isMonitoring else { return }
        // If engine is not running, set up a dedicated monitoring engine
        if audioEngine == nil {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            let monitorMixer = AVAudioMixerNode()
            engine.attach(monitorMixer)
            engine.connect(inputNode, to: monitorMixer, format: inputFormat)
            engine.connect(monitorMixer, to: engine.mainMixerNode, format: inputFormat)
            monitorMixer.outputVolume = monitorVolume

            do {
                try engine.start()
                self.audioEngine = engine
                self.monitorMixerNode = monitorMixer
                isMonitoring = true
            } catch {
                print("LoopRecordingEngine: Monitor start error: \(error)")
            }
        }
    }

    func stopInputMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitorMixerNode?.outputVolume = 0
        monitorMixerNode = nil
        // Only tear down if we're not recording/playing
        if state == .idle {
            _tearDownEngine()
        }
    }

    func setMonitorVolume(volume: Double) {
        monitorVolume = Float(max(0, min(1, volume)))
        monitorMixerNode?.outputVolume = monitorVolume
    }

    func setMasterVolume(volume: Double) {
        masterVolume = Float(max(0, min(1, volume)))
        audioEngine?.mainMixerNode.outputVolume = masterVolume
    }

    // MARK: - Input Level Metering

    private var inputLevelMeteringActive: Bool = false
    private var meteringEngine: AVAudioEngine?

    func startInputLevelMeter() {
        guard !inputLevelMeteringActive else { return }
        inputLevelMeteringActive = true

        // If no engine is running, create a lightweight one for metering
        if audioEngine == nil && meteringEngine == nil {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            let tapFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: inputFormat.sampleRate,
                channels: 1,
                interleaved: false
            )

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
                DispatchQueue.main.async {
                    self?._sendInputLevelEvent(buffer)
                }
            }

            do {
                try engine.start()
                meteringEngine = engine
            } catch {
                print("LoopRecordingEngine: Metering engine start error: \(error)")
                inputLevelMeteringActive = false
            }
        }
    }

    func stopInputLevelMeter() {
        inputLevelMeteringActive = false
        meteringEngine?.inputNode.removeTap(onBus: 0)
        meteringEngine?.stop()
        meteringEngine = nil
    }

    // MARK: - Export

    func exportMixdown() -> String? {
        return queue.sync {
            guard !layers.isEmpty, loopLengthFrames > 0, let format = loopFormat else { return nil }

            // Create output buffer
            guard let mixBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: loopLengthFrames) else { return nil }
            mixBuffer.frameLength = loopLengthFrames

            // Zero fill
            if let dst = mixBuffer.floatChannelData {
                for ch in 0..<Int(format.channelCount) {
                    memset(dst[ch], 0, Int(loopLengthFrames) * MemoryLayout<Float>.size)
                }
            }

            // Mix all audible layers
            for (i, layer) in layers.enumerated() {
                guard _isLayerAudible(index: i) else { continue }
                let srcBuffer = layer.buffer
                guard let srcData = srcBuffer.floatChannelData, let dstData = mixBuffer.floatChannelData else { continue }
                let framesToMix = min(Int(srcBuffer.frameLength), Int(loopLengthFrames))
                for ch in 0..<Int(format.channelCount) {
                    let src = srcData[ch]
                    let dst = dstData[ch]
                    for f in 0..<framesToMix {
                        dst[f] += src[f] * layer.volume
                    }
                }
            }

            // Write to WAV file
            let tempDir = FileManager.default.temporaryDirectory
            let outFile = tempDir.appendingPathComponent("loop_mixdown_\(UUID().uuidString).wav")

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
                try file.write(from: mixBuffer)
                return outFile.path
            } catch {
                print("LoopRecordingEngine: Export mixdown failed: \(error)")
                return nil
            }
        }
    }

    func exportStems() -> [[String: Any]] {
        return queue.sync {
            guard !layers.isEmpty, let format = loopFormat else { return [] }

            var results: [[String: Any]] = []
            let tempDir = FileManager.default.temporaryDirectory

            for (i, layer) in layers.enumerated() {
                let outFile = tempDir.appendingPathComponent("loop_stem_\(i)_\(UUID().uuidString).wav")
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
                    try file.write(from: layer.buffer)
                    results.append([
                        "index": i,
                        "name": layer.name,
                        "path": outFile.path,
                        "duration": Double(layer.buffer.frameLength) / format.sampleRate,
                    ])
                } catch {
                    print("LoopRecordingEngine: Export stem \(i) failed: \(error)")
                }
            }

            return results
        }
    }

    func exportSelectedLayers(indices: [Int]) -> String? {
        return queue.sync {
            guard !layers.isEmpty, loopLengthFrames > 0, let format = loopFormat else { return nil }

            guard let mixBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: loopLengthFrames) else { return nil }
            mixBuffer.frameLength = loopLengthFrames

            if let dst = mixBuffer.floatChannelData {
                for ch in 0..<Int(format.channelCount) {
                    memset(dst[ch], 0, Int(loopLengthFrames) * MemoryLayout<Float>.size)
                }
            }

            for i in indices {
                guard i >= 0, i < layers.count else { continue }
                let layer = layers[i]
                guard let srcData = layer.buffer.floatChannelData, let dstData = mixBuffer.floatChannelData else { continue }
                let framesToMix = min(Int(layer.buffer.frameLength), Int(loopLengthFrames))
                for ch in 0..<Int(format.channelCount) {
                    let src = srcData[ch]
                    let dst = dstData[ch]
                    for f in 0..<framesToMix {
                        dst[f] += src[f] * layer.volume
                    }
                }
            }

            let tempDir = FileManager.default.temporaryDirectory
            let outFile = tempDir.appendingPathComponent("loop_selected_\(UUID().uuidString).wav")
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
                try file.write(from: mixBuffer)
                return outFile.path
            } catch {
                print("LoopRecordingEngine: Export selected layers failed: \(error)")
                return nil
            }
        }
    }

    // MARK: - Beat Info

    func getBeatInfo() -> [String: Int] {
        return queue.sync {
            guard loopLengthFrames > 0, let startTime = playbackStartTime else {
                return ["currentBeat": 0, "totalBeats": 0]
            }
            let elapsed = Date().timeIntervalSince(startTime)
            let loopDuration = Double(loopLengthFrames) / loopSampleRate
            guard loopDuration > 0 else {
                return ["currentBeat": 0, "totalBeats": 0]
            }
            let posInLoop = elapsed.truncatingRemainder(dividingBy: loopDuration)
            // Assume 4/4 at whatever BPM the metronome is using
            // For now use a simple division of the loop into beats
            let totalBeats = max(1, Int(loopDuration * 2)) // approx 120bpm
            let currentBeat = Int(posInLoop / loopDuration * Double(totalBeats))
            return ["currentBeat": currentBeat, "totalBeats": totalBeats]
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

    // MARK: - Private: Recording

    private func _handleRecordingBuffer(_ buffer: AVAudioPCMBuffer) {
        // Send input level event on main thread (outside queue.sync to avoid deadlock)
        DispatchQueue.main.async { [weak self] in
            self?._sendInputLevelEvent(buffer)
        }

        queue.sync {
            guard let recBuffer = recordingBuffer, let format = loopFormat else { return }

            let remaining = recBuffer.frameCapacity - recordingBufferFramePosition
            if remaining == 0 { return }
            let framesToCopy = min(buffer.frameLength, remaining)

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
                DispatchQueue.main.async { [weak self] in
                    let result = self?.stopRecording()
                    // Send overdub auto-stop event
                    if let result = result, result["success"] as? Bool == true {
                        let event: [String: Any] = [
                            "type": "overdubAutoStop",
                            "layerCount": result["layerCount"] ?? 0,
                            "duration": result["duration"] ?? 0.0,
                        ]
                        self?.onEvent?(event)
                    }
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
            if _isLayerAudible(index: i) {
                player.scheduleBuffer(layers[i].buffer, at: nil, options: [], completionHandler: nil)
                player.play()
            }
        }
    }

    private func _scheduleLoopingPlayback() {
        for (i, player) in playerNodes.enumerated() {
            guard i < layers.count else { break }
            if _isLayerAudible(index: i) {
                player.scheduleBuffer(layers[i].buffer, at: nil, options: .loops, completionHandler: nil)
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
        for (i, player) in playerNodes.enumerated() {
            guard i < layers.count else { break }
            let layer = layers[i]
            let audible = _isLayerAudible(index: i)
            player.volume = audible ? layer.volume : 0.0
            player.pan = layer.pan
        }
    }

    private func _isLayerAudible(index: Int) -> Bool {
        guard index >= 0, index < layers.count else { return false }
        let layer = layers[index]
        if layer.isMuted { return false }
        let hasSolo = layers.contains { $0.isSolo }
        if hasSolo && !layer.isSolo { return false }
        return true
    }

    // MARK: - Private: Position Tracking

    private var positionTimer: Timer?
    private var playbackStartTime: Date?

    private func _startPositionTimer() {
        _stopPositionTimer()
        playbackStartTime = Date()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?._sendPositionEvent()
        }
    }

    private func _stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
        playbackStartTime = nil
    }

    private func _sendPositionEvent() {
        guard loopLengthFrames > 0, let startTime = playbackStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let loopDuration = Double(loopLengthFrames) / loopSampleRate
        guard loopDuration > 0 else { return }
        let position = elapsed.truncatingRemainder(dividingBy: loopDuration) / loopDuration
        let info: [String: Any] = [
            "type": "loopPosition",
            "position": position,
        ]
        onEvent?(info)
    }

    private func _sendInputLevelEvent(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        var sum: Float = 0
        let ptr = data[0]
        for i in 0..<frames {
            sum += abs(ptr[i])
        }
        let avgLevel = sum / Float(frames)
        // Normalize to 0-1 range (amplify for UI visibility)
        let level = min(1.0, Double(avgLevel) * 5.0)
        let info: [String: Any] = [
            "type": "inputLevel",
            "level": level,
        ]
        onEvent?(info)
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
