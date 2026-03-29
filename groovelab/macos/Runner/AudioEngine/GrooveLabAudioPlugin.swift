import FlutterMacOS
import AVFoundation

/// Flutter plugin registration for the native audio engine on macOS.
public class GrooveLabAudioPlugin: NSObject, FlutterPlugin {
    private var metronomeEngine: MetronomeEngine?
    private var recordingEngine: RecordingEngine?
    private var pedaleraEngine: PedaleraEngine?
    private var loopEngine: LoopRecordingEngine?
    private var songLabEngine: SongLabEngine?
    private var padEngine: PadEngine?
    private var tunerEngine: TunerEngine?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.groovelab/audio_engine",
            binaryMessenger: registrar.messenger
        )
        let eventChannel = FlutterEventChannel(
            name: "com.groovelab/audio_events",
            binaryMessenger: registrar.messenger
        )

        let instance = GrooveLabAudioPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "init":
            initEngine(result: result)
        case "loadSound":
            guard let key = args?["key"] as? String,
                  let data = args?["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing key or data", details: nil))
                return
            }
            metronomeEngine?.loadSound(key: key, wavData: Data(data.data))
            result(nil)
        case "startMetronome":
            startMetronome(args: args, result: result)
        case "stopMetronome":
            metronomeEngine?.stop()
            result(nil)
        case "updateBpm":
            if let bpm = args?["bpm"] as? Int { metronomeEngine?.updateBpm(bpm) }
            result(nil)
        case "updateTimeSignature":
            if let beats = args?["beatsPerBar"] as? Int, let unit = args?["beatUnit"] as? Int {
                metronomeEngine?.updateTimeSignature(beatsPerBar: beats, beatUnit: unit)
            }
            result(nil)
        case "updateSubdivision":
            if let sub = args?["subdivision"] as? Int { metronomeEngine?.updateSubdivision(sub) }
            result(nil)
        case "updateSwing":
            if let pct = args?["swingPercent"] as? Int { metronomeEngine?.updateSwing(pct) }
            result(nil)
        case "updateClickSound":
            if let sound = args?["clickSound"] as? String { metronomeEngine?.updateClickSound(sound) }
            result(nil)
        case "updateAccentPattern":
            if let pattern = args?["pattern"] as? [Double] { metronomeEngine?.updateAccentPattern(pattern) }
            result(nil)
        case "setHapticMode":
            // No haptics on macOS
            result(nil)
        case "updateHumanFeel":
            if let pct = args?["percent"] as? Int { metronomeEngine?.updateHumanFeel(pct) }
            result(nil)
        case "updatePolyrhythm":
            let enabled = args?["enabled"] as? Bool ?? false
            let value = args?["value"] as? Int ?? 3
            metronomeEngine?.updatePolyrhythm(enabled: enabled, value: value)
            result(nil)
        case "startDrumPattern":
            startDrumPattern(args: args, result: result)
        case "stopDrumPattern":
            metronomeEngine?.stop()
            result(nil)
        case "updateDrumPattern":
            if let pattern = args?["pattern"] as? [String: [Int]] { metronomeEngine?.updateDrumPattern(pattern) }
            result(nil)
        case "updateDrumVolumes":
            if let volumes = args?["volumes"] as? [String: Double] { metronomeEngine?.updateDrumVolumes(volumes) }
            result(nil)
        case "startRecording":
            recordingEngine?.startRecording()
            result(nil)
        case "stopRecording":
            let path = recordingEngine?.stopRecording()
            result(path)
        case "enableOnsetDetection":
            let threshold = args?["threshold"] as? Double ?? 0.1
            let minInterval = args?["minIntervalMs"] as? Int ?? 50
            recordingEngine?.enableOnsetDetection(threshold: threshold, minIntervalMs: minInterval)
            result(nil)
        case "disableOnsetDetection":
            recordingEngine?.disableOnsetDetection()
            result(nil)
        case "getOutputLatency":
            let latency = metronomeEngine?.getOutputLatency() ?? 0
            result(latency)
        case "getInputLatency":
            let latency = recordingEngine?.getInputLatency() ?? 0
            result(latency)
        case "initPedalera":
            if pedaleraEngine == nil {
                pedaleraEngine = PedaleraEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
                pedaleraEngine?.initialize()
            }
            result(nil)
        case "setPedalChain":
            if let chainConfig = args?["chain"] as? [[String: Any]] { pedaleraEngine?.setChain(chainConfig) }
            result(nil)
        case "setPedalParam":
            if let idx = args?["index"] as? Int, let name = args?["param"] as? String, let val = args?["value"] as? Double {
                pedaleraEngine?.setParam(pedalIndex: idx, paramName: name, value: val)
            }
            result(nil)
        case "setPedalBypass":
            if let idx = args?["index"] as? Int, let bypassed = args?["bypassed"] as? Bool {
                pedaleraEngine?.setBypass(pedalIndex: idx, bypassed: bypassed)
            }
            result(nil)
        case "stopPedalera":
            pedaleraEngine?.stop(); pedaleraEngine = nil; result(nil)
        case "getPedalLatency":
            result(pedaleraEngine?.getLatency() ?? 0.0)
        // ── Loop Station ──
        case "startLoopRecording":
            if loopEngine == nil {
                loopEngine = LoopRecordingEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
                loopEngine?.initialize()
            }
            let status = loopEngine?.startRecording() ?? "error"
            result(status)
        case "stopLoopRecording":
            let info = loopEngine?.stopRecording() ?? ["success": false, "layerCount": 0]
            // Auto-start playback after recording completes
            if info["success"] as? Bool == true {
                loopEngine?.startPlayback()
            }
            result(info)
        case "startLoopPlayback":
            loopEngine?.startPlayback()
            result(nil)
        case "stopLoopPlayback":
            loopEngine?.stopPlayback()
            result(nil)
        case "undoLoopLayer":
            loopEngine?.undoLayer()
            result(nil)
        case "clearLoop":
            loopEngine?.clearLoop()
            result(nil)
        case "setLoopLayerVolume":
            if let idx = args?["index"] as? Int, let vol = args?["volume"] as? Double {
                loopEngine?.setLayerVolume(index: idx, volume: vol)
            }
            result(nil)
        case "setLayerMute":
            if let idx = args?["index"] as? Int, let muted = args?["muted"] as? Bool {
                loopEngine?.setLayerMute(index: idx, muted: muted)
            }
            result(nil)
        case "setLayerSolo":
            if let idx = args?["index"] as? Int, let solo = args?["solo"] as? Bool {
                loopEngine?.setLayerSolo(index: idx, solo: solo)
            }
            result(nil)
        case "setLayerPan":
            if let idx = args?["index"] as? Int, let pan = args?["pan"] as? Double {
                loopEngine?.setLayerPan(index: idx, pan: pan)
            }
            result(nil)
        case "deleteLoopLayer":
            if let idx = args?["index"] as? Int { loopEngine?.deleteLayer(index: idx) }
            result(nil)
        case "renameLoopLayer":
            if let idx = args?["index"] as? Int, let name = args?["name"] as? String {
                loopEngine?.renameLayer(index: idx, name: name)
            }
            result(nil)
        case "getLoopState":
            result(loopEngine?.getState() ?? ["state": "idle", "layerCount": 0])
        case "getLayerWaveform":
            let index = args?["index"] as? Int ?? 0
            let numSamples = args?["numSamples"] as? Int ?? 80
            let waveform = loopEngine?.getLayerWaveform(index: index, numSamples: numSamples) ?? []
            result(waveform)

        // ── Song Lab ──
        case "songLabLoadTrack":
            guard let data = args?["data"] as? FlutterStandardTypedData,
                  let name = args?["name"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing data or name", details: nil))
                return
            }
            if songLabEngine == nil {
                songLabEngine = SongLabEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
            }
            let info = songLabEngine!.loadTrack(audioData: Data(data.data), name: name)
            result(info)
        case "songLabPlay":
            songLabEngine?.play()
            result(nil)
        case "songLabPause":
            songLabEngine?.pause()
            result(nil)
        case "songLabStop":
            songLabEngine?.stop()
            result(nil)
        case "songLabSeek":
            if let position = args?["position"] as? Double {
                songLabEngine?.seek(position: position)
            }
            result(nil)
        case "songLabSetTrackVolume":
            if let vol = args?["volume"] as? Double {
                songLabEngine?.setVolume(vol)
            }
            result(nil)
        case "songLabSetSpeed":
            if let speed = args?["speed"] as? Double {
                songLabEngine?.setSpeed(speed)
            }
            result(nil)
        case "songLabClearAll":
            songLabEngine?.clearAll()
            songLabEngine = nil
            result(nil)
        case "songLabGetWaveform":
            let numSamples = args?["numSamples"] as? Int ?? 200
            let waveform = songLabEngine?.getWaveform(numSamples: numSamples) ?? []
            result(waveform)

        // ── Pad Engine ──
        case "loadPadSound":
            guard let key = args?["key"] as? String,
                  let data = args?["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing key or data", details: nil))
                return
            }
            if padEngine == nil {
                padEngine = PadEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
                padEngine?.initialize()
            }
            padEngine?.loadPadSound(key: key, wavData: Data(data.data))
            result(nil)
        case "playPad":
            if let key = args?["key"] as? String {
                padEngine?.playPad(key: key)
            }
            result(nil)
        case "stopPad":
            if let key = args?["key"] as? String {
                padEngine?.stopPad(key: key)
            }
            result(nil)
        case "stopAllPads":
            padEngine?.stopAllPads()
            result(nil)
        case "setPadVolume":
            if let key = args?["key"] as? String, let vol = args?["volume"] as? Double {
                padEngine?.setPadVolume(key: key, volume: vol)
            }
            result(nil)
        case "setPadPan":
            if let key = args?["key"] as? String, let pan = args?["pan"] as? Double {
                padEngine?.setPadPan(key: key, pan: pan)
            }
            result(nil)
        case "setPadMasterVolume":
            if let vol = args?["volume"] as? Double {
                padEngine?.setMasterVolume(vol)
            }
            result(nil)
        case "crossfadeToPad":
            if let fromKey = args?["fromKey"] as? String,
               let toKey = args?["toKey"] as? String,
               let duration = args?["duration"] as? Double {
                padEngine?.crossfade(fromKey: fromKey, toKey: toKey, duration: duration)
            }
            result(nil)

        // ── Metronome enhancements ──
        case "updateCountIn":
            if let bars = args?["bars"] as? Int { metronomeEngine?.updateCountIn(bars: bars) }
            result(nil)
        case "updateIntervalTraining":
            let enabled = args?["enabled"] as? Bool ?? false
            let clickBars = args?["clickBars"] as? Int ?? 4
            let silentBars = args?["silentBars"] as? Int ?? 2
            metronomeEngine?.updateIntervalTraining(enabled: enabled, clickBars: clickBars, silentBars: silentBars)
            result(nil)
        case "updateRandomSilence":
            let enabled = args?["enabled"] as? Bool ?? false
            let probability = args?["probability"] as? Int ?? 0
            metronomeEngine?.updateRandomSilence(enabled: enabled, probability: probability)
            result(nil)
        case "updateDrumTimeSig":
            if let beats = args?["beats"] as? Int, let unit = args?["beatUnit"] as? Int {
                metronomeEngine?.updateDrumTimeSig(beats: beats, beatUnit: unit)
            }
            result(nil)
        case "updateDrumAccentPattern":
            if let pattern = args?["pattern"] as? [Double] { metronomeEngine?.updateDrumAccentPattern(pattern) }
            result(nil)
        case "setGuideVolume":
            if let vol = args?["volume"] as? Double { metronomeEngine?.setMetronomeVolume(vol) }
            result(nil)
        case "muteGuide":
            if let muted = args?["muted"] as? Bool { metronomeEngine?.setMetronomeMuted(muted) }
            result(nil)

        // ── Loop Station enhancements ──
        case "startInputMonitoring":
            if loopEngine == nil {
                loopEngine = LoopRecordingEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
                loopEngine?.initialize()
            }
            loopEngine?.startInputMonitoring()
            result(nil)
        case "stopInputMonitoring":
            loopEngine?.stopInputMonitoring()
            result(nil)
        case "setMonitorVolume":
            if let vol = args?["volume"] as? Double { loopEngine?.setMonitorVolume(volume: vol) }
            result(nil)
        case "setLoopMasterVolume":
            if let vol = args?["volume"] as? Double { loopEngine?.setMasterVolume(volume: vol) }
            result(nil)
        case "exportLoopMixdown":
            let path = loopEngine?.exportMixdown()
            result(path)
        case "exportStems":
            let stems = loopEngine?.exportStems() ?? []
            result(stems)
        case "exportSelectedLayers":
            if let indices = args?["indices"] as? [Int] {
                let path = loopEngine?.exportSelectedLayers(indices: indices)
                result(path)
            } else {
                result(nil)
            }
        case "startInputLevelMeter":
            if loopEngine == nil {
                loopEngine = LoopRecordingEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
                loopEngine?.initialize()
            }
            loopEngine?.startInputLevelMeter()
            result(nil)
        case "stopInputLevelMeter":
            loopEngine?.stopInputLevelMeter()
            result(nil)
        case "getAudioInputDevices":
            let devices = _getAudioInputDevices()
            result(devices)
        case "getLoopBeatInfo":
            let info = loopEngine?.getBeatInfo() ?? ["currentBeat": 0, "totalBeats": 0]
            result(info)

        // ── Song Lab enhancements ──
        case "songLabSetTrackPan":
            if let pan = args?["pan"] as? Double {
                songLabEngine?.setPan(pan)
            }
            result(nil)
        case "songLabSetTrackMute":
            if let muted = args?["muted"] as? Bool {
                songLabEngine?.setMuted(muted)
            }
            result(nil)
        case "songLabSetTrackSolo":
            if let solo = args?["solo"] as? Bool {
                songLabEngine?.setSolo(solo)
            }
            result(nil)
        case "songLabSetPitchShift":
            if let semitones = args?["semitones"] as? Int {
                songLabEngine?.setPitchShift(semitones: Double(semitones))
            }
            result(nil)
        case "songLabSetLoopRegion":
            if let start = args?["start"] as? Double, let end = args?["end"] as? Double {
                songLabEngine?.setLoopRegion(startTime: start, endTime: end)
            }
            result(nil)
        case "songLabClearLoopRegion":
            songLabEngine?.clearLoopRegion()
            result(nil)
        case "songLabGetState":
            let state = songLabEngine?.getState() ?? [:]
            result(state)
        case "songLabExportMixdown":
            let path = songLabEngine?.exportMixdown()
            result(path)
        case "songLabMockSeparate":
            // Stem separation requires ML model — not available natively yet
            result(["error": "stem_separation_not_available"])

        // ── Tuner ──
        case "startTuner":
            if tunerEngine == nil {
                tunerEngine = TunerEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
            }
            tunerEngine?.start()
            result(nil)
        case "stopTuner":
            tunerEngine?.stop()
            result(nil)

        case "dispose":
            metronomeEngine?.stop()
            metronomeEngine = nil
            recordingEngine?.stopRecording()
            recordingEngine = nil
            pedaleraEngine?.stop()
            pedaleraEngine = nil
            loopEngine?.stop()
            loopEngine = nil
            songLabEngine?.clearAll()
            songLabEngine = nil
            padEngine?.dispose()
            padEngine = nil
            tunerEngine?.stop()
            tunerEngine = nil
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initEngine(result: FlutterResult) {
        metronomeEngine = MetronomeEngine { [weak self] event in
            DispatchQueue.main.async { self?.eventSink?(event) }
        }
        recordingEngine = RecordingEngine { [weak self] event in
            DispatchQueue.main.async { self?.eventSink?(event) }
        }
        metronomeEngine?.initialize()
        result(nil)
    }

    private func startMetronome(args: [String: Any]?, result: FlutterResult) {
        guard let bpm = args?["bpm"] as? Int,
              let beatsPerBar = args?["beatsPerBar"] as? Int,
              let beatUnit = args?["beatUnit"] as? Int else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing metronome params", details: nil))
            return
        }
        let subdivision = args?["subdivision"] as? Int ?? 1
        let swing = args?["swingPercent"] as? Int ?? 0
        let clickSound = args?["clickSound"] as? String ?? "Wood"
        let accents = args?["accentPattern"] as? [Double] ?? [1.0, 0.7, 0.7, 0.7]
        let haptic = args?["hapticEnabled"] as? Bool ?? false

        metronomeEngine?.start(
            bpm: bpm, beatsPerBar: beatsPerBar, beatUnit: beatUnit,
            subdivision: subdivision, swingPercent: swing, clickSound: clickSound,
            accentPattern: accents, hapticEnabled: haptic
        )
        result(nil)
    }

    private func _getAudioInputDevices() -> [[String: String]] {
        // On macOS, query available audio input devices via AVAudioEngine
        var devices: [[String: String]] = []
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // Add the default input device
        devices.append([
            "id": "default",
            "name": "Default Input",
            "sampleRate": "\(format.sampleRate)",
        ])
        return devices
    }

    private func startDrumPattern(args: [String: Any]?, result: FlutterResult) {
        guard let bpm = args?["bpm"] as? Int,
              let pattern = args?["pattern"] as? [String: [Int]] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing drum params", details: nil))
            return
        }
        let swing = args?["swingPercent"] as? Int ?? 0
        metronomeEngine?.startDrumPattern(bpm: bpm, pattern: pattern, swingPercent: swing)
        result(nil)
    }
}

// MARK: - FlutterStreamHandler
extension GrooveLabAudioPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
