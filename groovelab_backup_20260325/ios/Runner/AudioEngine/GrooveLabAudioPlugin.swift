import Flutter
import UIKit

/// Flutter plugin registration for the native audio engine.
public class GrooveLabAudioPlugin: NSObject, FlutterPlugin {
    private var metronomeEngine: MetronomeEngine?
    private var recordingEngine: RecordingEngine?
    private var pedaleraEngine: PedaleraEngine?
    private var midiEngine: MIDIEngine?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.groovelab/audio_engine",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.groovelab/audio_events",
            binaryMessenger: registrar.messenger()
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
        case "playSound":
            if let key = args?["key"] as? String {
                metronomeEngine?.playSingleHit(key: key)
            }
            result(nil)
        case "startMetronome":
            startMetronome(args: args, result: result)
        case "stopMetronome":
            metronomeEngine?.stop()
            result(nil)
        case "updateBpm":
            if let bpm = args?["bpm"] as? Int {
                metronomeEngine?.updateBpm(bpm)
            }
            result(nil)
        case "updateTimeSignature":
            if let beats = args?["beatsPerBar"] as? Int,
               let unit = args?["beatUnit"] as? Int {
                metronomeEngine?.updateTimeSignature(beatsPerBar: beats, beatUnit: unit)
            }
            result(nil)
        case "updateSubdivision":
            if let sub = args?["subdivision"] as? Int {
                metronomeEngine?.updateSubdivision(sub)
            }
            result(nil)
        case "updateSwing":
            if let pct = args?["swingPercent"] as? Int {
                metronomeEngine?.updateSwing(pct)
            }
            result(nil)
        case "updateClickSound":
            if let sound = args?["clickSound"] as? String {
                metronomeEngine?.updateClickSound(sound)
            }
            result(nil)
        case "updateAccentPattern":
            if let pattern = args?["pattern"] as? [Double] {
                metronomeEngine?.updateAccentPattern(pattern)
            }
            result(nil)
        case "setHapticMode":
            if let enabled = args?["enabled"] as? Bool {
                metronomeEngine?.setHapticMode(enabled)
            }
            result(nil)
        case "updateHumanFeel":
            if let pct = args?["percent"] as? Int {
                metronomeEngine?.updateHumanFeel(pct)
            }
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
            if let pattern = args?["pattern"] as? [String: [Int]] {
                metronomeEngine?.updateDrumPattern(pattern)
            }
            result(nil)
        case "updateDrumVolumes":
            if let volumes = args?["volumes"] as? [String: Double] {
                metronomeEngine?.updateDrumVolumes(volumes)
            }
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
        // ── Pedalera ──
        case "initPedalera":
            if pedaleraEngine == nil {
                pedaleraEngine = PedaleraEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
                pedaleraEngine?.initialize()
            }
            result(nil)
        case "setPedalChain":
            if let chainConfig = args?["chain"] as? [[String: Any]] {
                pedaleraEngine?.setChain(chainConfig)
            }
            result(nil)
        case "setPedalParam":
            if let idx = args?["index"] as? Int,
               let name = args?["param"] as? String,
               let val = args?["value"] as? Double {
                pedaleraEngine?.setParam(pedalIndex: idx, paramName: name, value: val)
            }
            result(nil)
        case "setPedalBypass":
            if let idx = args?["index"] as? Int,
               let bypassed = args?["bypassed"] as? Bool {
                pedaleraEngine?.setBypass(pedalIndex: idx, bypassed: bypassed)
            }
            result(nil)
        case "stopPedalera":
            pedaleraEngine?.stop()
            pedaleraEngine = nil
            result(nil)
        case "getPedalLatency":
            result(pedaleraEngine?.getLatency() ?? 0.0)

        // ── CoreMIDI ──
        case "initMidi":
            if midiEngine == nil {
                midiEngine = MIDIEngine { [weak self] event in
                    DispatchQueue.main.async { self?.eventSink?(event) }
                }
            }
            let success = midiEngine?.initialize() ?? false
            result(success)
        case "getMidiDevices":
            result(midiEngine?.listDevices() ?? [])
        case "sendMidiNoteOn":
            if let note = args?["note"] as? Int,
               let velocity = args?["velocity"] as? Int,
               let channel = args?["channel"] as? Int {
                midiEngine?.sendNoteOn(note: UInt8(note), velocity: UInt8(velocity), channel: UInt8(channel))
            }
            result(nil)
        case "sendMidiNoteOff":
            if let note = args?["note"] as? Int,
               let channel = args?["channel"] as? Int {
                midiEngine?.sendNoteOff(note: UInt8(note), channel: UInt8(channel))
            }
            result(nil)
        case "sendMidiCC":
            if let controller = args?["controller"] as? Int,
               let value = args?["value"] as? Int,
               let channel = args?["channel"] as? Int {
                midiEngine?.sendCC(controller: UInt8(controller), value: UInt8(value), channel: UInt8(channel))
            }
            result(nil)
        case "sendMidiProgramChange":
            if let program = args?["program"] as? Int,
               let channel = args?["channel"] as? Int {
                midiEngine?.sendProgramChange(program: UInt8(program), channel: UInt8(channel))
            }
            result(nil)
        case "startMidiClock":
            if let bpm = args?["bpm"] as? Double {
                midiEngine?.startClock(bpm: bpm)
            }
            result(nil)
        case "stopMidiClock":
            midiEngine?.stopClock()
            result(nil)
        case "updateMidiClockBpm":
            if let bpm = args?["bpm"] as? Double {
                midiEngine?.updateClockBpm(bpm)
            }
            result(nil)
        case "disconnectMidi":
            midiEngine?.dispose()
            midiEngine = nil
            result(nil)

        // ── Audio Session / Routing ──
        case "getAudioRoute":
            result(AudioSessionManager.shared.getCurrentRoute())
        case "getAvailableInputs":
            result(AudioSessionManager.shared.getAvailableInputs())
        case "setPreferredInput":
            if let uid = args?["uid"] as? String {
                result(AudioSessionManager.shared.setPreferredInput(uid))
            } else {
                result(false)
            }
        case "setBufferDuration":
            if let ms = args?["durationMs"] as? Double {
                AudioSessionManager.shared.setBufferDuration(ms)
            }
            result(nil)

        case "dispose":
            metronomeEngine?.stop()
            metronomeEngine = nil
            recordingEngine?.stopRecording()
            recordingEngine = nil
            pedaleraEngine?.stop()
            pedaleraEngine = nil
            midiEngine?.dispose()
            midiEngine = nil
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initEngine(result: FlutterResult) {
        // Configure audio session first
        AudioSessionManager.shared.configure { [weak self] event in
            DispatchQueue.main.async { self?.eventSink?(event) }
        }

        metronomeEngine = MetronomeEngine { [weak self] event in
            DispatchQueue.main.async {
                self?.eventSink?(event)
            }
        }
        recordingEngine = RecordingEngine { [weak self] event in
            DispatchQueue.main.async {
                self?.eventSink?(event)
            }
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
            bpm: bpm,
            beatsPerBar: beatsPerBar,
            beatUnit: beatUnit,
            subdivision: subdivision,
            swingPercent: swing,
            clickSound: clickSound,
            accentPattern: accents,
            hapticEnabled: haptic
        )
        result(nil)
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
