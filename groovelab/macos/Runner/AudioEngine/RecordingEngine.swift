import AVFoundation
import Accelerate

/// Recording engine with real-time onset detection for macOS.
/// Port of the iOS RecordingEngine — no AVAudioSession on macOS.
final class RecordingEngine {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var isRecording = false

    // Onset detection
    private var onsetDetectionEnabled = false
    private var onsetThreshold: Double = 0.1
    private var minOnsetIntervalMs: Int = 50
    private var lastOnsetTime: UInt64 = 0
    private var previousEnergy: Float = 0
    private var energyHistory: [Float] = []
    private let energyHistorySize = 10

    private let onEvent: ([String: Any]) -> Void
    private var currentFilePath: String?

    init(onEvent: @escaping ([String: Any]) -> Void) {
        self.onEvent = onEvent
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Create output file in app support directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filePath = documentsPath.appendingPathComponent("take_\(timestamp).wav")
        currentFilePath = filePath.path

        do {
            audioFile = try AVAudioFile(forWriting: filePath, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
            ])
        } catch {
            print("RecordingEngine: File creation error: \(error)")
            return
        }

        input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }

        do {
            try engine.start()
        } catch {
            print("RecordingEngine: Engine start error: \(error)")
            return
        }

        self.audioEngine = engine
        self.inputNode = input
        isRecording = true
        previousEnergy = 0
        energyHistory.removeAll()
        lastOnsetTime = 0

        onEvent(["type": "recordingState", "isRecording": true, "durationMs": 0])
    }

    func stopRecording() -> String? {
        guard isRecording else { return nil }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        isRecording = false

        onEvent(["type": "recordingState", "isRecording": false, "durationMs": 0, "filePath": currentFilePath ?? ""])
        return currentFilePath
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        if let file = audioFile {
            do { try file.write(from: buffer) } catch { print("RecordingEngine: Write error: \(error)") }
        }
        if onsetDetectionEnabled { detectOnset(buffer: buffer, time: time) }
    }

    private func detectOnset(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let data = channelData[0]

        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(frameCount))

        let flux = max(0, rms - previousEnergy)
        previousEnergy = rms

        energyHistory.append(flux)
        if energyHistory.count > energyHistorySize { energyHistory.removeFirst() }

        let avgFlux = energyHistory.reduce(0, +) / Float(energyHistory.count)
        let adaptiveThreshold = max(Float(onsetThreshold), avgFlux * 2.5)

        if flux > adaptiveThreshold {
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)
            let nsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
            let nowHost = mach_absolute_time()
            let nowNs = Double(nowHost) * nsPerTick
            let lastNs = Double(lastOnsetTime) * nsPerTick
            let elapsedMs = (nowNs - lastNs) / 1_000_000

            if lastOnsetTime == 0 || elapsedMs >= Double(minOnsetIntervalMs) {
                lastOnsetTime = nowHost
                let timestampUs = Int(nowNs / 1000)
                var peak: Float = 0
                vDSP_maxv(data, 1, &peak, vDSP_Length(frameCount))
                let amplitude = min(1.0, Double(peak))

                onEvent(["type": "onset", "timestampUs": timestampUs, "amplitude": amplitude])
            }
        }
    }

    func enableOnsetDetection(threshold: Double, minIntervalMs: Int) {
        onsetThreshold = threshold
        minOnsetIntervalMs = minIntervalMs
        onsetDetectionEnabled = true
    }

    func disableOnsetDetection() {
        onsetDetectionEnabled = false
    }

    func getInputLatency() -> Double {
        return (audioEngine?.inputNode.presentationLatency ?? 0) * 1000.0
    }
}
