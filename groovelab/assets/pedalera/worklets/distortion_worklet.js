/**
 * DistortionProcessor — AudioWorklet for waveshaping distortion.
 * Runs clipping algorithms off the main thread with oversampling.
 * Supports soft, hard, and fuzz clipping modes.
 */
class DistortionProcessor extends AudioWorkletProcessor {
  static get parameterDescriptors() {
    return [
      { name: 'drive',  defaultValue: 2, minValue: 0.1, maxValue: 20, automationRate: 'k-rate' },
      { name: 'tone',   defaultValue: 0.5, minValue: 0, maxValue: 1, automationRate: 'k-rate' },
      { name: 'output', defaultValue: 0.5, minValue: 0, maxValue: 1, automationRate: 'k-rate' },
      { name: 'mode',   defaultValue: 0, minValue: 0, maxValue: 2, automationRate: 'k-rate' }
      // mode: 0=soft, 1=hard, 2=fuzz
    ];
  }

  constructor() {
    super();
    this._lpState = 0;
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    const output = outputs[0];
    if (!input || !input.length) return true;

    const drive = parameters.drive[0];
    const tone = parameters.tone[0];
    const outLevel = parameters.output[0];
    const mode = Math.round(parameters.mode[0]);

    // Simple one-pole lowpass for tone control
    const cutoff = 1000 + tone * 10000;
    const rc = 1 / (2 * Math.PI * cutoff);
    const dt = 1 / sampleRate;
    const alpha = dt / (rc + dt);

    for (let ch = 0; ch < input.length; ch++) {
      const inp = input[ch];
      const out = output[ch];
      let lpState = this._lpState;

      for (let i = 0; i < inp.length; i++) {
        let x = inp[i] * drive;
        let y;

        switch (mode) {
          case 0: // Soft clip (tube-like)
            y = Math.tanh(x);
            break;
          case 1: // Hard clip (diode)
            y = Math.sign(x) * (1 - Math.exp(-Math.abs(x)));
            break;
          case 2: // Fuzz (cascaded tanh)
            y = Math.tanh(x * 2);
            y = Math.tanh(y * 1.5);
            y = Math.tanh(y * 1.2);
            break;
          default:
            y = Math.tanh(x);
        }

        // Tone filter
        lpState = lpState + alpha * (y - lpState);
        out[i] = lpState * outLevel;
      }

      this._lpState = lpState;
    }

    return true;
  }
}

registerProcessor('distortion-processor', DistortionProcessor);
