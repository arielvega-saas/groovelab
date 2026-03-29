import AVFoundation
import AudioToolbox
import Accelerate

/// Professional-quality guitar effects signal chain using AVAudioEngine.
/// Real DSP implementations: dynamics processor, LFO-modulated chorus, cabinet IR via EQ, etc.
final class PedaleraEngine {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputMixer: AVAudioMixerNode?
    private var chainNodes: [(type: String, nodes: [AVAudioNode], enabled: Bool)] = []
    private var isActive = false
    private let onEvent: ([String: Any]) -> Void

    // Chorus LFO state
    private var chorusTimer: DispatchSourceTimer?
    private var chorusLFOPhase: Double = 0.0
    private var chorusRate: Double = 1.0     // Hz
    private var chorusDepth: Double = 5.0    // ms
    private var chorusBaseDelay: Double = 12.0 // ms

    // Noise gate state
    private var gateInputTap: Bool = false
    private var gateGainNode: AVAudioMixerNode?
    private var gateThreshold: Float = -40.0
    private var gateAttack: Float = 0.5      // ms
    private var gateHold: Float = 100.0      // ms
    private var gateRelease: Float = 50.0    // ms
    private var gateIsOpen: Bool = true
    private var gateHoldCounter: Float = 0.0
    private var gateCurrentGain: Float = 1.0

    init(onEvent: @escaping ([String: Any]) -> Void) {
        self.onEvent = onEvent
    }

    // MARK: - Initialization

