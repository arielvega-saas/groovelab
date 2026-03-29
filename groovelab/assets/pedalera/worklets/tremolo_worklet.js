/**
 * TremoloProcessor — AudioWorklet for LFO amplitude modulation.
 * Supports sine, triangle, and square waveforms.
 * BPM-syncable rate parameter.
 */
class TremoloProcessor extends AudioWorkletProcessor {
  static get parameterDescriptors() {
    return [
      { name: 'rate',  defaultValue: 4, minValue: 0.1, maxValue: 20, automationRate: 'k-rate' },
      { name: 'depth', defaultValue: 0.5, minValue: 0, maxValue: 1, automationRate: 'k-rate' },
      { name: 'wave',  defaultValue: 0, minValue: 0, maxValue: 2, automationRate: 'k-rate' }
      // wave: 0=sine, 1=triangle, 2=square
    ];
  }

  constructor() {
    super();
    this._phase = 0;
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    const output = outputs[0];
    if (!input || !input.length) return true;

    const rate = parameters.rate[0];
    const depth = parameters.depth[0];
    const wave = Math.round(parameters.wave[0]);
    const phaseInc = rate / sampleRate;

    for (let ch = 0; ch < input.length; ch++) {
      const inp = input[ch];
      const out = output[ch];
      let phase = this._phase;

      for (let i = 0; i < inp.length; i++) {
        let lfo;

        switch (wave) {
          case 0: // Sine
            lfo = Math.sin(2 * Math.PI * phase);
            break;
          case 1: // Triangle
            lfo = 2 * Math.abs(2 * (phase % 1) - 1) - 1;
            break;
          case 2: // Square (with slight smoothing)
            lfo = phase % 1 < 0.5 ? 1 : -1;
            break;
          default:
            lfo = Math.sin(2 * Math.PI * phase);
        }

        // Modulate amplitude: 1 - depth * (0.5 + 0.5 * lfo)
        const mod = 1 - depth * (0.5 + 0.5 * lfo);
        out[i] = inp[i] * mod;

        phase += phaseInc;
        if (phase >= 1) phase -= 1;
      }

      // Only update phase from first channel to keep stereo in sync
      if (ch === 0) this._phase = phase;
    }

    return true;
  }
}

registerProcessor('tremolo-processor', TremoloProcessor);
