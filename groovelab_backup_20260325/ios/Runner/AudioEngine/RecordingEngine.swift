import AVFoundation
import Accelerate

/// Recording engine with real-time onset detection.
/// Uses AVAudioEngine input tap for low-latency mic capture
/// and energy-based onset detection for timing analysis.
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

    // Callback to send events to Flutter
    private let onEvent: ([String: Any]) -> Void

    // Recording file path
    private var currentFilePath: String?

    init(onEvent: @escaping ([String: Any]) -> Void) {
        self.onEvent = onEvent
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("RecordingEngine: AudioSession error: \(error)")
            return
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Create output file
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

        // Install tap on input for recording + onset detection
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

        onEvent([
            "type": "recordingState",
            "isRecording": true,
            "durationMs": 0,
        ])
    }

    func stopRecording() -> String? {
        guard isRecording else { return nil }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        isRecording = false

        onEvent([
            "type": "recordingState",
            "isRecording": false,
            "durationMs": 0,
            "filePath": currentFilePath ?? "",
        ])

        return currentFilePath
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Write to file
        if let file = audioFile {
            do {
                try file.write(from: buffer)
            } catch {
                print("RecordingEngine: Write error: \(error)")
            }
        }

        // Onset detection
        if onsetDetectionEnabled {
            detectOnset(buffer: buffer, time: time)
        }
    }

    // MARK: - Onset Detection

    /// Energy-based onset detection with spectral flux.
    /// Detects sudden increases in audio energy (transients)
    /// that correspond to note attacks.
    private func detectOnset(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let data = channelData[0]

        // Calculate RMS energy of this buffer
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(frameCount))

        // Calculate spectral flux (energy increase)
        let flux = max(0, rms - previousEnergy)
        previousEnergy = rms

        // Maintain running average for adaptive threshold
        energyHistory.append(flux)
        if energyHistory.count > energyHistorySize {
            energyHistory.removeFirst()
        }

        let avgFlux = energyHistory.reduce(0, +) / Float(energyHistory.count)
        let adaptiveThreshold = max(Float(onsetThreshold), avgFlux * 2.5)

        // Check if this is an onset
        if flux > adaptiveThreshold {
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)
            let nsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)

            let nowHost = mach_absolute_time()
            let nowNs = Double(nowHost) * nsPerTick
            let lastNs = Double(lastOnsetTime) * nsPerTick
            let elapsedMs = (nowNs - lastNs) / 1_000_000

            // Enforce minimum interval between onsets
            if lastOnsetTime == 0 || elapsedMs >= Double(minOnsetIntervalMs) {
                lastOnsetTime = nowHost
                let timestampUs = Int(nowNs / 1000)

                // Calculate amplitude (peak in this buffer)
                var peak: Float = 0
                vDSP_maxv(data, 1, &peak, vDSP_Length(frameCount))
                let amplitude = min(1.0, Double(peak))

                onEvent([
                    "type": "onset",
                    "timestampUs": timestampUs,
                    "amplitude": amplitude,
                ])
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
        return AVAudioSession.sharedInstance().inputLatency * 1000.0 // ms
    }
}
