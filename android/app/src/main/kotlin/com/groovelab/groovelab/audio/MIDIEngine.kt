package com.groovelab.groovelab.audio

import android.content.Context
import android.media.midi.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/**
 * Android MIDI engine for GrooveLab.
 * Supports MIDI input/output, device discovery, MIDI clock send/receive.
 * Compatible with USB MIDI, Bluetooth MIDI, and virtual MIDI.
 */
class MIDIEngine(
    private val context: Context,
    private val onEvent: (Map<String, Any>) -> Unit
) {
    companion object {
        private const val TAG = "MIDIEngine"
    }

    private var midiManager: MidiManager? = null
    private var openDevices: MutableList<MidiDevice> = mutableListOf()
    private var inputPorts: MutableList<MidiInputPort> = mutableListOf()
    private var outputReceivers: MutableList<MidiOutputPort> = mutableListOf()
    private var isInitialized = false

    // MIDI Clock
    private val scheduler = Executors.newSingleThreadScheduledExecutor()
    private var clockFuture: ScheduledFuture<*>? = null
    private var clockBpm: Double = 120.0
    @Volatile private var isSendingClock = false

    fun initialize(): Boolean {
        if (isInitialized) return true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Log.w(TAG, "MIDI not supported below Android 6.0")
            return false
        }

        midiManager = context.getSystemService(Context.MIDI_SERVICE) as? MidiManager
        if (midiManager == null) {
            Log.e(TAG, "MIDI not available on this device")
            return false
        }

        // Register device callback for hot-plug
        midiManager?.registerDeviceCallback(object : MidiManager.DeviceCallback() {
            override fun onDeviceAdded(device: MidiDeviceInfo) {
                Handler(Looper.getMainLooper()).post {
                    onEvent(mapOf(
                        "type" to "midiDeviceChange",
                        "action" to "added",
                        "devices" to listDevices()
                    ))
                }
            }
            override fun onDeviceRemoved(device: MidiDeviceInfo) {
                Handler(Looper.getMainLooper()).post {
                    onEvent(mapOf(
                        "type" to "midiDeviceChange",
                        "action" to "removed",
                        "devices" to listDevices()
                    ))
                }
            }
        }, Handler(Looper.getMainLooper()))

        isInitialized = true
        Log.d(TAG, "MIDI initialized")
        return true
    }

    fun listDevices(): List<Map<String, Any>> {
        val manager = midiManager ?: return emptyList()
        return manager.devices.map { info ->
            val props = info.properties
            mapOf(
                "name" to (props.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "Unknown"),
                "manufacturer" to (props.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER) ?: ""),
                "id" to info.id,
                "inputCount" to info.inputPortCount,
                "outputCount" to info.outputPortCount,
                "type" to when (info.type) {
                    MidiDeviceInfo.TYPE_USB -> "usb"
                    MidiDeviceInfo.TYPE_BLUETOOTH -> "bluetooth"
                    MidiDeviceInfo.TYPE_VIRTUAL -> "virtual"
                    else -> "unknown"
                }
            )
        }
    }

    fun connectToDevice(deviceId: Int) {
        val manager = midiManager ?: return
        val deviceInfo = manager.devices.find { it.id == deviceId } ?: return

        manager.openDevice(deviceInfo, { device ->
            if (device == null) {
                Log.e(TAG, "Failed to open MIDI device $deviceId")
                return@openDevice
            }
            openDevices.add(device)

            // Open input ports (for sending MIDI TO the device)
            for (i in 0 until device.info.inputPortCount) {
                val port = device.openInputPort(i)
                if (port != null) inputPorts.add(port)
            }

            // Open output ports (for receiving MIDI FROM the device)
            for (i in 0 until device.info.outputPortCount) {
                val port = device.openOutputPort(i)
                if (port != null) {
                    outputReceivers.add(port)
                    port.connect(object : MidiReceiver() {
                        override fun onSend(data: ByteArray, offset: Int, count: Int, timestamp: Long) {
                            processMidiData(data, offset, count)
                        }
                    })
                }
            }

            Log.d(TAG, "Connected to MIDI device: ${deviceInfo.properties.getString(MidiDeviceInfo.PROPERTY_NAME)}")
        }, Handler(Looper.getMainLooper()))
    }

    // MARK: - Send MIDI

    fun sendNoteOn(note: Int, velocity: Int, channel: Int = 0) {
        sendBytes(byteArrayOf(
            (0x90 or (channel and 0x0F)).toByte(),
            (note and 0x7F).toByte(),
            (velocity and 0x7F).toByte()
        ))
    }

    fun sendNoteOff(note: Int, channel: Int = 0) {
        sendBytes(byteArrayOf(
            (0x80 or (channel and 0x0F)).toByte(),
            (note and 0x7F).toByte(),
            0
        ))
    }

    fun sendCC(controller: Int, value: Int, channel: Int = 0) {
        sendBytes(byteArrayOf(
            (0xB0 or (channel and 0x0F)).toByte(),
            (controller and 0x7F).toByte(),
            (value and 0x7F).toByte()
        ))
    }

    fun sendProgramChange(program: Int, channel: Int = 0) {
        sendBytes(byteArrayOf(
            (0xC0 or (channel and 0x0F)).toByte(),
            (program and 0x7F).toByte()
        ))
    }

    private fun sendBytes(data: ByteArray) {
        for (port in inputPorts) {
            try {
                port.send(data, 0, data.size)
            } catch (e: Exception) {
                Log.e(TAG, "Send MIDI error: $e")
            }
        }
    }

    // MARK: - MIDI Clock

    fun startClock(bpm: Double) {
        stopClock()
        clockBpm = bpm
        isSendingClock = true

        // Send MIDI Start
        sendBytes(byteArrayOf(0xFA.toByte()))

        // 24 ppq clock
        val intervalUs = ((60_000_000.0 / bpm / 24.0)).toLong()
        clockFuture = scheduler.scheduleAtFixedRate({
            if (isSendingClock) {
                sendBytes(byteArrayOf(0xF8.toByte()))
            }
        }, 0, intervalUs, TimeUnit.MICROSECONDS)
    }

    fun stopClock() {
        isSendingClock = false
        clockFuture?.cancel(false)
        clockFuture = null
        sendBytes(byteArrayOf(0xFC.toByte())) // MIDI Stop
    }

    fun updateClockBpm(bpm: Double) {
        if (isSendingClock) {
            startClock(bpm)
        } else {
            clockBpm = bpm
        }
    }

    // MARK: - Receive Processing

    private fun processMidiData(data: ByteArray, offset: Int, count: Int) {
        var i = offset
        while (i < offset + count) {
            val status = data[i].toInt() and 0xFF
            val msgType = status and 0xF0
            val channel = status and 0x0F

            val event = mutableMapOf<String, Any>(
                "type" to "midi",
                "status" to status,
                "channel" to channel
            )

            when {
                msgType == 0x90 && i + 2 < offset + count -> {
                    val note = data[i + 1].toInt() and 0x7F
                    val vel = data[i + 2].toInt() and 0x7F
                    event["kind"] = if (vel > 0) "noteOn" else "noteOff"
                    event["note"] = note
                    event["velocity"] = vel
                    i += 3
                }
                msgType == 0x80 && i + 2 < offset + count -> {
                    event["kind"] = "noteOff"
                    event["note"] = data[i + 1].toInt() and 0x7F
                    event["velocity"] = data[i + 2].toInt() and 0x7F
                    i += 3
                }
                msgType == 0xB0 && i + 2 < offset + count -> {
                    event["kind"] = "cc"
                    event["controller"] = data[i + 1].toInt() and 0x7F
                    event["value"] = data[i + 2].toInt() and 0x7F
                    i += 3
                }
                msgType == 0xC0 && i + 1 < offset + count -> {
                    event["kind"] = "programChange"
                    event["program"] = data[i + 1].toInt() and 0x7F
                    i += 2
                }
                status == 0xF8 -> { event["kind"] = "clock"; i += 1 }
                status == 0xFA -> { event["kind"] = "start"; i += 1 }
                status == 0xFB -> { event["kind"] = "continue"; i += 1 }
                status == 0xFC -> { event["kind"] = "stop"; i += 1 }
                else -> { i += 1 }
            }

            Handler(Looper.getMainLooper()).post { onEvent(event) }
        }
    }

    // MARK: - Cleanup

    fun dispose() {
        stopClock()
        for (port in inputPorts) { try { port.close() } catch (_: Exception) {} }
        for (port in outputReceivers) { try { port.close() } catch (_: Exception) {} }
        for (device in openDevices) { try { device.close() } catch (_: Exception) {} }
        inputPorts.clear()
        outputReceivers.clear()
        openDevices.clear()
        isInitialized = false
        Log.d(TAG, "MIDI disposed")
    }
}
