import CoreMIDI
import AVFoundation

/// CoreMIDI engine for GrooveLab.
/// Enables MIDI input/output for integration with MainStage, Logic Pro, Ableton, etc.
/// Supports MIDI Clock send/receive, Note input, CC mapping, and Network MIDI.
final class MIDIEngine {
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0
    private var virtualSource: MIDIEndpointRef = 0
    private var virtualDestination: MIDIEndpointRef = 0
    private var connectedSources: Set<MIDIEndpointRef> = []

    // MIDI Clock
    private var clockTimer: DispatchSourceTimer?
    private var isSendingClock = false
    private var clockBpm: Double = 120.0

    // Callbacks
    private let onEvent: ([String: Any]) -> Void

    // State
    private var isInitialized = false

    init(onEvent: @escaping ([String: Any]) -> Void) {
        self.onEvent = onEvent
    }

    // MARK: - Initialization

    func initialize() -> Bool {
        guard !isInitialized else { return true }

        var status: OSStatus

        // Create MIDI client
        status = MIDIClientCreateWithBlock("GrooveLab" as CFString, &midiClient) { [weak self] notification in
            self?.handleMIDINotification(notification)
        }
        guard status == noErr else {
            print("MIDIEngine: Failed to create client: \(status)")
            return false
        }

        // Create input port for receiving MIDI
        status = MIDIInputPortCreateWithProtocol(
            midiClient,
            "GrooveLab Input" as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, srcConnRefCon in
            self?.handleMIDIEventList(eventList)
        }
        guard status == noErr else {
            print("MIDIEngine: Failed to create input port: \(status)")
            return false
        }

        // Create output port for sending MIDI
        status = MIDIOutputPortCreate(midiClient, "GrooveLab Output" as CFString, &outputPort)
        guard status == noErr else {
            print("MIDIEngine: Failed to create output port: \(status)")
            return false
        }

        // Create virtual source (so other apps can receive from GrooveLab)
        status = MIDISourceCreateWithProtocol(
            midiClient,
            "GrooveLab" as CFString,
            ._1_0,
            &virtualSource
        )
        if status != noErr {
            print("MIDIEngine: Warning - Failed to create virtual source: \(status)")
        }

        // Create virtual destination (so other apps can send to GrooveLab)
        status = MIDIDestinationCreateWithProtocol(
            midiClient,
            "GrooveLab" as CFString,
            ._1_0,
            &virtualDestination
        ) { [weak self] eventList, srcConnRefCon in
            self?.handleMIDIEventList(eventList)
        }
        if status != noErr {
            print("MIDIEngine: Warning - Failed to create virtual destination: \(status)")
        }

        // Enable Network MIDI session
        let networkSession = MIDINetworkSession.default()
        networkSession.isEnabled = true
        networkSession.connectionPolicy = .anyone

        // Connect to all existing sources
        connectToAllSources()

        isInitialized = true
        print("MIDIEngine: Initialized with \(getSourceCount()) sources, \(getDestinationCount()) destinations")
        return true
    }

    // MARK: - Device Discovery

    func getSourceCount() -> Int {
        return MIDIGetNumberOfSources()
    }

    func getDestinationCount() -> Int {
        return MIDIGetNumberOfDestinations()
    }

    func listDevices() -> [[String: Any]] {
        var devices: [[String: Any]] = []

        // List sources (input devices)
        for i in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(i)
            if let info = getEndpointInfo(endpoint) {
                var device = info
                device["direction"] = "input"
                device["index"] = i
                device["connected"] = connectedSources.contains(endpoint)
                devices.append(device)
            }
        }

