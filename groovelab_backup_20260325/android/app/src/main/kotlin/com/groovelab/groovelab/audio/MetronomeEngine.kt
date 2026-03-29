package com.groovelab.groovelab.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.content.Context
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min

/**
 * High-precision metronome engine for Android using AudioTrack.
 * Runs audio generation on a dedicated high-priority thread.
 * Uses System.nanoTime() for precise scheduling with drift compensation.
 */
class MetronomeEngine(private val onEvent: (Map<String, Any>) -> Unit) {

    private val sampleRate = 44100
    private val soundBuffers = mutableMapOf<String, ShortArray>()

    // Metronome state (volatile for thread safety)
    @Volatile private var bpm = 120
    @Volatile private var beatsPerBar = 4
    @Volatile private var beatUnit = 4
    @Volatile private var subdivision = 1
    @Volatile private var swingPercent = 0
    @Volatile private var clickSound = "Wood"
    @Volatile private var accentPattern = listOf(1.0, 0.7, 0.7, 0.7)
    @Volatile private var hapticEnabled = false
    @Volatile private var humanFeel = 0 // 0-50, timing jitter percentage
    @Volatile private var polyrhythmEnabled = false
    @Volatile private var polyrhythmValue = 3 // N in N:beatsPerBar

    // Drum mode
    @Volatile private var isDrumMode = false
    @Volatile private var drumPattern = mapOf<String, List<Int>>()
    @Volatile private var drumVolumes = mapOf("kick" to 1.0, "snare" to 1.0, "hihat" to 1.0, "ride" to 1.0)

    // Playback
    private var audioTrack: AudioTrack? = null
    private var playbackThread: Thread? = null
    @Volatile private var isRunning = false
    private var currentSubBeat = 0
    private var currentMeasure = 0

    fun initialize() {
        // Pre-allocate AudioTrack
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        val format = AudioFormat.Builder()
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .build()

        val builder = AudioTrack.Builder()
            .setAudioAttributes(attrs)
            .setAudioFormat(format)
            .setBufferSizeInBytes(minBuffer * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        }

        audioTrack = builder.build()
    }

