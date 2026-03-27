import AVFoundation
import UIKit

/// High-precision metronome engine using AVAudioEngine.
/// Scheduling uses AVAudioTime for sample-accurate playback.
/// Timer runs on a high-priority GCD queue with lookahead buffering.
final class MetronomeEngine {
    // MARK: - Audio Graph
    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var players: [String: AVAudioPlayerNode] = [:]
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    // MARK: - Timing State (all atomic via queue)
    private let audioQueue = DispatchQueue(label: "com.groovelab.metronome", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var isRunning = false

    // Metronome parameters (modified atomically on audioQueue)
    private var bpm: Int = 120
    private var beatsPerBar: Int = 4
    private var beatUnit: Int = 4
    private var subdivision: Int = 1
    private var swingPercent: Int = 0
    private var clickSound: String = "Wood"
    private var accentPattern: [Double] = [1.0, 0.7, 0.7, 0.7]
    private var hapticEnabled: Bool = false
    private var humanFeel: Int = 0 // 0-50, timing jitter percentage
    private var polyrhythmEnabled: Bool = false
    private var polyrhythmValue: Int = 3 // N in N:beatsPerBar

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

    // Haptic generators
    private var hapticImpact: UIImpactFeedbackGenerator?
    private var hapticHeavy: UIImpactFeedbackGenerator?

    // Callback to send events to Flutter
    private let onEvent: ([String: Any]) -> Void

    // Pool of player nodes for polyphonic playback
    private let playerPoolSize = 8
    private var playerPool: [AVAudioPlayerNode] = []
    /// Thread-safe player index — only accessed within audioQueue or via getNextPlayer()
    private var nextPlayerIndex = 0

    // Drift correction: track cumulative error over measures
    private var driftReferenceHostTime: UInt64 = 0
    private var driftReferenceBeatCount: Int = 0
    private var driftCorrectionEnabled = true

    init(onEvent: @escaping ([String: Any]) -> Void) {
        self.onEvent = onEvent
    }

    // MARK: - Initialization

    func initialize() {
        setupAudioSession()
        setupAudioEngine()
        setupHaptics()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Use playAndRecord for simultaneous playback + mic
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            // 10ms buffer: stable balance between latency and avoiding underruns
            // (5ms was too aggressive, causing glitches on older devices under CPU load)
            try session.setPreferredIOBufferDuration(0.010)
            // Use device's preferred sample rate instead of forcing 44.1kHz
            // This avoids unnecessary resampling overhead on 48kHz-native devices
            let deviceRate = session.preferredSampleRate
            if deviceRate > 0 {
                try session.setPreferredSampleRate(deviceRate)
            }
            try session.setActive(true)
            sampleRate = session.sampleRate
        } catch {
            print("AudioSession setup error: \(error)")
        }
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        // Create a pool of player nodes for overlapping sounds
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

    private func setupHaptics() {
        hapticImpact = UIImpactFeedbackGenerator(style: .medium)
        hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)
        hapticImpact?.prepare()
        hapticHeavy?.prepare()
    }

    // MARK: - Sound Loading

    func loadSound(key: String, wavData: Data) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

        // Validate WAV RIFF header before parsing
        guard wavData.count > 44 else {
            print("MetronomeEngine: WAV too short for '\(key)' (\(wavData.count) bytes)")
            return
        }

        // Verify RIFF chunk signature
        let riffHeader = wavData.prefix(4)
        guard String(data: riffHeader, encoding: .ascii) == "RIFF" else {
            print("MetronomeEngine: Invalid WAV header for '\(key)' — not RIFF")
            return
        }

        // Find data chunk offset (handles non-standard WAV with extra chunks)
        var dataOffset = 12 // skip RIFF header + format
        var dataSize = 0
        while dataOffset < wavData.count - 8 {
            let chunkId = String(data: wavData.subdata(in: dataOffset..<dataOffset+4), encoding: .ascii) ?? ""
            let chunkSize = wavData.subdata(in: dataOffset+4..<dataOffset+8).withUnsafeBytes {
                $0.load(as: UInt32.self)
            }
            if chunkId == "data" {
                dataOffset += 8
                dataSize = Int(chunkSize)
                break
            }
            dataOffset += 8 + Int(chunkSize)
            // Align to even byte boundary
            if dataOffset % 2 != 0 { dataOffset += 1 }
        }

        if dataSize <= 0 || dataOffset + dataSize > wavData.count {
            // Fallback to 44-byte header skip for simple WAVs
            dataOffset = 44
            dataSize = wavData.count - 44
        }
        guard dataSize > 0, dataOffset + dataSize <= wavData.count else { return }

