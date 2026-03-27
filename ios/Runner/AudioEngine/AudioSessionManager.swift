import AVFoundation
import UIKit

/// Manages AVAudioSession configuration for professional audio use.
/// Handles audio route changes, interruptions, and background audio.
final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private var isConfigured = false
    private var onRouteChange: (([String: Any]) -> Void)?

    private init() {}

    // MARK: - Configuration

    /// Configure audio session for professional use with low latency.
    func configure(onRouteChange: (([String: Any]) -> Void)? = nil) {
        guard !isConfigured else { return }
        self.onRouteChange = onRouteChange

        let session = AVAudioSession.sharedInstance()

        do {
            // PlayAndRecord: enables mic input + speaker output simultaneously
            // Options:
            //   .defaultToSpeaker — route to speaker when no headphones
            //   .allowBluetooth — support BT headphones
            //   .allowBluetoothA2DP — better quality BT audio
            //   .mixWithOthers — allow other apps' audio to continue
            try session.setCategory(
                .playAndRecord,
                mode: .measurement, // Low-latency, minimal processing
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .mixWithOthers,
                ]
            )

            // 10ms buffer: optimal balance between low latency and stability
            // Avoids underruns on older/loaded devices while staying imperceptible (<15ms total)
            try session.setPreferredIOBufferDuration(0.010)
            // Use device-preferred sample rate to avoid resampling overhead
            // Most modern iOS devices prefer 48kHz; forcing 44.1kHz wastes CPU
            let deviceRate = session.preferredSampleRate
            if deviceRate > 0 {
                try session.setPreferredSampleRate(deviceRate)
            }

            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // Register for notifications
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleRouteChange),
                name: AVAudioSession.routeChangeNotification, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleInterruption),
                name: AVAudioSession.interruptionNotification, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleMediaServicesReset),
                name: AVAudioSession.mediaServicesWereResetNotification, object: nil
            )

            isConfigured = true

            let actualBufferDuration = session.ioBufferDuration
            let actualSampleRate = session.sampleRate
            let actualLatency = session.outputLatency + session.inputLatency
            print("AudioSessionManager: Configured")
            print("  Buffer: \(String(format: "%.1f", actualBufferDuration * 1000))ms")
            print("  Sample rate: \(actualSampleRate)Hz")
            print("  Round-trip latency: \(String(format: "%.1f", actualLatency * 1000))ms")
            print("  Current route: \(session.currentRoute.outputs.map { $0.portName })")

        } catch {
            print("AudioSessionManager: Configuration error: \(error)")
        }
    }

    // MARK: - Audio Route Info

    func getCurrentRoute() -> [String: Any] {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute

        let inputs = route.inputs.map { port -> [String: Any] in
            return [
                "name": port.portName,
                "type": port.portType.rawValue,
                "uid": port.uid,
                "channels": port.channels?.count ?? 0,
            ]
        }

        let outputs = route.outputs.map { port -> [String: Any] in
            return [
                "name": port.portName,
                "type": port.portType.rawValue,
                "uid": port.uid,
                "channels": port.channels?.count ?? 0,
            ]
        }

        return [
            "inputs": inputs,
            "outputs": outputs,
            "sampleRate": session.sampleRate,
            "bufferDuration": session.ioBufferDuration * 1000, // ms
            "outputLatency": session.outputLatency * 1000, // ms
            "inputLatency": session.inputLatency * 1000, // ms
            "isOtherAudioPlaying": session.isOtherAudioPlaying,
        ]
    }

    func getAvailableInputs() -> [[String: Any]] {
        let session = AVAudioSession.sharedInstance()
        return (session.availableInputs ?? []).map { port in
            return [
                "name": port.portName,
                "type": port.portType.rawValue,
                "uid": port.uid,
                "channels": port.channels?.count ?? 0,
                "dataSources": port.dataSources?.map { $0.dataSourceName } ?? [],
            ]
        }
    }

    func setPreferredInput(_ uid: String) -> Bool {
        let session = AVAudioSession.sharedInstance()
        guard let input = session.availableInputs?.first(where: { $0.uid == uid }) else {
            return false
        }
        do {
            try session.setPreferredInput(input)
            return true
        } catch {
            print("AudioSessionManager: setPreferredInput error: \(error)")
            return false
        }
    }

    func setBufferDuration(_ durationMs: Double) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredIOBufferDuration(durationMs / 1000.0)
        } catch {
            print("AudioSessionManager: setBufferDuration error: \(error)")
        }
    }

    // MARK: - Notification Handlers

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute

        var reasonStr = "unknown"
        switch reason {
        case .newDeviceAvailable: reasonStr = "newDevice"
        case .oldDeviceUnavailable: reasonStr = "deviceRemoved"
        case .categoryChange: reasonStr = "categoryChange"
        case .override: reasonStr = "override"
        case .routeConfigurationChange: reasonStr = "configChange"
        default: break
        }

        let event: [String: Any] = [
            "type": "audioRouteChange",
            "reason": reasonStr,
            "currentOutputs": route.outputs.map { $0.portName },
            "currentInputs": route.inputs.map { $0.portName },
            "latencyMs": (session.outputLatency + session.inputLatency) * 1000,
        ]

        DispatchQueue.main.async { [weak self] in
            self?.onRouteChange?(event)
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            print("AudioSessionManager: Interruption began (call, alarm, etc)")
            onRouteChange?([
                "type": "audioInterruption",
                "action": "began",
            ])
        case .ended:
            let options = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            print("AudioSessionManager: Interruption ended, shouldResume: \(shouldResume)")

            if shouldResume {
                try? AVAudioSession.sharedInstance().setActive(true)
            }

            onRouteChange?([
                "type": "audioInterruption",
                "action": "ended",
                "shouldResume": shouldResume,
            ])
        @unknown default:
            break
        }
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        print("AudioSessionManager: Media services were reset — rebuilding audio")
        isConfigured = false
        configure(onRouteChange: onRouteChange)
        onRouteChange?([
            "type": "audioReset",
        ])
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