    fun loadSound(key: String, wavData: ByteArray) {
        // Parse WAV: skip 44-byte header, extract 16-bit PCM samples
        if (wavData.size <= 44) return
        val pcmData = wavData.copyOfRange(44, wavData.size)
        val sampleCount = pcmData.size / 2
        val samples = ShortArray(sampleCount)

        val buffer = ByteBuffer.wrap(pcmData).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until sampleCount) {
            samples[i] = buffer.short
        }
        soundBuffers[key] = samples
    }

    /** Play a single sound hit immediately (for manual drum pad taps). */
    fun playSingleHit(key: String, volume: Float = 1.0f) {
        val samples = soundBuffers[key] ?: return
        Thread {
            try {
                val track = audioTrack ?: return@Thread
                if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
                    track.play()
                }
                track.write(samples, 0, samples.size)
            } catch (e: Exception) {
                android.util.Log.e("MetronomeEngine", "playSingleHit error: $e")
            }
        }.start()
    }

    fun start(
        bpm: Int, beatsPerBar: Int, beatUnit: Int, subdivision: Int,
        swingPercent: Int, clickSound: String, accentPattern: List<Double>,
        hapticEnabled: Boolean
    ) {
        stop()
        this.bpm = bpm
        this.beatsPerBar = beatsPerBar
        this.beatUnit = beatUnit
        this.subdivision = subdivision
        this.swingPercent = swingPercent
        this.clickSound = clickSound
        this.accentPattern = accentPattern
        this.hapticEnabled = hapticEnabled
        this.isDrumMode = false
        this.currentSubBeat = 0
        this.currentMeasure = 0

        isRunning = true
        audioTrack?.play()
        startPlaybackThread()
    }

    fun startDrumPattern(bpm: Int, pattern: Map<String, List<Int>>, swingPercent: Int) {
        stop()
        this.bpm = bpm
        this.beatsPerBar = 4
        this.beatUnit = 4
        this.subdivision = 4
        this.swingPercent = swingPercent
        this.drumPattern = pattern
        this.isDrumMode = true
        this.currentSubBeat = 0
        this.currentMeasure = 0

        isRunning = true
        audioTrack?.play()
        startPlaybackThread()
    }

    fun stop() {
        isRunning = false
        playbackThread?.join(500)
        playbackThread = null
        audioTrack?.pause()
        audioTrack?.flush()
    }

    /**
     * Core playback thread: runs at high priority.
     * Instead of using Timer, this thread generates audio directly
     * and writes to AudioTrack, which handles precise timing.
     */
    private fun startPlaybackThread() {
        playbackThread = Thread({
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)

            var nextBeatTimeNs = System.nanoTime()

            while (isRunning) {
                val currentBpm = bpm
                val currentSub = subdivision
                val totalSubBeats = if (isDrumMode) 16 else (beatsPerBar * currentSub)

                // Calculate this sub-beat's interval
                val baseIntervalNs = if (isDrumMode) {
                    (60_000_000_000L / currentBpm / 4) // 16th notes
                } else {
                    (60_000_000_000L / currentBpm / currentSub)
                }

                var intervalNs = baseIntervalNs

                // Apply swing
                if (swingPercent > 0 && currentSub >= 2) {
                    val swingRatio = 0.5 + swingPercent / 200.0
                    val pairIntervalNs = baseIntervalNs * 2
                    val isEven = (currentSubBeat) % 2 == 0
                    intervalNs = if (isEven) {
                        (pairIntervalNs * swingRatio).toLong()
                    } else {
                        (pairIntervalNs * (1.0 - swingRatio)).toLong()
                    }
                }

                // Apply human feel (timing jitter)
                if (humanFeel > 0 && !isDrumMode) {
                    val maxJitterFraction = humanFeel / 100.0 * 0.08
                    val jitter = (Math.random() * 2.0 - 1.0) * maxJitterFraction * intervalNs
                    intervalNs = max((intervalNs * 0.85).toLong(), intervalNs + jitter.toLong())
                }

                // Generate audio for this beat
                val soundData = generateBeatAudio()

                // Write audio to AudioTrack (this blocks until the buffer is consumed = natural timing)
                if (soundData != null && soundData.isNotEmpty()) {
                    audioTrack?.write(soundData, 0, soundData.size)
                }

                // Generate silence to fill remaining interval
                val soundDurationSamples = soundData?.size ?: 0
                val intervalSamples = (intervalNs.toDouble() / 1_000_000_000.0 * sampleRate).toInt()
                val silenceSamples = max(0, intervalSamples - soundDurationSamples)
                if (silenceSamples > 0) {
                    val silence = ShortArray(silenceSamples)
                    audioTrack?.write(silence, 0, silence.size)
                }

                // Send events
                if (isDrumMode) {
                    val step = currentSubBeat % 16
                    onEvent(mapOf(
                        "type" to "drumStep",
                        "step" to step,
                        "measureIndex" to currentMeasure,
                        "timestampUs" to (System.nanoTime() / 1000)
                    ))
                } else {
                    val subBeatInBar = currentSubBeat % totalSubBeats
                    val isMainBeat = subBeatInBar % currentSub == 0
                    if (isMainBeat) {
                        val mainBeatIndex = subBeatInBar / currentSub
                        onEvent(mapOf(
                            "type" to "beat",
                            "beatIndex" to mainBeatIndex,
                            "measureIndex" to currentMeasure,
                            "isAccent" to (mainBeatIndex == 0),
                            "timestampUs" to (System.nanoTime() / 1000)
                        ))
                    }
                }

                // Advance
                currentSubBeat++
                if (currentSubBeat % totalSubBeats == 0) {
                    currentMeasure++
                }
            }
        }, "GrooveLab-Audio").apply {
            priority = Thread.MAX_PRIORITY
        }
        playbackThread?.start()
    }

    private fun generateBeatAudio(): ShortArray? {
        if (isDrumMode) {
            return generateDrumStepAudio()
        }

        val totalSubBeats = beatsPerBar * subdivision
        val subBeatInBar = currentSubBeat % totalSubBeats
        val isMainBeat = subBeatInBar % subdivision == 0
        val mainBeatIndex = subBeatInBar / subdivision

        var mainSound: ShortArray? = null

        if (isMainBeat) {
            val vol = if (mainBeatIndex < accentPattern.size) accentPattern[mainBeatIndex] else 0.7
            if (vol > 0) {
                val isAccent = vol >= 0.9
                val key = getSoundKey(clickSound, isAccent)
                mainSound = soundBuffers[key]
            }

            // Polyrhythm: mix ghost click if this beat aligns with the poly grid
            if (polyrhythmEnabled) {
                val lcmVal = lcm(beatsPerBar, polyrhythmValue)
                val polyStep = lcmVal / polyrhythmValue
                val mainStep = lcmVal / beatsPerBar
                val currentPos = mainBeatIndex * mainStep
                if (currentPos % polyStep == 0) {
                    val ghost = soundBuffers["click_ghost"]
                    if (ghost != null && mainSound != null) {
                        mainSound = mixSounds(mainSound!!, ghost, 0.4)
                    } else if (ghost != null) {
                        mainSound = applyVolume(ghost, 0.4)
                    }
                }
            }
        } else if (subdivision > 1) {
            mainSound = soundBuffers["click_sub"]
        }

        return mainSound
    }

    private fun mixSounds(a: ShortArray, b: ShortArray, bVol: Double): ShortArray {
        val maxLen = max(a.size, b.size)
        val result = ShortArray(maxLen)
        for (i in 0 until maxLen) {
            val sa = if (i < a.size) a[i].toInt() else 0
            val sb = if (i < b.size) (b[i].toDouble() * bVol).toInt() else 0
            result[i] = max(-32768, min(32767, sa + sb)).toShort()
        }
        return result
    }

    private fun applyVolume(data: ShortArray, vol: Double): ShortArray {
        return ShortArray(data.size) { max(-32768, min(32767, (data[it].toDouble() * vol).toInt())).toShort() }
    }

    private fun generateDrumStepAudio(): ShortArray? {
        val step = currentSubBeat % 16
        val trackNames = listOf("kick", "snare", "hihat", "ride")
        val sounds = mutableListOf<Pair<ShortArray, Double>>() // sound + volume

        for (track in trackNames) {
            val pattern = drumPattern[track] ?: continue
            if (step < pattern.size && pattern[step] == 1) {
                val buf = soundBuffers[track] ?: continue
                val vol = drumVolumes[track] ?: 1.0
                if (vol > 0.01) sounds.add(Pair(buf, vol))
            }
        }

        if (sounds.isEmpty()) return null

        // Mix all simultaneous drum sounds with per-track volume
        val maxLen = sounds.maxOf { it.first.size }
        val mixed = ShortArray(maxLen)
        for ((sound, vol) in sounds) {
            for (i in sound.indices) {
                val scaled = (sound[i].toDouble() * vol).toInt()
                val sum = mixed[i].toInt() + scaled
                mixed[i] = max(-32768, min(32767, sum)).toShort()
            }
        }
        return mixed
    }

    private fun getSoundKey(clickSound: String, isAccent: Boolean): String {
        return when (clickSound) {
            "Wood" -> if (isAccent) "click_accent" else "click_normal"
            "Digital" -> if (isAccent) "digital_accent" else "digital_normal"
            "Hi-Hat" -> "hihat_click"
            "Clave" -> if (isAccent) "clave_accent" else "clave_normal"
            "Cowbell" -> if (isAccent) "cowbell_accent" else "cowbell_normal"
            "Beep" -> if (isAccent) "beep_accent" else "beep_normal"
            else -> if (isAccent) "click_accent" else "click_normal"
        }
    }

    // Live updates
    fun updateBpm(newBpm: Int) { bpm = newBpm }
    fun updateTimeSignature(beats: Int, unit: Int) {
        beatsPerBar = beats; beatUnit = unit
        if (accentPattern.size != beats) {
            accentPattern = List(beats) { if (it == 0) 1.0 else 0.7 }
        }
    }
    fun updateSubdivision(sub: Int) { subdivision = sub }
    fun updateSwing(pct: Int) { swingPercent = pct }
    fun updateClickSound(sound: String) { clickSound = sound }
    fun updateAccentPattern(pattern: List<Double>) { accentPattern = pattern }
    fun setHapticMode(enabled: Boolean) { hapticEnabled = enabled }
    fun updateHumanFeel(percent: Int) { humanFeel = percent.coerceIn(0, 50) }
    fun updatePolyrhythm(enabled: Boolean, value: Int) {
        polyrhythmEnabled = enabled
        polyrhythmValue = value.coerceIn(2, 7)
    }
    fun updateDrumPattern(pattern: Map<String, List<Int>>) { drumPattern = pattern }
    fun updateDrumVolumes(volumes: Map<String, Double>) { drumVolumes = volumes }

    private fun gcd(a: Int, b: Int): Int = if (b == 0) a else gcd(b, a % b)
    private fun lcm(a: Int, b: Int): Int = a / gcd(a, b) * b

    fun getOutputLatency(): Double {
        // AudioTrack latency is approximately buffer size / sample rate
        val minBuffer = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
        return (minBuffer.toDouble() / sampleRate / 2) * 1000.0 // approximate ms
    }
}