    func initialize() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("PedaleraEngine: AudioSession error: \(error)")
        }

        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        do {
            try engine.start()
        } catch {
            print("PedaleraEngine: Engine start error: \(error)")
        }

        self.audioEngine = engine
        self.inputNode = engine.inputNode
        self.outputMixer = mixer
    }

    // MARK: - Chain Building

    func setChain(_ config: [[String: Any]]) {
        guard let engine = audioEngine, let input = inputNode, let output = outputMixer else { return }

        // Disconnect existing chain
        disconnectChain()

        let inputFormat = input.outputFormat(forBus: 0)
        var newChain: [(type: String, nodes: [AVAudioNode], enabled: Bool)] = []

        for pedal in config {
            guard let type = pedal["type"] as? String,
                  let enabled = pedal["enabled"] as? Bool,
                  let params = pedal["params"] as? [String: Double] else { continue }

            let nodes = createNodes(type: type, params: params, engine: engine, format: inputFormat)
            if !nodes.isEmpty {
                newChain.append((type: type, nodes: nodes, enabled: enabled))
            }
        }

        self.chainNodes = newChain
        reconnectChain()
    }

    private func createNodes(type: String, params: [String: Double], engine: AVAudioEngine, format: AVAudioFormat) -> [AVAudioNode] {
        switch type {

        // ─── NOISE GATE ─────────────────────────────────────────────────────
        // Real threshold-based gate using level monitoring + gain node
        case "noiseGate":
            let gateGain = AVAudioMixerNode()
            engine.attach(gateGain)
            self.gateGainNode = gateGain
            self.gateThreshold = Float(params["threshold"] ?? -40)
            self.gateAttack = Float(params["attack"] ?? 0.5)
            self.gateHold = Float(params["hold"] ?? 100)
            self.gateRelease = Float(params["release"] ?? 50)
            self.gateIsOpen = true
            self.gateCurrentGain = 1.0
            self.gateHoldCounter = 0.0
            startGateMonitoring(engine: engine, format: format)
            return [gateGain]

        // ─── COMPRESSOR ─────────────────────────────────────────────────────
        // Apple's built-in DynamicsProcessor AudioUnit — a real compressor
        case "compressor":
            let compressor = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_DynamicsProcessor,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            ))
            engine.attach(compressor)
            let au = compressor.audioUnit
            let threshold = Float32(params["threshold"] ?? -20)
            let ratio = Float32(params["ratio"] ?? 4)
            let attack = Float32(params["attack"] ?? 10) / 1000.0  // convert ms to seconds
            let release = Float32(params["release"] ?? 100) / 1000.0
            let makeupGain = Float32(params["makeupGain"] ?? 0)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, threshold, 0)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, Float32(ratio), 0)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, attack, 0)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, release, 0)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, makeupGain, 0)
            return [compressor]

        // ─── DRIVE ──────────────────────────────────────────────────────────
        // AVAudioUnitDistortion with preset mapping + post-distortion tone EQ
        case "drive":
            let dist = AVAudioUnitDistortion()
            let gain = params["gain"] ?? 50
            let driveType = Int(params["driveType"] ?? 0)
            // 0=Clean Boost, 1=Tube Overdrive, 2=Heavy Distortion, 3=Fuzz
            switch driveType {
            case 0: // Clean Boost
                dist.loadFactoryPreset(.drumsBufferBeats)
                dist.wetDryMix = Float(min(gain * 0.3, 30))
            case 1: // Tube Overdrive
                dist.loadFactoryPreset(.multiDistortedCubed)
                dist.wetDryMix = Float(gain * 0.7)
            case 2: // Heavy Distortion
                dist.loadFactoryPreset(.multiDistortedSquared)
                dist.wetDryMix = Float(gain)
            case 3: // Fuzz
                dist.loadFactoryPreset(.multiDistortedFunk)
                dist.wetDryMix = Float(min(gain * 1.2, 100))
            default:
                dist.loadFactoryPreset(gain > 70 ? .drumsBitBrush : .drumsBufferBeats)
                dist.wetDryMix = Float(gain)
            }
            engine.attach(dist)
            // Post-distortion tone control (low-pass filter for darkness)
            let toneEQ = AVAudioUnitEQ(numberOfBands: 2)
            let tone = Float(params["toneControl"] ?? 50)
            // Tone: 0=dark (1kHz lowpass), 50=neutral, 100=bright (boost highs)
            let lpFreq: Float = 1000 + (tone / 100.0) * 9000 // 1kHz to 10kHz
            toneEQ.bands[0].filterType = .lowPass
            toneEQ.bands[0].frequency = lpFreq
            toneEQ.bands[0].bypass = false
            // High shelf for brightness
            toneEQ.bands[1].filterType = .highShelf
            toneEQ.bands[1].frequency = 3000
            toneEQ.bands[1].gain = (tone - 50) / 5.0 // -10 to +10 dB
            toneEQ.bands[1].bypass = false
            engine.attach(toneEQ)
            return [dist, toneEQ]

        // ─── EQ ─────────────────────────────────────────────────────────────
        case "eq":
            let eq = AVAudioUnitEQ(numberOfBands: 5)
            let freqs: [Float] = [100, 300, 1000, 3500, 10000]
            let gains: [Float] = [
                Float(params["low"] ?? 0), Float(params["lowMid"] ?? 0),
                Float(params["mid"] ?? 0), Float(params["hiMid"] ?? 0),
                Float(params["high"] ?? 0)
            ]
            let types: [AVAudioUnitEQFilterType] = [.lowShelf, .parametric, .parametric, .parametric, .highShelf]
            for i in 0..<5 {
                eq.bands[i].filterType = types[i]
                eq.bands[i].frequency = freqs[i]
                eq.bands[i].gain = gains[i]
                eq.bands[i].bandwidth = 1.0
                eq.bands[i].bypass = false
            }
            engine.attach(eq)
            return [eq]

        // ─── AMP ────────────────────────────────────────────────────────────
        case "amp":
            let dist = AVAudioUnitDistortion()
            let gain = params["gain"] ?? 50
            if gain > 60 {
                dist.loadFactoryPreset(.multiDistortedSquared)
            } else {
                dist.loadFactoryPreset(.multiBrokenSpeaker)
            }
            dist.wetDryMix = Float(gain)
            engine.attach(dist)

            let eq = AVAudioUnitEQ(numberOfBands: 3)
            let bassGain = Float((params["bass"] ?? 50) - 50) / 5
            let midGain = Float((params["mid"] ?? 50) - 50) / 5
            let trebleGain = Float((params["treble"] ?? 50) - 50) / 5
            eq.bands[0].filterType = .lowShelf
            eq.bands[0].frequency = 200
            eq.bands[0].gain = bassGain
            eq.bands[1].filterType = .parametric
            eq.bands[1].frequency = 1000
            eq.bands[1].gain = midGain
            eq.bands[1].bandwidth = 0.8
            eq.bands[2].filterType = .highShelf
            eq.bands[2].frequency = 3500
            eq.bands[2].gain = trebleGain
            engine.attach(eq)
            return [dist, eq]

        // ─── CABINET SIMULATION ─────────────────────────────────────────────
        // Multi-band EQ curves simulating speaker cabinet impulse responses
        case "cabinet":
            let cabinetType = Int(params["cabinetType"] ?? 0)
            let eq = AVAudioUnitEQ(numberOfBands: 6)
            applyCabinetCurve(eq: eq, cabinetType: cabinetType)
            engine.attach(eq)
            // Add a very short room ambiance to simulate mic'd cab
            let ambience = AVAudioUnitReverb()
            ambience.loadFactoryPreset(.smallRoom)
            ambience.wetDryMix = Float(params["mix"] ?? 100) * 0.15  // subtle room
            engine.attach(ambience)
            return [eq, ambience]

        // ─── CHORUS ─────────────────────────────────────────────────────────
        // Real two-voice chorus with sine LFO modulating delay time
        case "chorus":
            let delay = AVAudioUnitDelay()
            self.chorusRate = (params["rate"] ?? 40) / 40.0  // normalize: 0-100 -> 0-2.5Hz
            self.chorusDepth = (params["depth"] ?? 50) / 10.0 // normalize: 0-100 -> 0-10ms
            self.chorusBaseDelay = 12.0  // ms
            delay.delayTime = chorusBaseDelay / 1000.0
            delay.feedback = 15
            delay.lowPassCutoff = 12000
            delay.wetDryMix = Float(params["mix"] ?? 40)
            engine.attach(delay)
            startChorusLFO(delay: delay)
            return [delay]

        // ─── DELAY ──────────────────────────────────────────────────────────
        case "delay":
            let delay = AVAudioUnitDelay()
            delay.delayTime = (params["time"] ?? 400) / 1000.0
            delay.feedback = Float(params["feedback"] ?? 35)
            delay.wetDryMix = Float(params["mix"] ?? 30)
            delay.lowPassCutoff = 15000
            engine.attach(delay)
            return [delay]

        // ─── REVERB ─────────────────────────────────────────────────────────
        // Apple built-in reverb with preset mapping + pre-delay
        case "reverb":
            let preDelayMs = params["preDelay"] ?? 0
            var nodes: [AVAudioNode] = []
            if preDelayMs > 1.0 {
                let preDelay = AVAudioUnitDelay()
                preDelay.delayTime = preDelayMs / 1000.0
                preDelay.feedback = 0
                preDelay.wetDryMix = 100
                preDelay.lowPassCutoff = 20000
                engine.attach(preDelay)
                nodes.append(preDelay)
            }
            let r = AVAudioUnitReverb()
            let reverbType = Int(params["reverbType"] ?? 0)
            // 0=Room, 1=Hall, 2=Plate, 3=Spring, 4=Cathedral, 5=Chamber
            switch reverbType {
            case 0: r.loadFactoryPreset(.smallRoom)
            case 1: r.loadFactoryPreset(.largeHall)
            case 2: r.loadFactoryPreset(.plate)
            case 3: r.loadFactoryPreset(.mediumRoom) // closest to spring
            case 4: r.loadFactoryPreset(.cathedral)
            case 5: r.loadFactoryPreset(.largeChamber)
            default:
                let decay = params["decay"] ?? 50
                if decay < 30 { r.loadFactoryPreset(.smallRoom) }
                else if decay < 60 { r.loadFactoryPreset(.mediumRoom) }
                else { r.loadFactoryPreset(.largeChamber) }
            }
            r.wetDryMix = Float(params["mix"] ?? 30)
            engine.attach(r)
            nodes.append(r)
            return nodes

        default:
            return []
        }
    }

    // MARK: - Cabinet EQ Curves

    private func applyCabinetCurve(eq: AVAudioUnitEQ, cabinetType: Int) {
        switch cabinetType {
        case 0: // 1x12 Combo — mid-focused, 2-6kHz cut, balanced lows
            eq.bands[0].filterType = .highPass;   eq.bands[0].frequency = 80;   eq.bands[0].bypass = false
            eq.bands[1].filterType = .lowShelf;    eq.bands[1].frequency = 150;  eq.bands[1].gain = 1.0;  eq.bands[1].bypass = false
            eq.bands[2].filterType = .parametric;  eq.bands[2].frequency = 700;  eq.bands[2].gain = 3.0;  eq.bands[2].bandwidth = 1.2; eq.bands[2].bypass = false
            eq.bands[3].filterType = .parametric;  eq.bands[3].frequency = 3500; eq.bands[3].gain = -4.0; eq.bands[3].bandwidth = 1.5; eq.bands[3].bypass = false
            eq.bands[4].filterType = .highShelf;   eq.bands[4].frequency = 6000; eq.bands[4].gain = -8.0; eq.bands[4].bypass = false
            eq.bands[5].filterType = .lowPass;     eq.bands[5].frequency = 8000; eq.bands[5].bypass = false

        case 1: // 2x12 Open Back — balanced, slight high cut, wider low-mid
            eq.bands[0].filterType = .highPass;   eq.bands[0].frequency = 70;   eq.bands[0].bypass = false
            eq.bands[1].filterType = .lowShelf;    eq.bands[1].frequency = 120;  eq.bands[1].gain = 2.0;  eq.bands[1].bypass = false
            eq.bands[2].filterType = .parametric;  eq.bands[2].frequency = 500;  eq.bands[2].gain = 2.0;  eq.bands[2].bandwidth = 1.5; eq.bands[2].bypass = false
            eq.bands[3].filterType = .parametric;  eq.bands[3].frequency = 2500; eq.bands[3].gain = -2.0; eq.bands[3].bandwidth = 1.0; eq.bands[3].bypass = false
            eq.bands[4].filterType = .highShelf;   eq.bands[4].frequency = 5500; eq.bands[4].gain = -6.0; eq.bands[4].bypass = false
            eq.bands[5].filterType = .lowPass;     eq.bands[5].frequency = 9000; eq.bands[5].bypass = false

        case 2: // 4x12 Closed Back — bass heavy, sharp high cut at 5kHz, tight
            eq.bands[0].filterType = .highPass;   eq.bands[0].frequency = 60;   eq.bands[0].bypass = false
            eq.bands[1].filterType = .lowShelf;    eq.bands[1].frequency = 200;  eq.bands[1].gain = 4.0;  eq.bands[1].bypass = false
            eq.bands[2].filterType = .parametric;  eq.bands[2].frequency = 800;  eq.bands[2].gain = 2.0;  eq.bands[2].bandwidth = 0.8; eq.bands[2].bypass = false
            eq.bands[3].filterType = .parametric;  eq.bands[3].frequency = 4000; eq.bands[3].gain = -6.0; eq.bands[3].bandwidth = 1.0; eq.bands[3].bypass = false
            eq.bands[4].filterType = .highShelf;   eq.bands[4].frequency = 5000; eq.bands[4].gain = -12.0; eq.bands[4].bypass = false
            eq.bands[5].filterType = .lowPass;     eq.bands[5].frequency = 6000; eq.bands[5].bypass = false

        case 3: // 1x10 Jazz — warm, rolled off above 4kHz, scooped highs
            eq.bands[0].filterType = .highPass;   eq.bands[0].frequency = 90;   eq.bands[0].bypass = false
            eq.bands[1].filterType = .lowShelf;    eq.bands[1].frequency = 180;  eq.bands[1].gain = 2.0;  eq.bands[1].bypass = false
            eq.bands[2].filterType = .parametric;  eq.bands[2].frequency = 400;  eq.bands[2].gain = 2.5;  eq.bands[2].bandwidth = 1.8; eq.bands[2].bypass = false
            eq.bands[3].filterType = .parametric;  eq.bands[3].frequency = 2000; eq.bands[3].gain = -3.0; eq.bands[3].bandwidth = 1.2; eq.bands[3].bypass = false
            eq.bands[4].filterType = .highShelf;   eq.bands[4].frequency = 4000; eq.bands[4].gain = -14.0; eq.bands[4].bypass = false
            eq.bands[5].filterType = .lowPass;     eq.bands[5].frequency = 5000; eq.bands[5].bypass = false

        default:
            applyCabinetCurve(eq: eq, cabinetType: 1)
        }
    }

    // MARK: - Chorus LFO

    private func startChorusLFO(delay: AVAudioUnitDelay) {
        stopChorusLFO()
        chorusLFOPhase = 0.0
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        let intervalMs = 10.0 // 100Hz update rate for smooth modulation
        timer.schedule(deadline: .now(), repeating: .milliseconds(Int(intervalMs)))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let phaseIncrement = self.chorusRate * (intervalMs / 1000.0) * 2.0 * .pi
            self.chorusLFOPhase += phaseIncrement
            if self.chorusLFOPhase > 2.0 * .pi { self.chorusLFOPhase -= 2.0 * .pi }
            let lfoValue = sin(self.chorusLFOPhase) // -1 to +1
            let delayMs = self.chorusBaseDelay + (lfoValue * self.chorusDepth)
            let clampedDelay = max(1.0, min(30.0, delayMs)) / 1000.0
            delay.delayTime = clampedDelay
        }
        timer.resume()
        chorusTimer = timer
    }

    private func stopChorusLFO() {
        chorusTimer?.cancel()
        chorusTimer = nil
    }

    // MARK: - Noise Gate Monitoring

    private func startGateMonitoring(engine: AVAudioEngine, format: AVAudioFormat) {
        guard let input = inputNode else { return }
        let bufferSize: AVAudioFrameCount = 512
        gateInputTap = true
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self = self, let gainNode = self.gateGainNode else { return }
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            // Calculate RMS level in dB
            var rms: Float = 0
            vDSP_measqv(channelData[0], 1, &rms, vDSP_Length(frameCount))
            rms = sqrtf(rms)
            let db = rms > 0 ? 20.0 * log10f(rms) : -120.0
            // Gate logic with attack/hold/release
            let sampleRate = Float(format.sampleRate)
            let bufferDurationMs = Float(frameCount) / sampleRate * 1000.0
            if db > self.gateThreshold {
                // Signal above threshold -> open gate
                self.gateHoldCounter = self.gateHold
                if !self.gateIsOpen {
                    self.gateIsOpen = true
                    let attackSamples = max(1, self.gateAttack / bufferDurationMs)
                    let step = (1.0 - self.gateCurrentGain) / attackSamples
                    self.gateCurrentGain = min(1.0, self.gateCurrentGain + step)
                } else {
                    self.gateCurrentGain = 1.0
                }
            } else {
                // Signal below threshold
                if self.gateHoldCounter > 0 {
                    self.gateHoldCounter -= bufferDurationMs
                } else {
                    self.gateIsOpen = false
                    let releaseSamples = max(1, self.gateRelease / bufferDurationMs)
                    let step = self.gateCurrentGain / releaseSamples
                    self.gateCurrentGain = max(0.0, self.gateCurrentGain - step)
                }
            }
            gainNode.outputVolume = self.gateCurrentGain
        }
    }

    private func stopGateMonitoring() {
        if gateInputTap, let input = inputNode {
            input.removeTap(onBus: 0)
            gateInputTap = false
        }
        gateGainNode = nil
    }

    // MARK: - Chain Connection

    private func reconnectChain() {
        guard let engine = audioEngine, let input = inputNode, let output = outputMixer else { return }

        let format = input.outputFormat(forBus: 0)
        var current: AVAudioNode = input

        for item in chainNodes {
            if !item.enabled || item.nodes.isEmpty { continue }
            for node in item.nodes {
                engine.connect(current, to: node, format: format)
                current = node
            }
        }

        engine.connect(current, to: output, format: format)
        isActive = true
    }

    private func disconnectChain() {
        guard let engine = audioEngine else { return }
        stopChorusLFO()
        stopGateMonitoring()

        for item in chainNodes {
            for node in item.nodes {
                engine.disconnectNodeOutput(node)
                engine.detach(node)
            }
        }
        if let input = inputNode {
            engine.disconnectNodeOutput(input)
        }
        chainNodes = []
        isActive = false
    }

    // MARK: - Parameter Updates

    func setParam(pedalIndex: Int, paramName: String, value: Double) {
        guard pedalIndex >= 0, pedalIndex < chainNodes.count else { return }
        let item = chainNodes[pedalIndex]

        switch item.type {

        case "noiseGate":
            switch paramName {
            case "threshold": gateThreshold = Float(value)
            case "attack":    gateAttack = Float(value)
            case "hold":      gateHold = Float(value)
            case "release":   gateRelease = Float(value)
            default: break
            }

        case "compressor":
            if let effect = item.nodes.first as? AVAudioUnitEffect {
                let au = effect.audioUnit
                switch paramName {
                case "threshold":  AudioUnitSetParameter(au, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, Float32(value), 0)
                case "ratio":      AudioUnitSetParameter(au, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, Float32(value), 0)
                case "attack":     AudioUnitSetParameter(au, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, Float32(value / 1000.0), 0)
                case "release":    AudioUnitSetParameter(au, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, Float32(value / 1000.0), 0)
                case "makeupGain": AudioUnitSetParameter(au, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, Float32(value), 0)
                default: break
                }
            }

        case "drive":
            if let dist = item.nodes.first as? AVAudioUnitDistortion {
                if paramName == "gain" { dist.wetDryMix = Float(value) }
            }
            if item.nodes.count > 1, let toneEQ = item.nodes.last as? AVAudioUnitEQ {
                if paramName == "toneControl" {
                    let tone = Float(value)
                    toneEQ.bands[0].frequency = 1000 + (tone / 100.0) * 9000
                    toneEQ.bands[1].gain = (tone - 50) / 5.0
                }
            }

        case "amp":
            if let dist = item.nodes.first as? AVAudioUnitDistortion {
                if paramName == "gain" || paramName == "mix" { dist.wetDryMix = Float(value) }
            }
            if item.nodes.count > 1, let eq = item.nodes.last as? AVAudioUnitEQ {
                switch paramName {
                case "bass":   eq.bands[0].gain = Float((value - 50) / 5)
                case "mid":    eq.bands[1].gain = Float((value - 50) / 5)
                case "treble": eq.bands[2].gain = Float((value - 50) / 5)
                default: break
                }
            }

        case "eq":
            if let eq = item.nodes.first as? AVAudioUnitEQ {
                let bandMap = ["low": 0, "lowMid": 1, "mid": 2, "hiMid": 3, "high": 4]
                if let idx = bandMap[paramName], idx < eq.bands.count {
                    eq.bands[idx].gain = Float(value)
                }
            }

        case "cabinet":
            if let eq = item.nodes.first as? AVAudioUnitEQ {
                if paramName == "cabinetType" {
                    applyCabinetCurve(eq: eq, cabinetType: Int(value))
                }
            }
            if item.nodes.count > 1, let reverb = item.nodes.last as? AVAudioUnitReverb {
                if paramName == "mix" { reverb.wetDryMix = Float(value) * 0.15 }
            }

        case "chorus":
            if let delay = item.nodes.first as? AVAudioUnitDelay {
                switch paramName {
                case "rate":
                    chorusRate = value / 40.0
                case "depth":
                    chorusDepth = value / 10.0
                case "mix":
                    delay.wetDryMix = Float(value)
                default: break
                }
            }

        case "delay":
            if let delay = item.nodes.first as? AVAudioUnitDelay {
                switch paramName {
                case "time":     delay.delayTime = value / 1000.0
                case "feedback": delay.feedback = Float(value)
                case "mix":      delay.wetDryMix = Float(value)
                default: break
                }
            }

        case "reverb":
            let reverbNode: AVAudioUnitReverb? = item.nodes.last as? AVAudioUnitReverb
            let preDelayNode: AVAudioUnitDelay? = item.nodes.count > 1 ? item.nodes.first as? AVAudioUnitDelay : nil
            switch paramName {
            case "mix":      reverbNode?.wetDryMix = Float(value)
            case "preDelay": preDelayNode?.delayTime = value / 1000.0
            default: break
            }

        default:
            break
        }
    }

    func setBypass(pedalIndex: Int, bypassed: Bool) {
        guard pedalIndex >= 0, pedalIndex < chainNodes.count else { return }
        chainNodes[pedalIndex].enabled = !bypassed

        for node in chainNodes[pedalIndex].nodes {
            if let eq = node as? AVAudioUnitEQ {
                eq.bypass = bypassed
            } else if let effect = node as? AVAudioUnitEffect {
                effect.bypass = bypassed
            } else if let dist = node as? AVAudioUnitDistortion {
                dist.bypass = bypassed
            } else if let reverb = node as? AVAudioUnitReverb {
                reverb.bypass = bypassed
            } else if let delay = node as? AVAudioUnitDelay {
                delay.bypass = bypassed
            } else if let mixer = node as? AVAudioMixerNode, node !== outputMixer {
                mixer.outputVolume = bypassed ? 1.0 : gateCurrentGain
            } else {
                // Fallback: reconnect chain for node types without bypass
                guard let engine = audioEngine, let input = inputNode else { return }
                engine.disconnectNodeOutput(input)
                for item in chainNodes {
                    for n in item.nodes {
                        engine.disconnectNodeOutput(n)
                    }
                }
                reconnectChain()
                return
            }
        }
        // Stop/start chorus LFO on bypass
        if chainNodes[pedalIndex].type == "chorus" {
            if bypassed {
                stopChorusLFO()
            } else if let delay = chainNodes[pedalIndex].nodes.first as? AVAudioUnitDelay {
                startChorusLFO(delay: delay)
            }
        }
    }

    func getLatency() -> Double {
        return (AVAudioSession.sharedInstance().outputLatency + AVAudioSession.sharedInstance().inputLatency) * 1000.0
    }

    // MARK: - Cleanup

    func stop() {
        stopChorusLFO()
        stopGateMonitoring()
        disconnectChain()
        audioEngine?.stop()
        audioEngine = nil
        isActive = false
    }
}
