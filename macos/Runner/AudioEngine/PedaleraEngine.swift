import AVFoundation
import Accelerate

/// Real-time guitar effects signal chain for macOS using AVAudioEngine.
/// Port of iOS PedaleraEngine — no AVAudioSession on macOS.
final class PedaleraEngine {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputMixer: AVAudioMixerNode?
    private var chainNodes: [(type: String, nodes: [AVAudioNode], enabled: Bool)] = []
    private var isActive = false
    private let onEvent: ([String: Any]) -> Void

    init(onEvent: @escaping ([String: Any]) -> Void) { self.onEvent = onEvent }

    func initialize() {
        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        do { try engine.start() } catch { print("PedaleraEngine: \(error)") }
        self.audioEngine = engine; self.inputNode = engine.inputNode; self.outputMixer = mixer
    }

    func setChain(_ config: [[String: Any]]) {
        guard let engine = audioEngine, let input = inputNode else { return }
        disconnectChain()
        let fmt = input.outputFormat(forBus: 0)
        var nc: [(type: String, nodes: [AVAudioNode], enabled: Bool)] = []
        for p in config {
            guard let t = p["type"] as? String, let en = p["enabled"] as? Bool,
                  let pr = p["params"] as? [String: Double] else { continue }
            let nodes = createNodes(type: t, params: pr, engine: engine, format: fmt)
            if !nodes.isEmpty { nc.append((type: t, nodes: nodes, enabled: en)) }
        }
        self.chainNodes = nc; reconnectChain()
    }

    private func createNodes(type: String, params: [String: Double], engine: AVAudioEngine, format: AVAudioFormat) -> [AVAudioNode] {
        switch type {
        case "noiseGate":
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            eq.bands[0].filterType = .highPass; eq.bands[0].frequency = 80; eq.bands[0].bypass = false
            engine.attach(eq); return [eq]
        case "compressor":
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            eq.bands[0].filterType = .parametric; eq.bands[0].frequency = 1000; eq.bands[0].gain = 0
            eq.bands[0].bandwidth = 4.0; eq.bands[0].bypass = false
            engine.attach(eq); return [eq]
        case "drive":
            let d = AVAudioUnitDistortion()
            let g = params["gain"] ?? 50
            d.loadFactoryPreset(g > 70 ? .drumsBitBrush : .drumsBufferBeats)
            d.wetDryMix = Float(g); engine.attach(d); return [d]
        case "eq":
            let eq = AVAudioUnitEQ(numberOfBands: 5)
            let f: [Float] = [100,300,1000,3500,10000]
            let g: [Float] = [Float(params["low"] ?? 0),Float(params["lowMid"] ?? 0),Float(params["mid"] ?? 0),Float(params["hiMid"] ?? 0),Float(params["high"] ?? 0)]
            let t: [AVAudioUnitEQFilterType] = [.lowShelf,.parametric,.parametric,.parametric,.highShelf]
            for i in 0..<5 { eq.bands[i].filterType = t[i]; eq.bands[i].frequency = f[i]; eq.bands[i].gain = g[i]; eq.bands[i].bandwidth = 1.0; eq.bands[i].bypass = false }
            engine.attach(eq); return [eq]
        case "amp":
            let d = AVAudioUnitDistortion()
            d.loadFactoryPreset((params["gain"] ?? 50) > 60 ? .multiDistortedSquared : .multiBrokenSpeaker)
            d.wetDryMix = Float(params["gain"] ?? 50); engine.attach(d)
            let eq = AVAudioUnitEQ(numberOfBands: 3)
            eq.bands[0].filterType = .lowShelf; eq.bands[0].frequency = 200; eq.bands[0].gain = Float((params["bass"] ?? 50) - 50) / 5
            eq.bands[1].filterType = .parametric; eq.bands[1].frequency = 1000; eq.bands[1].gain = Float((params["mid"] ?? 50) - 50) / 5; eq.bands[1].bandwidth = 0.8
            eq.bands[2].filterType = .highShelf; eq.bands[2].frequency = 3500; eq.bands[2].gain = Float((params["treble"] ?? 50) - 50) / 5
            engine.attach(eq); return [d, eq]
        case "cabinet":
            let r = AVAudioUnitReverb(); r.loadFactoryPreset(.smallRoom); r.wetDryMix = Float(params["mix"] ?? 100) * 0.3
            engine.attach(r); return [r]
        case "chorus":
            let d = AVAudioUnitDelay(); d.delayTime = 0.015; d.feedback = 20; d.wetDryMix = Float(params["mix"] ?? 40)
            engine.attach(d); return [d]
        case "delay":
            let d = AVAudioUnitDelay(); d.delayTime = (params["time"] ?? 400) / 1000.0
            d.feedback = Float(params["feedback"] ?? 35); d.wetDryMix = Float(params["mix"] ?? 30)
            engine.attach(d); return [d]
        case "reverb":
            let r = AVAudioUnitReverb()
            let dc = params["decay"] ?? 50
            r.loadFactoryPreset(dc < 30 ? .smallRoom : dc < 60 ? .mediumRoom : .largeChamber)
            r.wetDryMix = Float(params["mix"] ?? 30); engine.attach(r); return [r]
        default: return []
        }
    }

    private func reconnectChain() {
        guard let engine = audioEngine, let input = inputNode, let output = outputMixer else { return }
        let fmt = input.outputFormat(forBus: 0); var cur: AVAudioNode = input
        for item in chainNodes where item.enabled && !item.nodes.isEmpty {
            for node in item.nodes { engine.connect(cur, to: node, format: fmt); cur = node }
        }
        engine.connect(cur, to: output, format: fmt); isActive = true
    }

    private func disconnectChain() {
        guard let engine = audioEngine else { return }
        for item in chainNodes { for n in item.nodes { engine.disconnectNodeOutput(n); engine.detach(n) } }
        if let input = inputNode { engine.disconnectNodeOutput(input) }
        chainNodes = []; isActive = false
    }

    func setParam(pedalIndex: Int, paramName: String, value: Double) {}
    func setBypass(pedalIndex: Int, bypassed: Bool) {
        guard pedalIndex >= 0, pedalIndex < chainNodes.count else { return }
        chainNodes[pedalIndex].enabled = !bypassed
        guard let engine = audioEngine, let input = inputNode else { return }
        engine.disconnectNodeOutput(input)
        for item in chainNodes { for n in item.nodes { engine.disconnectNodeOutput(n) } }
        reconnectChain()
    }

    func getLatency() -> Double {
        return ((audioEngine?.outputNode.presentationLatency ?? 0) + (audioEngine?.inputNode.presentationLatency ?? 0)) * 1000.0
    }

    func stop() { disconnectChain(); audioEngine?.stop(); audioEngine = nil; isActive = false }
}
