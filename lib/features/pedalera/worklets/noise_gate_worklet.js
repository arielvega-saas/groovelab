/**
 * NoiseGateProcessor — AudioWorklet for real-time noise gate.
 * RMS level detection with threshold, attack, hold, and release.
 * Runs entirely off the main thread for lowest latency.
 */
class NoiseGateProcessor extends AudioWorkletProcessor {
  static get parameterDescriptors() {
    return [
      { name: 'threshold', defaultValue: -50, minValue: -96, maxValue: 0, automationRate: 'k-rate' },
      { name: 'attack',    defaultValue: 0.5, minValue: 0.1, maxValue: 50, automationRate: 'k-rate' },
      { name: 'hold',      defaultValue: 100, minValue: 0,   maxValue: 500, automationRate: 'k-rate' },
      { name: 'release',   defaultValue: 50,  minValue: 1,   maxValue: 500, automationRate: 'k-rate' }
    ];
  }

  constructor() {
    super();
    this._gateOpen = true;
    this._currentGain = 1.0;
    this._holdCounter = 0;
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    const output = outputs[0];
    if (!input || !input.length) return true;

    const threshold = parameters.threshold[0];
    const attackMs = parameters.attack[0];
    const holdMs = parameters.hold[0];
    const releaseMs = parameters.release[0];

    const thresholdLinear = Math.pow(10, threshold / 20);
    const attackCoeff = 1 - Math.exp(-1 / (sampleRate * attackMs / 1000));
    const releaseCoeff = 1 - Math.exp(-1 / (sampleRate * releaseMs / 1000));
    const holdSamples = (holdMs / 1000) * sampleRate;

    for (let ch = 0; ch < input.length; ch++) {
      const inp = input[ch];
      const out = output[ch];

      for (let i = 0; i < inp.length; i++) {
        // RMS approximation (simplified: abs value tracking)
        const level = Math.abs(inp[i]);

        if (level > thresholdLinear) {
          // Signal above threshold — open gate
          this._gateOpen = true;
          this._holdCounter = holdSamples;
          this._currentGain += attackCoeff * (1 - this._currentGain);
        } else if (this._holdCounter > 0) {
          // In hold period
          this._holdCounter--;
          this._currentGain += attackCoeff * (1 - this._currentGain);
        } else {
          // Below threshold, hold expired — close gate
          this._gateOpen = false;
          this._currentGain += releaseCoeff * (0 - this._currentGain);
        }

        out[i] = inp[i] * this._currentGain;
      }
    }

    return true;
  }
}

registerProcessor('noise-gate-processor', NoiseGateProcessor);
