import AVFoundation

/// High-precision metronome engine for macOS using AVAudioEngine.
/// Port of the iOS MetronomeEngine — no AVAudioSession or haptics on macOS.
final class MetronomeEngine {
    // MARK: - Audio Graph
    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    // MARK: - Timing State (all atomic via queue)
    private let audioQueue = DispatchQueue(label: "com.groovelab.metronome", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var isRunning = false

    // Metronome parameters
    private var bpm: Int = 120
    private var beatsPerBar: Int = 4
    private var beatUnit: Int = 4
    private var subdivision: Int = 1
    private var swingPercent: Int = 0
    private var clickSound: String = "Wood"
    private var accentPattern: [Double] = [1.0, 0.7, 0.7, 0.7]
    private var humanFeel: Int = 0
    private var polyrhythmEnabled: Bool = false
    private var polyrhythmValue: Int = 3

    // Drum mode
    private var isDrumMode = false
    private var drumPattern: [String: [Int]] = [:]
    private var drumVolumes: [String: Double] = ["kick": 1.0, "snare": 1.0, "hihat": 1.0, "ride": 1.0]

    // Scheduling state
    private var nextBeatTime: AVAudioTime?
    private var currentSubBeat: Int = 0
    private var currentMeasure: Int = 0
    private var sampleRate: Double = 44100.0

    // Lookahead: schedule 30ms ahead, check every 10ms
    private let lookAheadMs: Double = 30.0
    private let timerIntervalMs: Double = 10.0

    // Callback to send events to Flutter
    private let onEvent: ([String: Any]) -> Void

    // Pool of player nodes for polyphonic playback
    private let playerPoolSize = 8
    private var playerPool: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0

    init(onEvent: @escaping ([String: Any]) -> Void) {
        self.onEvent = onEvent
    }

    // MARK: - Initialization

    func initialize() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)