        // List destinations (output devices)
        for i in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(i)
            if let info = getEndpointInfo(endpoint) {
                var device = info
                device["direction"] = "output"
                device["index"] = i
                devices.append(device)
            }
        }

        return devices
    }

    private func getEndpointInfo(_ endpoint: MIDIEndpointRef) -> [String: Any]? {
        guard endpoint != 0 else { return nil }

        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        let displayName = (name?.takeRetainedValue() as String?) ?? "Unknown"

        var manufacturer: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)
        let mfr = (manufacturer?.takeRetainedValue() as String?) ?? ""

        var uniqueID: Int32 = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)

        return [
            "name": displayName,
            "manufacturer": mfr,
            "uniqueId": Int(uniqueID),
            "endpointRef": Int(endpoint),
        ]
    }

    // MARK: - Connection Management

    func connectToAllSources() {
        for i in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(i)
            connectToSource(source)
        }
    }

    func connectToSource(_ source: MIDIEndpointRef) {
        guard source != virtualDestination else { return } // Don't connect to ourselves
        let status = MIDIPortConnectSource(inputPort, source, nil)
        if status == noErr {
            connectedSources.insert(source)
        }
    }

    func disconnectFromSource(_ source: MIDIEndpointRef) {
        MIDIPortDisconnectSource(inputPort, source)
        connectedSources.remove(source)
    }

    // MARK: - MIDI Sending

    func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        let status: UInt8 = 0x90 | (channel & 0x0F)
        sendMessage([status, note, velocity])
    }

    func sendNoteOff(note: UInt8, channel: UInt8 = 0) {
        let status: UInt8 = 0x80 | (channel & 0x0F)
        sendMessage([status, note, 0])
    }

    func sendCC(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        let status: UInt8 = 0xB0 | (channel & 0x0F)
        sendMessage([status, controller, value])
    }

    func sendProgramChange(program: UInt8, channel: UInt8 = 0) {
        let status: UInt8 = 0xC0 | (channel & 0x0F)
        sendMessage([status, program])
    }

    private func sendMessage(_ bytes: [UInt8]) {
        // Send to all destinations
        for i in 0..<MIDIGetNumberOfDestinations() {
            let dest = MIDIGetDestination(i)
            sendToEndpoint(dest, bytes: bytes)
        }

        // Also send via virtual source
        if virtualSource != 0 {
            sendViaSource(bytes)
        }
    }

    private func sendToEndpoint(_ dest: MIDIEndpointRef, bytes: [UInt8]) {
        var packet = MIDIPacket()
        packet.timeStamp = mach_absolute_time()
        packet.length = UInt16(bytes.count)
        withUnsafeMutablePointer(to: &packet.data) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            for (i, byte) in bytes.enumerated() {
                raw.storeBytes(of: byte, toByteOffset: i, as: UInt8.self)
            }
        }

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        MIDISend(outputPort, dest, &packetList)
    }

    private func sendViaSource(_ bytes: [UInt8]) {
        var packet = MIDIPacket()
        packet.timeStamp = mach_absolute_time()
        packet.length = UInt16(bytes.count)
        withUnsafeMutablePointer(to: &packet.data) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            for (i, byte) in bytes.enumerated() {
                raw.storeBytes(of: byte, toByteOffset: i, as: UInt8.self)
            }
        }

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        MIDIReceived(virtualSource, &packetList)
    }

    // MARK: - MIDI Clock

    func startClock(bpm: Double) {
        stopClock()
        clockBpm = bpm
        isSendingClock = true

        // Send MIDI Start (0xFA)
        sendMessage([0xFA])

        // MIDI Clock sends 24 pulses per quarter note
        let pulsesPerBeat: Double = 24.0
        let intervalNs = UInt64((60.0 / bpm / pulsesPerBeat) * 1_000_000_000)

        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .nanoseconds(Int(intervalNs)), leeway: .nanoseconds(0))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isSendingClock else { return }
            // MIDI Clock tick (0xF8)
            self.sendMessage([0xF8])
        }
        timer.resume()
        clockTimer = timer
    }

    func stopClock() {
        isSendingClock = false
        clockTimer?.cancel()
        clockTimer = nil
        // Send MIDI Stop (0xFC)
        sendMessage([0xFC])
    }

    func updateClockBpm(_ bpm: Double) {
        guard isSendingClock else {
            clockBpm = bpm
            return
        }
        // Restart clock with new BPM
        startClock(bpm: bpm)
    }

    // MARK: - MIDI Receive Handling

    private func handleMIDIEventList(_ eventList: UnsafePointer<MIDIEventList>) {
        let list = eventList.pointee
        // Use the modern Swift iteration for MIDIEventList
        eventList.unsafeSequence().forEach { event in
            let wordCount = Int(event.pointee.wordCount)
            guard wordCount > 0 else { return }
            // Read words from the packet
            withUnsafePointer(to: event.pointee.words) { ptr in
                ptr.withMemoryRebound(to: UInt32.self, capacity: wordCount) { wordsPtr in
                    for i in 0..<wordCount {
                        processMIDI1Word(wordsPtr[i])
                    }
                }
            }
        }
    }

    private func processMIDI1Word(_ word: UInt32) {
        // Universal MIDI Packet format (UMP) for MIDI 1.0
        let messageType = (word >> 28) & 0x0F
        guard messageType == 0x02 else { return } // MIDI 1.0 Channel Voice

        let status = UInt8((word >> 16) & 0xFF)
        let data1 = UInt8((word >> 8) & 0x7F)
        let data2 = UInt8(word & 0x7F)

        let messageKind = status & 0xF0
        let channel = status & 0x0F

        var eventDict: [String: Any] = [
            "type": "midi",
            "status": Int(status),
            "channel": Int(channel),
            "data1": Int(data1),
            "data2": Int(data2),
        ]

        switch messageKind {
        case 0x90: // Note On
            if data2 > 0 {
                eventDict["kind"] = "noteOn"
                eventDict["note"] = Int(data1)
                eventDict["velocity"] = Int(data2)
            } else {
                // Note On with velocity 0 = Note Off
                eventDict["kind"] = "noteOff"
                eventDict["note"] = Int(data1)
                eventDict["velocity"] = 0
            }
        case 0x80: // Note Off
            eventDict["kind"] = "noteOff"
            eventDict["note"] = Int(data1)
            eventDict["velocity"] = Int(data2)
        case 0xB0: // Control Change
            eventDict["kind"] = "cc"
            eventDict["controller"] = Int(data1)
            eventDict["value"] = Int(data2)
        case 0xC0: // Program Change
            eventDict["kind"] = "programChange"
            eventDict["program"] = Int(data1)
        case 0xE0: // Pitch Bend
            let bendValue = (Int(data2) << 7) | Int(data1)
            eventDict["kind"] = "pitchBend"
            eventDict["value"] = bendValue - 8192 // center at 0
        default:
            eventDict["kind"] = "other"
        }

        // Real-time messages (system)
        if status == 0xF8 { // Clock
            eventDict["kind"] = "clock"
        } else if status == 0xFA { // Start
            eventDict["kind"] = "start"
        } else if status == 0xFB { // Continue
            eventDict["kind"] = "continue"
        } else if status == 0xFC { // Stop
            eventDict["kind"] = "stop"
        }

        DispatchQueue.main.async { [weak self] in
            self?.onEvent(eventDict)
        }
    }

    // MARK: - MIDI Setup Change Notification

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        let messageID = notification.pointee.messageID

        switch messageID {
        case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved:
            // Reconnect to any new sources
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.connectToAllSources()
                self?.onEvent([
                    "type": "midiDeviceChange",
                    "devices": self?.listDevices() ?? [],
                ])
            }
        default:
            break
        }
    }

    // MARK: - Cleanup

    func dispose() {
        stopClock()

        for source in connectedSources {
            MIDIPortDisconnectSource(inputPort, source)
        }
        connectedSources.removeAll()

        if virtualSource != 0 { MIDIEndpointDispose(virtualSource) }
        if virtualDestination != 0 { MIDIEndpointDispose(virtualDestination) }
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if midiClient != 0 { MIDIClientDispose(midiClient) }

        isInitialized = false
        print("MIDIEngine: Disposed")
    }
}
