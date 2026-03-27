package com.groovelab.groovelab.audio

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class GrooveLabAudioPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var metronomeEngine: MetronomeEngine? = null
    private var recordingEngine: RecordingEngine? = null
    private var pedaleraEngine: PedaleraEngine? = null
    private var midiEngine: MIDIEngine? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "com.groovelab/audio_engine")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "com.groovelab/audio_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        metronomeEngine?.stop()
        recordingEngine?.stopRecording()
        pedaleraEngine?.stop()
        midiEngine?.dispose()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                metronomeEngine = MetronomeEngine { event ->
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        eventSink?.success(event)
                    }
                }
                recordingEngine = RecordingEngine(context!!) { event ->
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        eventSink?.success(event)
                    }
                }
                metronomeEngine?.initialize()
                result.success(null)
            }
            "loadSound" -> {
                val key = call.argument<String>("key") ?: return result.error("INVALID_ARGS", "Missing key", null)
                val data = call.argument<ByteArray>("data") ?: return result.error("INVALID_ARGS", "Missing data", null)
                metronomeEngine?.loadSound(key, data)
                result.success(null)
            }
            "playSound" -> {
                val key = call.argument<String>("key") ?: "kick"
                metronomeEngine?.playSingleHit(key)
                result.success(null)
            }
            "startMetronome" -> {
                val bpm = call.argument<Int>("bpm") ?: 120
                val beatsPerBar = call.argument<Int>("beatsPerBar") ?: 4
                val beatUnit = call.argument<Int>("beatUnit") ?: 4
                val subdivision = call.argument<Int>("subdivision") ?: 1
                val swing = call.argument<Int>("swingPercent") ?: 0
                val clickSound = call.argument<String>("clickSound") ?: "Wood"
                val accents = call.argument<List<Double>>("accentPattern") ?: listOf(1.0, 0.7, 0.7, 0.7)
                val haptic = call.argument<Boolean>("hapticEnabled") ?: false
                metronomeEngine?.start(bpm, beatsPerBar, beatUnit, subdivision, swing, clickSound, accents, haptic)
                result.success(null)
            }
            "stopMetronome" -> { metronomeEngine?.stop(); result.success(null) }
            "updateBpm" -> { call.argument<Int>("bpm")?.let { metronomeEngine?.updateBpm(it) }; result.success(null) }
            "updateTimeSignature" -> {
                val beats = call.argument<Int>("beatsPerBar") ?: return result.success(null)
                val unit = call.argument<Int>("beatUnit") ?: return result.success(null)
                metronomeEngine?.updateTimeSignature(beats, unit)
                result.success(null)
            }
            "updateSubdivision" -> { call.argument<Int>("subdivision")?.let { metronomeEngine?.updateSubdivision(it) }; result.success(null) }
            "updateSwing" -> { call.argument<Int>("swingPercent")?.let { metronomeEngine?.updateSwing(it) }; result.success(null) }
            "updateClickSound" -> { call.argument<String>("clickSound")?.let { metronomeEngine?.updateClickSound(it) }; result.success(null) }
            "updateAccentPattern" -> { call.argument<List<Double>>("pattern")?.let { metronomeEngine?.updateAccentPattern(it) }; result.success(null) }
            "setHapticMode" -> { call.argument<Boolean>("enabled")?.let { metronomeEngine?.setHapticMode(it) }; result.success(null) }
            "updateHumanFeel" -> { call.argument<Int>("percent")?.let { metronomeEngine?.updateHumanFeel(it) }; result.success(null) }
            "updatePolyrhythm" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val value = call.argument<Int>("value") ?: 3
                metronomeEngine?.updatePolyrhythm(enabled, value)
                result.success(null)
            }
            "startDrumPattern" -> {
                val bpm = call.argument<Int>("bpm") ?: 120
                val pattern = call.argument<Map<String, List<Int>>>("pattern") ?: emptyMap()
                val swing = call.argument<Int>("swingPercent") ?: 0
                metronomeEngine?.startDrumPattern(bpm, pattern, swing)
                result.success(null)
            }
            "stopDrumPattern" -> { metronomeEngine?.stop(); result.success(null) }
            "updateDrumPattern" -> {
                call.argument<Map<String, List<Int>>>("pattern")?.let { metronomeEngine?.updateDrumPattern(it) }
                result.success(null)
            }
            "updateDrumVolumes" -> {
                call.argument<Map<String, Double>>("volumes")?.let { metronomeEngine?.updateDrumVolumes(it) }
                result.success(null)
            }
            "startRecording" -> { recordingEngine?.startRecording(); result.success(null) }
            "stopRecording" -> { result.success(recordingEngine?.stopRecording()) }
            "enableOnsetDetection" -> {
                val threshold = call.argument<Double>("threshold") ?: 0.1
                val minInterval = call.argument<Int>("minIntervalMs") ?: 50
                recordingEngine?.enableOnsetDetection(threshold, minInterval)
                result.success(null)
            }
            "disableOnsetDetection" -> { recordingEngine?.disableOnsetDetection(); result.success(null) }
            "getOutputLatency" -> { result.success(metronomeEngine?.getOutputLatency() ?: 0.0) }
            "getInputLatency" -> { result.success(recordingEngine?.getInputLatency() ?: 0.0) }
            // ── Pedalera ──
            "initPedalera" -> {
                if (pedaleraEngine == null) {
                    pedaleraEngine = PedaleraEngine(context!!) { event ->
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            eventSink?.success(event)
                        }
                    }
                    pedaleraEngine?.initialize()
                }
                result.success(null)
            }
            "setPedalChain" -> {
                @Suppress("UNCHECKED_CAST")
                val chainConfig = call.argument<List<Map<String, Any>>>("chain") ?: emptyList()
                pedaleraEngine?.setChain(chainConfig)
                result.success(null)
            }
            "setPedalParam" -> {
                val idx = call.argument<Int>("index") ?: return result.success(null)
                val name = call.argument<String>("param") ?: return result.success(null)
                val value = call.argument<Double>("value") ?: return result.success(null)
                pedaleraEngine?.setParam(idx, name, value)
                result.success(null)
            }
            "setPedalBypass" -> {
                val idx = call.argument<Int>("index") ?: return result.success(null)
                val bypassed = call.argument<Boolean>("bypassed") ?: return result.success(null)
                pedaleraEngine?.setBypass(idx, bypassed)
                result.success(null)
            }
            "stopPedalera" -> {
                pedaleraEngine?.stop()
                pedaleraEngine = null
                result.success(null)
            }
            "getPedalLatency" -> {
                result.success(pedaleraEngine?.getLatency() ?: 0.0)
            }
            // ── MIDI ──
            "initMidi" -> {
                if (midiEngine == null) {
                    midiEngine = MIDIEngine(context!!) { event ->
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            eventSink?.success(event)
                        }
                    }
                }
                result.success(midiEngine?.initialize() ?: false)
            }
            "getMidiDevices" -> { result.success(midiEngine?.listDevices() ?: emptyList<Map<String, Any>>()) }
            "sendMidiNoteOn" -> {
                val note = call.argument<Int>("note") ?: 60
                val velocity = call.argument<Int>("velocity") ?: 100
                val channel = call.argument<Int>("channel") ?: 0
                midiEngine?.sendNoteOn(note, velocity, channel)
                result.success(null)
            }
            "sendMidiNoteOff" -> {
                val note = call.argument<Int>("note") ?: 60
                val channel = call.argument<Int>("channel") ?: 0
                midiEngine?.sendNoteOff(note, channel)
                result.success(null)
            }
            "sendMidiCC" -> {
                val controller = call.argument<Int>("controller") ?: 0
                val value = call.argument<Int>("value") ?: 0
                val channel = call.argument<Int>("channel") ?: 0
                midiEngine?.sendCC(controller, value, channel)
                result.success(null)
            }
            "sendMidiProgramChange" -> {
                val program = call.argument<Int>("program") ?: 0
                val channel = call.argument<Int>("channel") ?: 0
                midiEngine?.sendProgramChange(program, channel)
                result.success(null)
            }
            "startMidiClock" -> {
                val bpm = call.argument<Double>("bpm") ?: 120.0
                midiEngine?.startClock(bpm)
                result.success(null)
            }
            "stopMidiClock" -> { midiEngine?.stopClock(); result.success(null) }
            "updateMidiClockBpm" -> {
                val bpm = call.argument<Double>("bpm") ?: 120.0
                midiEngine?.updateClockBpm(bpm)
                result.success(null)
            }
            "disconnectMidi" -> {
                midiEngine?.dispose()
                midiEngine = null
                result.success(null)
            }
            // ── Audio Session ──
            "getAudioRoute" -> { result.success("speaker") }
            "getAvailableInputs" -> { result.success(emptyList<Map<String, Any>>()) }
            "setPreferredInput" -> { result.success(false) }
            "setBufferDuration" -> { result.success(null) }
            "dispose" -> {
                metronomeEngine?.stop()
                metronomeEngine = null
                recordingEngine?.stopRecording()
                recordingEngine = null
                pedaleraEngine?.stop()
                pedaleraEngine = null
                midiEngine?.dispose()
                midiEngine = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