        // On macOS, get sample rate from the output node
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if sampleRate == 0 { sampleRate = 44100.0 }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

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
            print("AVAudioEngine start error: \(error)")
        }

        self.audioEngine = engine
        self.mixerNode = mixer
    }

    // MARK: - Sound Loading

    func loadSound(key: String, wavData: Data) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        guard wavData.count > 44 else { return }
        let pcmData = wavData.subdata(in: 44..<wavData.count)
        let sampleCount = pcmData.count / 2

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(sampleCount)

        let floatData = buffer.floatChannelData![0]
        pcmData.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
            let int16Ptr = rawPtr.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                floatData[i] = Float(int16Ptr[i]) / 32768.0
            }
        }

        buffers[key] = buffer
    }

    // MARK: - Metronome Start/Stop

    func start(
        bpm: Int, beatsPerBar: Int, beatUnit: Int, subdivision: Int,
        swingPercent: Int, clickSound: String, accentPattern: [Double],
        hapticEnabled: Bool
    ) {
        audioQueue.async { [self] in
            stop_internal()
            self.bpm = bpm
            self.beatsPerBar = beatsPerBar
            self.beatUnit = beatUnit
            self.subdivision = subdivision
            self.swingPercent = swingPercent
            self.clickSound = clickSound
            self.accentPattern = accentPattern
            self.isDrumMode = false
            self.currentSubBeat = 0
            self.currentMeasure = 0

            guard let engine = audioEngine, engine.isRunning else { return }
            for player in playerPool { if !player.isPlaying { player.play() } }

            let hostNow = mach_absolute_time()
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)
            let nsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
            let offsetNs = UInt64(lookAheadMs * 1_000_000)
            nextBeatTime = AVAudioTime(hostTime: hostNow + UInt64(Double(offsetNs) / nsPerTick))

            isRunning = true
            startTimer()
        }
    }

    func startDrumPattern(bpm: Int, pattern: [String: [Int]], swingPercent: Int) {
        audioQueue.async { [self] in
            stop_internal()
            self.bpm = bpm
            self.beatsPerBar = 4
            self.beatUnit = 4
            self.subdivision = 4
            self.swingPercent = swingPercent
            self.drumPattern = pattern
            self.isDrumMode = true
            self.currentSubBeat = 0
            self.currentMeasure = 0

            guard let engine = audioEngine, engine.isRunning else { return }
            for player in playerPool { if !player.isPlaying { player.play() } }

            let hostNow = mach_absolute_time()
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)
            let nsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
            let offsetNs = UInt64(lookAheadMs * 1_000_000)
            nextBeatTime = AVAudioTime(hostTime: hostNow + UInt64(Double(offsetNs) / nsPerTick))

            isRunning = true
            startTimer()
        }
    }

    func stop() {
        audioQueue.async { [self] in stop_internal() }
    }

    private func stop_internal() {
        isRunning = false
        timer?.cancel()
        timer = nil
        for player in playerPool { player.stop() }
    }

    // MARK: - Timer / Scheduler

    private func startTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: audioQueue)
        let intervalNs = UInt64(timerIntervalMs * 1_000_000)
        t.schedule(deadline: .now(), repeating: .nanoseconds(Int(intervalNs)), leeway: .nanoseconds(0))
        t.setEventHandler { [weak self] in self?.schedulerTick() }
        t.resume()
        timer = t
    }

    private func schedulerTick() {
        guard isRunning, let engine = audioEngine, engine.isRunning else { return }

        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        let nsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
        let now = mach_absolute_time()
        let nowNs = Double(now) * nsPerTick
        let lookAheadNs = lookAheadMs * 1_000_000

        while isRunning {
            guard let beatTime = nextBeatTime else { break }
            let beatNs = Double(beatTime.hostTime) * nsPerTick
            if beatNs > nowNs + lookAheadNs { break }

            if isDrumMode {
                scheduleDrumStep(at: beatTime)
            } else {
                scheduleMetronomeClick(at: beatTime)
            }
            advanceToNextBeat(nsPerTick: nsPerTick)
        }
    }

    private func scheduleMetronomeClick(at time: AVAudioTime) {
        let totalSubBeats = beatsPerBar * subdivision
        let subBeatInBar = currentSubBeat % totalSubBeats
        let isMainBeat = subBeatInBar % subdivision == 0
        let mainBeatIndex = subBeatInBar / subdivision

        if isMainBeat {
            let vol = mainBeatIndex < accentPattern.count ? accentPattern[mainBeatIndex] : 0.7
            if vol > 0 {
                let isAccent = vol >= 0.9
                let soundKey = getSoundKey(clickSound: clickSound, isAccent: isAccent)
                scheduleBuffer(key: soundKey, at: time)
            }

            var info = mach_timebase_info_data_t()
            mach_timebase_info(&info)
            let tsUs = Int(Double(time.hostTime) * Double(info.numer) / Double(info.denom) / 1000)
            onEvent([
                "type": "beat",
                "beatIndex": mainBeatIndex,
                "measureIndex": currentMeasure,
                "isAccent": mainBeatIndex == 0,
                "timestampUs": tsUs,
            ])
        } else if subdivision > 1 {
            scheduleBuffer(key: "click_sub", at: time)
        }

        if polyrhythmEnabled && !isDrumMode && isMainBeat {
            let totalBeats = beatsPerBar
            let polyN = polyrhythmValue
            let lcmVal = lcm(totalBeats, polyN)
            let polyStep = lcmVal / polyN
            let mainStep = lcmVal / totalBeats
            let currentPos = mainBeatIndex * mainStep
            if currentPos % polyStep == 0 {
                scheduleBuffer(key: "click_ghost", at: time, volume: 0.4)
            }
        }
    }

    private func scheduleDrumStep(at time: AVAudioTime) {
        let step = currentSubBeat % 16
        for track in ["kick", "snare", "hihat", "ride"] {
            guard let pattern = drumPattern[track], step < pattern.count, pattern[step] == 1 else { continue }
            let vol = drumVolumes[track] ?? 1.0
            if vol > 0.01 { scheduleBuffer(key: track, at: time, volume: Float(vol)) }
        }

        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let tsUs = Int(Double(time.hostTime) * Double(info.numer) / Double(info.denom) / 1000)
        onEvent(["type": "drumStep", "step": step, "measureIndex": currentMeasure, "timestampUs": tsUs])
    }

    private func scheduleBuffer(key: String, at time: AVAudioTime, volume: Float = 1.0) {
        guard let buffer = buffers[key] else { return }
        let player = playerPool[nextPlayerIndex % playerPoolSize]
        nextPlayerIndex += 1
        if !player.isPlaying { player.play() }
        player.volume = volume
        player.scheduleBuffer(buffer, at: time, options: [], completionHandler: nil)
    }

    private func advanceToNextBeat(nsPerTick: Double) {
        let totalSubBeats = isDrumMode ? 16 : (beatsPerBar * subdivision)
        currentSubBeat += 1
        if currentSubBeat % totalSubBeats == 0 { currentMeasure += 1 }

        let baseIntervalSec: Double
        if isDrumMode {
            baseIntervalSec = 60.0 / Double(bpm) / 4.0
        } else {
            baseIntervalSec = 60.0 / Double(bpm) / Double(subdivision)
        }

        var intervalNs = baseIntervalSec * 1_000_000_000

        if swingPercent > 0 && subdivision >= 2 {
            let swingRatio = 0.5 + Double(swingPercent) / 200.0
            let pairInterval = baseIntervalSec * 2.0
            let isEvenSubBeat = (currentSubBeat - 1) % 2 == 0
            intervalNs = (isEvenSubBeat ? pairInterval * swingRatio : pairInterval * (1.0 - swingRatio)) * 1_000_000_000
        }

        if humanFeel > 0 && !isDrumMode {
            let maxJitterFraction = Double(humanFeel) / 100.0 * 0.08
            let jitter = Double.random(in: -1.0...1.0) * maxJitterFraction * intervalNs
            intervalNs += jitter
            intervalNs = max(intervalNs * 0.85, intervalNs)
        }

        guard let prev = nextBeatTime else { return }
        let advanceTicks = UInt64(intervalNs / nsPerTick)
        nextBeatTime = AVAudioTime(hostTime: prev.hostTime + advanceTicks)
    }

    private func getSoundKey(clickSound: String, isAccent: Bool) -> String {
        switch clickSound {
        case "Wood": return isAccent ? "click_accent" : "click_normal"
        case "Digital": return isAccent ? "digital_accent" : "digital_normal"
        case "Hi-Hat": return "hihat_click"
        case "Clave": return isAccent ? "clave_accent" : "clave_normal"
        case "Cowbell": return isAccent ? "cowbell_accent" : "cowbell_normal"
        case "Beep": return isAccent ? "beep_accent" : "beep_normal"
        default: return isAccent ? "click_accent" : "click_normal"
        }
    }

    // MARK: - Live Updates
    func updateBpm(_ newBpm: Int) { audioQueue.async { self.bpm = newBpm } }
    func updateTimeSignature(beatsPerBar: Int, beatUnit: Int) {
        audioQueue.async {
            self.beatsPerBar = beatsPerBar
            self.beatUnit = beatUnit
            if self.accentPattern.count != beatsPerBar {
                var newAccents = Array(repeating: 0.7, count: beatsPerBar)
                newAccents[0] = 1.0
                self.accentPattern = newAccents
            }
        }
    }
    func updateSubdivision(_ sub: Int) { audioQueue.async { self.subdivision = sub } }
    func updateSwing(_ pct: Int) { audioQueue.async { self.swingPercent = pct } }
    func updateClickSound(_ sound: String) { audioQueue.async { self.clickSound = sound } }
    func updateAccentPattern(_ pattern: [Double]) { audioQueue.async { self.accentPattern = pattern } }
    func setHapticMode(_ enabled: Bool) { /* No haptics on macOS */ }
    func updateHumanFeel(_ percent: Int) { audioQueue.async { self.humanFeel = min(50, max(0, percent)) } }
    func updatePolyrhythm(enabled: Bool, value: Int) {
        audioQueue.async { self.polyrhythmEnabled = enabled; self.polyrhythmValue = max(2, min(7, value)) }
    }
    func updateDrumPattern(_ pattern: [String: [Int]]) { audioQueue.async { self.drumPattern = pattern } }
    func updateDrumVolumes(_ volumes: [String: Double]) { audioQueue.async { self.drumVolumes = volumes } }

    private func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    private func lcm(_ a: Int, _ b: Int) -> Int { a / gcd(a, b) * b }

    func getOutputLatency() -> Double {
        // macOS: estimate from audio engine
        return (audioEngine?.outputNode.presentationLatency ?? 0) * 1000.0
    }
}
