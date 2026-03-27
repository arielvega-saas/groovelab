package com.groovelab.groovelab.audio

import android.Manifest
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Recording engine with real-time onset detection for Android.
 * Uses AudioRecord for low-latency microphone capture.
 * Energy-based onset detection runs in the recording thread.
 */
class RecordingEngine(
    private val context: Context,
    private val onEvent: (Map<String, Any>) -> Unit
) {
    private val sampleRate = 44100
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    @Volatile private var isRecording = false
    private var currentFilePath: String? = null

    // Onset detection
    @Volatile private var onsetDetectionEnabled = false
    @Volatile private var onsetThreshold = 0.1
    @Volatile private var minOnsetIntervalMs = 50
    private var lastOnsetTimeNs: Long = 0
    private var previousEnergy: Double = 0.0
    private val energyHistory = mutableListOf<Double>()
    private val energyHistorySize = 10

    fun startRecording() {
        if (isRecording) return

        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ) * 2

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        // Create output file
        val dir = context.getExternalFilesDir(null) ?: context.filesDir
        val timestamp = System.currentTimeMillis()
        val file = File(dir, "take_$timestamp.wav")
        currentFilePath = file.absolutePath

        isRecording = true
        previousEnergy = 0.0
        energyHistory.clear()
        lastOnsetTimeNs = 0

        audioRecord?.startRecording()

        recordingThread = Thread({
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)

            val buffer = ShortArray(512)
            val rawFile = File(dir, "take_${timestamp}_raw.pcm")
            val outputStream = FileOutputStream(rawFile)

            onEvent(mapOf(
                "type" to "recordingState",
                "isRecording" to true,
                "durationMs" to 0
            ))

            while (isRecording) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read > 0) {
                    // Write raw PCM
                    val byteBuffer = ByteBuffer.allocate(read * 2).order(ByteOrder.LITTLE_ENDIAN)
                    for (i in 0 until read) {
                        byteBuffer.putShort(buffer[i])
                    }
                    outputStream.write(byteBuffer.array())

                    // Onset detection
                    if (onsetDetectionEnabled) {
                        detectOnset(buffer, read)
                    }
                }
            }

            outputStream.close()

            // Convert raw PCM to WAV
            convertToWav(rawFile, File(currentFilePath!!), sampleRate)
            rawFile.delete()

        }, "GrooveLab-Recording").apply {
            priority = Thread.MAX_PRIORITY - 1
        }
        recordingThread?.start()
    }

    fun stopRecording(): String? {
        if (!isRecording) return null
        isRecording = false
        recordingThread?.join(1000)
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        onEvent(mapOf(
            "type" to "recordingState",
            "isRecording" to false,
            "durationMs" to 0,
            "filePath" to (currentFilePath ?: "")
        ))

        return currentFilePath
    }

    private fun detectOnset(buffer: ShortArray, length: Int) {
        // Calculate RMS energy
        var sum = 0.0
        for (i in 0 until length) {
            val sample = buffer[i].toDouble() / 32768.0
            sum += sample * sample
        }
        val rms = sqrt(sum / length)

        // Spectral flux (energy increase)
        val flux = max(0.0, rms - previousEnergy)
        previousEnergy = rms

        // Running average for adaptive threshold
        energyHistory.add(flux)
        if (energyHistory.size > energyHistorySize) {
            energyHistory.removeAt(0)
        }
        val avgFlux = energyHistory.sum() / energyHistory.size
        val adaptiveThreshold = max(onsetThreshold, avgFlux * 2.5)

        if (flux > adaptiveThreshold) {
            val nowNs = System.nanoTime()
            val elapsedMs = (nowNs - lastOnsetTimeNs) / 1_000_000.0

            if (lastOnsetTimeNs == 0L || elapsedMs >= minOnsetIntervalMs) {
                lastOnsetTimeNs = nowNs

                // Peak amplitude
                var peak = 0.0
                for (i in 0 until length) {
                    peak = max(peak, abs(buffer[i].toDouble()) / 32768.0)
                }

                onEvent(mapOf(
                    "type" to "onset",
                    "timestampUs" to (nowNs / 1000),
                    "amplitude" to peak.coerceAtMost(1.0)
                ))
            }
        }
    }

    fun enableOnsetDetection(threshold: Double, minIntervalMs: Int) {
        onsetThreshold = threshold
        minOnsetIntervalMs = minIntervalMs
        onsetDetectionEnabled = true
    }

    fun disableOnsetDetection() {
        onsetDetectionEnabled = false
    }

    fun getInputLatency(): Double {
        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        return (minBuffer.toDouble() / sampleRate) * 1000.0
    }

    companion object {
        fun convertToWav(pcmFile: File, wavFile: File, sampleRate: Int) {
            val pcmSize = pcmFile.length().toInt()
            val wavSize = pcmSize + 44

            val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            // RIFF
            header.put("RIFF".toByteArray())
            header.putInt(wavSize - 8)
            header.put("WAVE".toByteArray())
            // fmt
            header.put("fmt ".toByteArray())
            header.putInt(16) // chunk size
            header.putShort(1) // PCM
            header.putShort(1) // mono
            header.putInt(sampleRate)
            header.putInt(sampleRate * 2) // byte rate
            header.putShort(2) // block align
            header.putShort(16) // bits per sample
            // data
            header.put("data".toByteArray())
            header.putInt(pcmSize)

            val fos = FileOutputStream(wavFile)
            fos.write(header.array())
            fos.write(pcmFile.readBytes())
            fos.close()
        }
    }
}
