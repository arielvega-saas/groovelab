import AVFoundation
import Accelerate

/// Real-time pitch detection engine using AVAudioEngine and autocorrelation.
/// Sends tunerPitch events back to Flutter via the event sink.
final class TunerEngine {
    private var audioEngine: AVAudioEngine?
    private var isRunning = false

    private let onEvent: ([String: Any]) -> Void

    // ── Configuration ──
    private let bufferSize: AVAudioFrameCount = 2048
    private let targetSampleRate: Double = 44100
    private let clarityThreshold: Float = 0.85
    private let rmsThreshold: Float = 0.005
    private let minFrequency: Float = 60    // Hz
    private let maxFrequency: Float = 1400  // Hz

    // ── Note names for pitch-to-note conversion ──
    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    init(onEvent: @escaping ([String: Any]) -> Void) {
        self.onEvent = onEvent
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        // Use the hardware format directly for the tap
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hwFormat.sampleRate,
            channels: 1,
            interleaved: false
        )!

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try engine.start()
            audioEngine = engine
            isRunning = true
        } catch {
            print("TunerEngine: Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
        }
    }

    func stop() {
        guard isRunning, let engine = audioEngine else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioEngine = nil
        isRunning = false
    }

    // MARK: - Audio Processing

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        let sampleRate = Float(buffer.format.sampleRate)

        // 1. RMS check - skip silence
        let rms = computeRMS(samples)
        guard rms > rmsThreshold else { return }

        // 2. Autocorrelation pitch detection
        let (pitch, clarity) = autoCorrelate(buffer: samples, sampleRate: sampleRate)

        // 3. Filter by clarity and frequency range
        guard clarity >= clarityThreshold,
              pitch >= minFrequency,
              pitch <= maxFrequency else { return }

        // 4. Convert to note info
        let (noteName, octave, cents) = pitchToNote(frequency: pitch)

        // 5. Send event to Flutter
        let event: [String: Any] = [
            "type": "tunerPitch",
            "pitch": Double(pitch),
            "clarity": Double(clarity),
            "note": noteName,
            "octave": octave,
            "cents": Double(cents),
            "frequency": Double(pitch),
        ]
        onEvent(event)
    }

    // MARK: - RMS Calculation

    private func computeRMS(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }

    // MARK: - Autocorrelation Pitch Detection

    private func autoCorrelate(buffer: [Float], sampleRate: Float) -> (pitch: Float, clarity: Float) {
        let size = buffer.count

        // Minimum and maximum lags based on frequency range
        let minLag = Int(sampleRate / maxFrequency)
        let maxLag = min(Int(sampleRate / minFrequency), size / 2)

        guard maxLag > minLag else { return (-1, 0) }

        // Find the first positive-going zero crossing to skip initial transient
        var startIndex = 0
        for i in 0..<(size / 2) {
            if buffer[i] < 0 && buffer[i + 1] >= 0 {
                startIndex = i + 1
                break
            }
        }

        let trimmedSize = size - startIndex
        guard trimmedSize > maxLag else { return (-1, 0) }

        // Compute normalized autocorrelation using Accelerate
        var correlations = [Float](repeating: 0, count: maxLag - minLag + 1)
        let trimmedBuffer = Array(buffer[startIndex...])

        // Compute energy at lag 0 for normalization
        var energy0: Float = 0
        vDSP_dotpr(trimmedBuffer, 1, trimmedBuffer, 1, &energy0, vDSP_Length(min(trimmedSize, maxLag * 2)))
        guard energy0 > 0 else { return (-1, 0) }

        // Compute autocorrelation for each lag
        for i in 0..<correlations.count {
            let lag = i + minLag
            let len = trimmedSize - lag
            guard len > 0 else { continue }

            var correlation: Float = 0
            vDSP_dotpr(trimmedBuffer, 1,
                       Array(trimmedBuffer[lag...]), 1,
                       &correlation,
                       vDSP_Length(len))

            // Compute energy at this lag for normalization
            var energyLag: Float = 0
            let lagSlice = Array(trimmedBuffer[lag..<(lag + len)])
            vDSP_dotpr(lagSlice, 1, lagSlice, 1, &energyLag, vDSP_Length(len))

            let denom = sqrt(energy0 * energyLag)
            correlations[i] = denom > 0 ? correlation / denom : 0
        }

        // Find the best peak in the autocorrelation
        var bestCorrelation: Float = 0
        var bestLagIndex = 0

        for i in 1..<(correlations.count - 1) {
            if correlations[i] > bestCorrelation &&
               correlations[i] > correlations[i - 1] &&
               correlations[i] > correlations[i + 1] {
                bestCorrelation = correlations[i]
                bestLagIndex = i
            }
        }

        guard bestCorrelation > 0 else { return (-1, 0) }

        // Parabolic interpolation for sub-sample accuracy
        let bestLag = bestLagIndex + minLag
        var refinedLag = Float(bestLag)

        if bestLagIndex > 0 && bestLagIndex < correlations.count - 1 {
            let prev = correlations[bestLagIndex - 1]
            let curr = correlations[bestLagIndex]
            let next = correlations[bestLagIndex + 1]
            let denom = 2.0 * curr - prev - next
            if abs(denom) > 1e-10 {
                let delta = (prev - next) / (2.0 * denom)
                refinedLag = Float(bestLag) + delta
            }
        }

        guard refinedLag > 0 else { return (-1, 0) }

        let frequency = sampleRate / refinedLag
        return (frequency, bestCorrelation)
    }

    // MARK: - Pitch to Note Conversion

    private func pitchToNote(frequency: Float) -> (name: String, octave: Int, cents: Float) {
        // A4 = 440 Hz, MIDI note 69
        let midiNote = 12.0 * log2(Double(frequency) / 440.0) + 69.0
        let roundedMidi = Int(round(midiNote))
        let cents = Float((midiNote - Double(roundedMidi)) * 100.0)

        let noteIndex = ((roundedMidi % 12) + 12) % 12
        let octave = (roundedMidi / 12) - 1

        return (TunerEngine.noteNames[noteIndex], octave, cents)
    }
}
