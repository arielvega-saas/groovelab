/**
 * TunerProcessor — AudioWorklet for real-time pitch detection.
 * Autocorrelation-based pitch detection running off the main thread.
 * Posts detected pitch data back to main thread via port.
 */
class TunerProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this._buffer = new Float32Array(4096);
    this._bufferIndex = 0;
    this._frameCount = 0;
    this._noteNames = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
    this._active = true;

    this.port.onmessage = (e) => {
      if (e.data.type === 'start') this._active = true;
      if (e.data.type === 'stop') this._active = false;
    };
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    const output = outputs[0];
    if (!input || !input.length) return true;

    const inp = input[0];

    // Pass through audio
    for (let ch = 0; ch < input.length; ch++) {
      if (output[ch]) {
        for (let i = 0; i < input[ch].length; i++) {
          output[ch][i] = input[ch][i];
        }
      }
    }

    if (!this._active) return true;

    // Fill buffer
    for (let i = 0; i < inp.length; i++) {
      this._buffer[this._bufferIndex++] = inp[i];
      if (this._bufferIndex >= this._buffer.length) {
        this._bufferIndex = 0;
        this._frameCount++;
        // Analyze every 3rd buffer fill (~35ms @ 44100Hz)
        if (this._frameCount % 3 === 0) {
          this._detectPitch();
        }
      }
    }

    return true;
  }

  _detectPitch() {
    const buf = this._buffer;
    const size = buf.length;

    // Check if there's enough signal
    let rms = 0;
    for (let i = 0; i < size; i++) rms += buf[i] * buf[i];
    rms = Math.sqrt(rms / size);
    if (rms < 0.01) {
      this.port.postMessage({ note: '--', freq: 0, cents: 0 });
      return;
    }

    // Autocorrelation
    const correlations = new Float32Array(size);
    for (let lag = 0; lag < size; lag++) {
      let sum = 0;
      for (let i = 0; i < size - lag; i++) {
        sum += buf[i] * buf[i + lag];
      }
      correlations[lag] = sum;
    }

    // Find first dip then first peak after it
    let dipped = false;
    let bestLag = -1;
    let bestCorr = 0;
    const minLag = Math.floor(sampleRate / 1200); // Max freq ~1200Hz
    const maxLag = Math.floor(sampleRate / 50);    // Min freq ~50Hz

    for (let lag = minLag; lag < Math.min(maxLag, size); lag++) {
      if (!dipped && correlations[lag] < correlations[lag - 1]) {
        dipped = true;
      }
      if (dipped && correlations[lag] > bestCorr) {
        bestCorr = correlations[lag];
        bestLag = lag;
      }
    }

    if (bestLag < 0 || bestCorr < correlations[0] * 0.3) {
      this.port.postMessage({ note: '--', freq: 0, cents: 0 });
      return;
    }

    // Parabolic interpolation for sub-sample accuracy
    const prev = correlations[bestLag - 1] || 0;
    const curr = correlations[bestLag];
    const next = correlations[bestLag + 1] || 0;
    const shift = (prev - next) / (2 * (prev - 2 * curr + next));
    const refinedLag = bestLag + (isFinite(shift) ? shift : 0);

    const freq = sampleRate / refinedLag;

    // Convert to note
    const noteNum = 12 * (Math.log2(freq / 440)) + 69;
    const roundedNote = Math.round(noteNum);
    const cents = Math.round((noteNum - roundedNote) * 100);
    const noteName = this._noteNames[roundedNote % 12];
    const octave = Math.floor(roundedNote / 12) - 1;

    this.port.postMessage({
      note: noteName + octave,
      freq: Math.round(freq * 10) / 10,
      cents: cents
    });
  }
}

registerProcessor('tuner-processor', TunerProcessor);
