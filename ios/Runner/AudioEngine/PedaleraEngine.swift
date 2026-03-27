import AVFoundation
import AudioToolbox
import Accelerate

/// Real-time guitar effects signal chain using AVAudioEngine.
/// Chain: Input → NoiseGate → Compressor → Drive → EQ → Amp → Cabinet → Chorus → Delay → Reverb → Output
final class PedaleraEngine {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputMixer: AVAudioMixerNode?
    private var chainNodes: [(type: String, nodes: [AVAudioNode], enabled: Bool)] = []
    private var isActive = false

    private let onEvent: ([String: Any]) -> Void

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
        case "noiseGate":
            // Noise gate using dynamics processor with high ratio as gate
            let gate = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_DynamicsProcessor,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            ))
            engine.attach(gate)
            let auGate = gate.audioUnit
            let gateThreshold = Float32(params["threshold"] ?? -40)
            AudioUnitSetParameter(auGate, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, gateThreshold, 0)
            AudioUnitSetParameter(auGate, kDynamicsProcessorParam_CompressionAmount, kAudioUnitScope_Global, 0, 40, 0) // high ratio = gate
            AudioUnitSetParameter(auGate, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, 0.001, 0)
            AudioUnitSetParameter(auGate, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, 0.05, 0)
            return [gate]

        case "compressor":
            // Real dynamics compressor using Apple's built-in AudioUnit
            let compressor = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_DynamicsProcessor,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            ))
            engine.attach(compressor)
            // Set compressor parameters via AudioUnit API
            let au = compressor.audioUnit
            let threshold = Float32(params["threshold"] ?? -20)
            let ratio = Float32(params["ratio"] ?? 4)
            let attack = Float32(params["attack"] ?? 0.01)
            let release = Float32(params["release"] ?? 0.1)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, threshold, 0)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_CompressionAmount, kAudioUnitScope_Global, 0, ratio, 0)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, attack, 0)
            AudioUnitSetParameter(au, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, release, 0)
            return [compressor]

        case "drive":
            let dist = AVAudioUnitDistortion()
            let gain = params["gain"] ?? 50
            if gain > 70 {
                dist.loadFactoryPreset(.drumsBitBrush)
            } else {
                dist.loadFactoryPreset(.drumsBufferBeats)
            }
            dist.wetDryMix = Float(gain)
            engine.attach(dist)
            return [dist]

        case "eq":
            let eq = AVAudioUnitEQ(numberOfBands: 5)
            let freqs: [Float] = [100, 300, 1000, 3500, 10000]
            let gains: [Float] = [
                Float(params["low"] ?? 0),
                Float(params["lowMid"] ?? 0),
                Float(params["mid"] ?? 0),
                Float(params["hiMid"] ?? 0),
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

        case "cabinet":
            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(.smallRoom)
            reverb.wetDryMix = Float(params["mix"] ?? 100) * 0.3
            engine.attach(reverb)
            return [reverb]

        case "chorus":
            let delay = AVAudioUnitDelay()
            delay.delayTime = 0.015
            delay.feedback = 20
            delay.wetDryMix = Float(params["mix"] ?? 40)
            engine.attach(delay)
            return [delay]

        case "delay":
            let delay = AVAudioUnitDelay()
            delay.delayTime = (params["time"] ?? 400) / 1000.0
            delay.feedback = Float(params["feedback"] ?? 35)
            delay.wetDryMix = Float(params["mix"] ?? 30)
            engine.attach(delay)
            return [delay]

        case "reverb":
            let reverb = AVAudioUnitReverb()
            let decay = params["decay"] ?? 50
            if decay < 30 {
                reverb.loadFactoryPreset(.smallRoom)
            } else if decay < 60 {
                reverb.loadFactoryPreset(.mediumRoom)
            } else {
                reverb.loadFactoryPreset(.largeChamber)
            }
            reverb.wetDryMix = Float(params["mix"] ?? 30)
            engine.attach(reverb)
            return [reverb]

        default:
            return []
        }
    }

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

        // Detach all chain nodes
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
        case "drive", "amp":
            if let dist = item.nodes.first as? AVAudioUnitDistortion {
                if paramName == "gain" || paramName == "mix" {
                    dist.wetDryMix = Float(value)
                }
            }
            // EQ part of amp
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
            if let reverb = item.nodes.first as? AVAudioUnitReverb {
                if paramName == "mix" { reverb.wetDryMix = Float(value) }
            }
        case "chorus":
            if let delay = item.nodes.first as? AVAudioUnitDelay {
                switch paramName {
                case "rate": delay.delayTime = max(0.005, min(0.030, value / 1000.0))
                case "mix":  delay.wetDryMix = Float(value)
                default: break
                }
            }
        case "cabinet":
            if let reverb = item.nodes.first as? AVAudioUnitReverb {
                if paramName == "mix" { reverb.wetDryMix = Float(value) * 0.3 }
            }
        case "compressor", "noiseGate":
            if let effect = item.nodes.first as? AVAudioUnitEffect {
                let au = effect.audioUnit
                switch paramName {
                case "threshold": AudioUnitSetParameter(au, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, Float32(value), 0)
                case "ratio": AudioUnitSetParameter(au, kDynamicsProcessorParam_CompressionAmount, kAudioUnitScope_Global, 0, Float32(value), 0)
                case "attack": AudioUnitSetParameter(au, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, Float32(value), 0)
                case "release": AudioUnitSetParameter(au, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, Float32(value), 0)
                default: break
                }
            }
        default:
            break
        }
    }

    func setBypass(pedalIndex: Int, bypassed: Bool) {
        guard pedalIndex >= 0, pedalIndex < chainNodes.count else { return }
        chainNodes[pedalIndex].enabled = !bypassed

        // Instead of disconnecting entire chain (which causes audio dropout),
        // use node bypass when possible
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
    }

    func getLatency() -> Double {
        return (AVAudioSession.sharedInstance().outputLatency + AVAudioSession.sharedInstance().inputLatency) * 1000.0
    }

    // MARK: - Cleanup

    func stop() {
        disconnectChain()
        audioEngine?.stop()
        audioEngine = nil
        isActive = false
    }
}