        let pcmData = wavData.subdata(in: dataOffset..<dataOffset + dataSize)
        let sampleCount = pcmData.count / 2 // 16-bit = 2 bytes per sample
        guard sampleCount > 0 else { return }

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
        bpm: Int,
        beatsPerBar: Int,
        beatUnit: Int,
        subdivision: Int,
        swingPercent: Int,
        clickSound: String,
        accentPattern: [Double],
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
            self.hapticEnabled = hapticEnabled
            self.isDrumMode = false
            self.currentSubBeat = 0
            self.currentMeasure = 0

            guard let engine = audioEngine, engine.isRunning else { return }

            // Start all player nodes
            for player in playerPool {
                if !player.isPlaying {
                    player.play()
                }
            }

            // First beat starts NOW + small lookahead
            let now = AVAudioTime(hostTime: mach_absolute_time())
            let offsetSamples = AVAudioFramePosition(lookAheadMs / 1000.0 * sampleRate)
            nextBeatTime = AVAudioTime(
                sampleTime: (now.sampleTime) + offsetSamples,
                atRate: sampleRate
            )
            // Use host time for first beat
            let hostNow = mach_absolute_time()
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)
            let nsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
            let offsetNs = UInt64(lookAheadMs * 1_000_000)
            nextBeatTime = AVAudioTime(hostTime: hostNow + UInt64(Double(offsetNs) / nsPerTick))

            // Initialize drift correction reference
            driftReferenceHostTime = nextBeatTime!.hostTime
            driftReferenceBeatCount = 0

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
            self.subdivision = 4 // 16th notes for drum grid
            self.swingPercent = swingPercent
            self.drumPattern = pattern
            self.isDrumMode = true
            self.currentSubBeat = 0
            self.currentMeasure = 0

            guard let engine = audioEngine, engine.isRunning else { return }

            for player in playerPool {
                if !player.isPlaying { player.play() }
            }

            let hostNow = mach_absolute_time()
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)
            let nsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
            let offsetNs = UInt64(lookAheadMs * 1_000_000)
            nextBeatTime = AVAudioTime(hostTime: hostNow + UInt64(Double(offsetNs) / nsPerTick))

            // Initialize drift correction reference
            driftReferenceHostTime = nextBeatTime!.hostTime
            driftReferenceBeatCount = 0

            isRunning = true
            startTimer()
        }
    }

    func stop() {
        audioQueue.async { [self] in
            stop_internal()
        }
    }

    private func stop_internal() {
        isRunning = false
        timer?.cancel()
        timer = nil
        for player in playerPool {
            player.stop()
        }
    }

    // MARK: - Timer / Scheduler

    private func startTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: audioQueue)
        let intervalNs = UInt64(timerIntervalMs * 1_000_000)
        // 50µs leeway gives OS scheduling flexibility without affecting timing
        // (0ns leeway is unrealistic and can cause timer starvation under CPU load)
        t.schedule(deadline: .now(), repeating: .nanoseconds(Int(intervalNs)), leeway: .nanoseconds(50_000))
        t.setEventHandler { [weak self] in
            self?.schedulerTick()
        }
        t.resume()
        timer = t
    }

    /// Core scheduler: runs every ~10ms, schedules sounds up to 30ms ahead.
    private func schedulerTick() {
        guard isRunning, let engine = audioEngine, engine.isRunning else { return }

        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        let nsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)

        let now = mach_absolute_time()
        let nowNs = Double(now) * nsPerTick
        let lookAheadNs = lookAheadMs * 1_000_000

        // Schedule all beats that fall within the lookahead window
        while isRunning {
            guard let beatTime = nextBeatTime else { break }

            let beatNs = Double(beatTime.hostTime) * nsPerTick
            if beatNs > nowNs + lookAheadNs {
                break // This beat is too far in the future
            }

            // Schedule this beat's sounds
            if isDrumMode {
                scheduleDrumStep(at: beatTime)
            } else {
                scheduleMetronomeClick(at: beatTime)
            }

            // Advance to next sub-beat
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

                if hapticEnabled {
                    // Schedule haptic on main thread close to beat time
                    DispatchQueue.main.async { [weak self] in
                        if isAccent {
                            self?.hapticHeavy?.impactOccurred()
                        } else {
                            self?.hapticImpact?.impactOccurred()
                        }
                    }
                }
            }

            // Send beat event to Flutter
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

        // Polyrhythm: schedule ghost click if this sub-beat aligns with the polyrhythm grid
        if polyrhythmEnabled && !isDrumMode && isMainBeat {
            let totalBeats = beatsPerBar
            let polyN = polyrhythmValue
            // Check if this beat aligns with the polyrhythm (using LCM grid)
            let lcmVal = lcm(totalBeats, polyN)
            let polyStep = lcmVal / polyN
            let mainStep = lcmVal / totalBeats
            let currentPos = mainBeatIndex * mainStep
            // Check if a poly beat falls on this position (but not also a main beat)
            if currentPos % polyStep == 0 {
                // This position has both main and poly beat - play poly accent
                scheduleBuffer(key: "click_ghost", at: time, volume: 0.4)
            }
        }
    }

    private func scheduleDrumStep(at time: AVAudioTime) {
        let step = currentSubBeat % 16
        let trackNames = ["kick", "snare", "hihat", "ride"]

        for track in trackNames {
            guard let pattern = drumPattern[track],
                  step < pattern.count,
                  pattern[step] == 1 else { continue }
            let vol = drumVolumes[track] ?? 1.0
            if vol > 0.01 {
                scheduleBuffer(key: track, at: time, volume: Float(vol))
            }
        }

        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let tsUs = Int(Double(time.hostTime) * Double(info.numer) / Double(info.denom) / 1000)
        onEvent([
            "type": "drumStep",
            "step": step,
            "measureIndex": currentMeasure,
            "timestampUs": tsUs,
        ])
    }

    /// Thread-safe round-robin player allocation. MUST be called from audioQueue.
    private func getNextPlayer() -> AVAudioPlayerNode {
        let player = playerPool[nextPlayerIndex % playerPoolSize]
        nextPlayerIndex = (nextPlayerIndex + 1) % playerPoolSize
        return player
    }

    private func scheduleBuffer(key: String, at time: AVAudioTime, volume: Float = 1.0) {
        guard let buffer = buffers[key] else { return }

        // Thread-safe: getNextPlayer() only called from audioQueue (scheduler runs on audioQueue)
        let player = getNextPlayer()

        if !player.isPlaying {
            player.play()
        }

        player.volume = volume
        player.scheduleBuffer(buffer, at: time, options: [], completionHandler: nil)
    }

    /// Play a single sound hit immediately (for manual drum pad taps).
    func playSingleHit(key: String, volume: Float = 1.0) {
        audioQueue.async { [self] in
            guard let buffer = buffers[key] else { return }
            // Thread-safe: runs on audioQueue, same as scheduler
            let player = getNextPlayer()
            if !player.isPlaying { player.play() }
            player.volume = volume
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }

    private func advanceToNextBeat(nsPerTick: Double) {
        let totalSubBeats = isDrumMode ? 16 : (beatsPerBar * subdivision)
        currentSubBeat += 1

        // Check for measure boundary
        if currentSubBeat % totalSubBeats == 0 {
            currentMeasure += 1
        }

        // Calculate interval to next sub-beat in nanoseconds
        let baseIntervalSec: Double
        if isDrumMode {
            // 16th notes at current BPM (4 per beat)
            baseIntervalSec = 60.0 / Double(bpm) / 4.0
        } else {
            baseIntervalSec = 60.0 / Double(bpm) / Double(subdivision)
        }

        var intervalNs = baseIntervalSec * 1_000_000_000

        // Apply swing
        if swingPercent > 0 && subdivision >= 2 {
            let swingRatio = 0.5 + Double(swingPercent) / 200.0
            let pairInterval = baseIntervalSec * 2.0
            let isEvenSubBeat = (currentSubBeat - 1) % 2 == 0
            intervalNs = (isEvenSubBeat ? pairInterval * swingRatio : pairInterval * (1.0 - swingRatio)) * 1_000_000_000
        }

        // Apply human feel (timing jitter)
        if humanFeel > 0 && !isDrumMode {
            let maxJitterFraction = Double(humanFeel) / 100.0 * 0.08 // max ±4% of beat interval at 50%
            let jitter = (Double.random(in: -1.0...1.0)) * maxJitterFraction * intervalNs
            intervalNs += jitter
            // Prevent intervals from being too short (minimum 85% of base)
            intervalNs = max(baseIntervalSec * 0.85 * 1_000_000_000, intervalNs)
        }

        // Advance next beat time using host time
        guard let prev = nextBeatTime else { return }
        let advanceTicks = UInt64(intervalNs / nsPerTick)
        nextBeatTime = AVAudioTime(hostTime: prev.hostTime + advanceTicks)

        // ── Drift Correction ──
        // Every 4 measures, compare accumulated time against ideal.
        // This prevents long-session drift (>1hr) by re-anchoring timing.
        if driftCorrectionEnabled && currentSubBeat > 0 && currentMeasure > 0 && currentMeasure % 4 == 0 && currentSubBeat % totalSubBeats == 0 {
            let totalBeatsFromRef = currentSubBeat - driftReferenceBeatCount
            let idealElapsedNs = Double(totalBeatsFromRef) * baseIntervalSec * 1_000_000_000
            let actualElapsedTicks = Double(nextBeatTime!.hostTime - driftReferenceHostTime)
            let actualElapsedNs = actualElapsedTicks * nsPerTick
            let driftNs = actualElapsedNs - idealElapsedNs

            // If drift exceeds 1ms, apply correction (max ±2ms per correction cycle)
            if abs(driftNs) > 1_000_000 {
                let correctionNs = min(abs(driftNs), 2_000_000) * (driftNs > 0 ? -1.0 : 1.0)
                let correctionTicks = Int64(correctionNs / nsPerTick)
                if correctionTicks < 0 {
                    nextBeatTime = AVAudioTime(hostTime: nextBeatTime!.hostTime - UInt64(abs(correctionTicks)))
                } else {
                    nextBeatTime = AVAudioTime(hostTime: nextBeatTime!.hostTime + UInt64(correctionTicks))
                }
            }

            // Reset reference point
            driftReferenceHostTime = nextBeatTime!.hostTime
            driftReferenceBeatCount = currentSubBeat
        }
    }

    private func getSoundKey(clickSound: String, isAccent: Bool) -> String {
        switch clickSound {
        case "Wood": return isAccent ? "click_accent" : "click_normal"
        case "Digital": return isAccent ? "digital_accent" : "digital_normal"
        case "Hi-Hat": return "hihat_click"
        case "Clave": return isAccent ? "clave_accent" : "clave_normal"
        case "Clave HQ": return isAccent ? "clave_hq_accent" : "clave_hq_normal"
        case "Cowbell": return isAccent ? "cowbell_accent" : "cowbell_normal"
        case "Beep": return isAccent ? "beep_accent" : "beep_normal"
        case "Rimshot": return isAccent ? "rimshot_accent" : "rimshot_normal"
        case "Shaker": return isAccent ? "shaker_accent" : "shaker_normal"
        case "Tambourine": return isAccent ? "tambourine_accent" : "tambourine_normal"
        case "WoodBlock": return isAccent ? "woodblock_accent" : "woodblock_normal"
        case "SineBurst": return isAccent ? "sineburst_accent" : "sineburst_normal"
        case "Stick": return isAccent ? "stick_accent" : "stick_normal"
        case "Tick-Tock": return isAccent ? "tick_accent" : "tick_normal"
        case "808 Cowbell": return isAccent ? "808cowbell_accent" : "808cowbell_normal"
        default: return isAccent ? "click_accent" : "click_normal"
        }
    }

    // MARK: - Live Updates

    func updateBpm(_ newBpm: Int) {
        audioQueue.async { self.bpm = newBpm }
    }

    func updateTimeSignature(beatsPerBar: Int, beatUnit: Int) {
        audioQueue.async {
            self.beatsPerBar = beatsPerBar
            self.beatUnit = beatUnit
            let newLen = Array(repeating: 0.7, count: beatsPerBar)
            if self.accentPattern.count != beatsPerBar {
                var newAccents = Array(repeating: 0.7, count: beatsPerBar)
                newAccents[0] = 1.0
                self.accentPattern = newAccents
            }
        }
    }

    func updateSubdivision(_ sub: Int) {
        audioQueue.async { self.subdivision = sub }
    }

    func updateSwing(_ pct: Int) {
        audioQueue.async { self.swingPercent = pct }
    }

    func updateClickSound(_ sound: String) {
        audioQueue.async { self.clickSound = sound }
    }

    func updateAccentPattern(_ pattern: [Double]) {
        audioQueue.async { self.accentPattern = pattern }
    }

    func setHapticMode(_ enabled: Bool) {
        audioQueue.async { self.hapticEnabled = enabled }
    }

    func updateHumanFeel(_ percent: Int) {
        audioQueue.async { self.humanFeel = min(50, max(0, percent)) }
    }

    func updatePolyrhythm(enabled: Bool, value: Int) {
        audioQueue.async {
            self.polyrhythmEnabled = enabled
            self.polyrhythmValue = max(2, min(7, value))
        }
    }

    func updateDrumPattern(_ pattern: [String: [Int]]) {
        audioQueue.async { self.drumPattern = pattern }
    }

    func updateDrumVolumes(_ volumes: [String: Double]) {
        audioQueue.async { self.drumVolumes = volumes }
    }

    private func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    private func lcm(_ a: Int, _ b: Int) -> Int { a / gcd(a, b) * b }

    func getOutputLatency() -> Double {
        return AVAudioSession.sharedInstance().outputLatency * 1000.0 // ms
    }
}
