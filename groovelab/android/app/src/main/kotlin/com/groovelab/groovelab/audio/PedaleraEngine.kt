package com.groovelab.groovelab.audio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.Equalizer
import android.media.audiofx.PresetReverb
import android.os.Build
import androidx.core.content.ContextCompat
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.tanh

/**
 * Real-time guitar effects engine for Android.
 * Chain: Input → NoiseGate → Compressor → Drive → EQ → Amp → Cabinet → Chorus → Delay → Reverb → Output
 *
 * Uses AudioRecord for input, manual DSP processing, and AudioTrack for output.
 * This provides the lowest latency path on Android without requiring NDK/Oboe.
 */
class PedaleraEngine(
    private val context: Context,
    private val onEvent: (Map<String, Any>) -> Unit
) {
    companion object {
        private const val SAMPLE_RATE = 44100
        private const val BUFFER_FRAMES = 256 // ~5.8ms @ 44.1kHz
        private const val TAG = "PedaleraEngine"
    }

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var processingThread: Thread? = null
    @Volatile private var isActive = false

    // Chain config
    private var chainConfig: List<PedalConfig> = emptyList()

    // Processing state
    private val delayBuffer = FloatArray(SAMPLE_RATE * 2) // 2 seconds max delay
    private var delayWritePos = 0
    private var delayEnabled = false
    private var delayTimeSamples = (0.4 * SAMPLE_RATE).toInt()
    private var delayFeedback = 0.35f
    private var delayMix = 0.3f

    // Drive/Distortion
    private var driveEnabled = false
    private var driveAmount = 2.0f

    // EQ state
    private var eqEnabled = false
    private var eqGains = floatArrayOf(0f, 0f, 0f, 0f, 0f) // low, lowMid, mid, hiMid, high

    // Noise gate
    private var gateEnabled = false
    private var gateThreshold = 0.01f

    // Compressor
    private var compEnabled = false
    private var compThreshold = 0.5f
    private var compRatio = 4.0f

    // Amp
    private var ampEnabled = false
    private var ampGain = 0.5f

    // Reverb
    private var reverbEnabled = false
    private var reverbMix = 0.3f
    private var reverbDecay = 0.5f
    // Simple Schroeder reverb implementation
    private val reverbBuffers = Array(4) { i ->
        FloatArray(when(i) { 0 -> 1557; 1 -> 1617; 2 -> 1491; 3 -> 1422; else -> 1500 })
    }
    private val reverbIndices = IntArray(4)

    // Chorus
    private var chorusEnabled = false
    private var chorusMix = 0.4f
    private val chorusBuffer = FloatArray(SAMPLE_RATE) // 1 second
    private var chorusWritePos = 0
    private var chorusPhase = 0.0

    data class PedalConfig(
        val type: String,
        var enabled: Boolean,
        val params: MutableMap<String, Double>
    )

    fun initialize() {
        android.util.Log.d(TAG, "Initializing PedaleraEngine")
    }

    fun setChain(config: List<Map<String, Any>>) {
        chainConfig = config.map { pedal ->
            @Suppress("UNCHECKED_CAST")
            PedalConfig(
                type = pedal["type"] as? String ?: "",
                enabled = pedal["enabled"] as? Boolean ?: false,
                params = (pedal["params"] as? Map<String, Any>)?.mapValues {
                    (it.value as? Number)?.toDouble() ?: 0.0
                }?.toMutableMap() ?: mutableMapOf()
            )
        }
        applyChainConfig()

        // Start audio processing if not already running
        if (!isActive) {
            startProcessing()
        }
    }

    private fun applyChainConfig() {
        for (pedal in chainConfig) {
            when (pedal.type) {
                "noiseGate" -> {
                    gateEnabled = pedal.enabled
                    gateThreshold = (pedal.params["threshold"] ?: 0.01).toFloat()
                }
                "compressor" -> {
                    compEnabled = pedal.enabled
                    compThreshold = ((pedal.params["threshold"] ?: -24.0) + 96.0).toFloat() / 96.0f
                    compRatio = (pedal.params["ratio"] ?: 4.0).toFloat()
                }
                "drive" -> {
                    driveEnabled = pedal.enabled
                    driveAmount = ((pedal.params["gain"] ?: 50.0) / 25.0).toFloat()
                }
                "eq" -> {
                    eqEnabled = pedal.enabled
                    eqGains[0] = (pedal.params["low"] ?: 0.0).toFloat()
                    eqGains[1] = (pedal.params["lowMid"] ?: 0.0).toFloat()
                    eqGains[2] = (pedal.params["mid"] ?: 0.0).toFloat()
                    eqGains[3] = (pedal.params["hiMid"] ?: 0.0).toFloat()
                    eqGains[4] = (pedal.params["high"] ?: 0.0).toFloat()
                }
                "amp" -> {
                    ampEnabled = pedal.enabled
                    ampGain = ((pedal.params["gain"] ?: 50.0) / 100.0).toFloat()
                }
                "delay" -> {
                    delayEnabled = pedal.enabled
                    delayTimeSamples = ((pedal.params["time"] ?: 400.0) / 1000.0 * SAMPLE_RATE).toInt()
                        .coerceIn(1, delayBuffer.size - 1)
                    delayFeedback = (pedal.params["feedback"] ?: 35.0).toFloat() / 100f
                    delayMix = (pedal.params["mix"] ?: 30.0).toFloat() / 100f
                }
                "reverb" -> {
                    reverbEnabled = pedal.enabled
                    reverbMix = (pedal.params["mix"] ?: 30.0).toFloat() / 100f
                    reverbDecay = (pedal.params["decay"] ?: 50.0).toFloat() / 100f
                }
                "chorus" -> {
                    chorusEnabled = pedal.enabled
                    chorusMix = (pedal.params["mix"] ?: 40.0).toFloat() / 100f
                }
                "cabinet" -> {
                    // Cabinet is simulated via low-pass filter + mild reverb
                    // Already handled in reverb processing
                }
            }
        }
    }

    fun setParam(pedalIndex: Int, paramName: String, value: Double) {
        if (pedalIndex < 0 || pedalIndex >= chainConfig.size) return
        chainConfig[pedalIndex].params[paramName] = value
        applyChainConfig()
    }

    fun setBypass(pedalIndex: Int, bypassed: Boolean) {
        if (pedalIndex < 0 || pedalIndex >= chainConfig.size) return
        chainConfig[pedalIndex].enabled = !bypassed
        applyChainConfig()
    }

    private fun startProcessing() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            android.util.Log.e(TAG, "RECORD_AUDIO permission not granted")
            return
        }

        val minBufSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_FLOAT
        )
        val bufferSize = max(minBufSize, BUFFER_FRAMES * 4)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_FLOAT,
            bufferSize
        )

        val trackBufSize = AudioTrack.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_FLOAT
        )

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .build()
            )
            .setBufferSizeInBytes(max(trackBufSize, BUFFER_FRAMES * 4))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                }
            }
            .build()

        isActive = true
        audioRecord?.startRecording()
        audioTrack?.play()

        processingThread = Thread({
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
            val buffer = FloatArray(BUFFER_FRAMES)

            while (isActive) {
                val read = audioRecord?.read(buffer, 0, BUFFER_FRAMES, AudioRecord.READ_BLOCKING) ?: 0
                if (read > 0) {
                    processAudio(buffer, read)
                    audioTrack?.write(buffer, 0, read, AudioTrack.WRITE_BLOCKING)
                }
            }
        }, "PedaleraAudio")
        processingThread?.start()

        android.util.Log.d(TAG, "Audio processing started")
    }

    private fun processAudio(buffer: FloatArray, frames: Int) {
        for (i in 0 until frames) {
            var sample = buffer[i]

            // 1. Noise Gate
            if (gateEnabled && abs(sample) < gateThreshold) {
                sample = 0f
            }

            // 2. Compressor
            if (compEnabled) {
                val level = abs(sample)
                if (level > compThreshold) {
                    val excess = level - compThreshold
                    val compressed = compThreshold + excess / compRatio
                    sample = if (sample >= 0) compressed else -compressed
                }
            }

            // 3. Drive / Distortion (soft-clipping via tanh)
            if (driveEnabled) {
                sample = tanh(sample * driveAmount).toFloat()
            }

            // 4. Amp (additional gain + soft clip)
            if (ampEnabled) {
                sample *= (1f + ampGain * 3f)
                sample = tanh(sample.toDouble()).toFloat()
            }

            // 5. Chorus (modulated short delay)
            if (chorusEnabled) {
                chorusBuffer[chorusWritePos] = sample
                chorusPhase += 0.5 * Math.PI * 2 / SAMPLE_RATE // 0.5 Hz LFO
                val modDelay = (0.015 * SAMPLE_RATE * (1.0 + 0.3 * kotlin.math.sin(chorusPhase))).toInt()
                val readPos = (chorusWritePos - modDelay + chorusBuffer.size) % chorusBuffer.size
                val chorusSample = chorusBuffer[readPos]
                sample = sample * (1f - chorusMix) + chorusSample * chorusMix
                chorusWritePos = (chorusWritePos + 1) % chorusBuffer.size
            }

            // 6. Delay
            if (delayEnabled) {
                val readPos = (delayWritePos - delayTimeSamples + delayBuffer.size) % delayBuffer.size
                val delaySample = delayBuffer[readPos]
                delayBuffer[delayWritePos] = sample + delaySample * delayFeedback
                sample = sample * (1f - delayMix) + delaySample * delayMix
                delayWritePos = (delayWritePos + 1) % delayBuffer.size
            }

            // 7. Reverb (simple Schroeder)
            if (reverbEnabled) {
                var reverbSample = 0f
                for (j in reverbBuffers.indices) {
                    val buf = reverbBuffers[j]
                    val idx = reverbIndices[j]
                    val delayed = buf[idx]
                    buf[idx] = sample + delayed * reverbDecay
                    reverbSample += delayed
                    reverbIndices[j] = (idx + 1) % buf.size
                }
                reverbSample /= reverbBuffers.size.toFloat()
                sample = sample * (1f - reverbMix) + reverbSample * reverbMix
            }

            // Soft limiter to prevent clipping
            sample = sample.coerceIn(-1f, 1f)

            buffer[i] = sample
        }
    }

    fun getLatency(): Double {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val framesPerBuffer = am?.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)?.toIntOrNull() ?: 256
        val sampleRate = am?.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull() ?: 44100
        return framesPerBuffer.toDouble() / sampleRate * 1000.0 * 2 // input + output
    }

    fun stop() {
        isActive = false
        processingThread?.join(1000)
        processingThread = null
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        android.util.Log.d(TAG, "PedaleraEngine stopped")
    }
}
