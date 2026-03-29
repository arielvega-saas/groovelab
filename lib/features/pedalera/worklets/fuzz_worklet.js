/**
 * FuzzProcessor — AudioWorklet for cascaded fuzz distortion.
 * Four-stage tanh cascade with bias and tone control.
 * Models Big Muff Pi-style sustain circuit.
 */
class FuzzProcessor extends AudioWorkletProcessor {
  static get parameterDescriptors() {
    return [
      { name: 'sustain', defaultValue: 5,   minValue: 0.5, maxValue: 15, automationRate: 'k-rate' },
      { name: 'tone',    defaultValue: 0.5, minValue: 0,   maxValue: 1,  automationRate: 'k-rate' },
      { name: 'volume',  defaultValue: 0.4, minValue: 0,   maxValue: 1,  automationRate: 'k-rate' }
    ];
  }

  constructor() {
    super();
    this._lpState = 0;
    this._hpState = 0;
    this._hpPrevIn = 0;
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    const output = outputs[0];
    if (!input || !input.length) return true;

    const sustain = parameters.sustain[0];
    const tone = parameters.tone[0];
    const volume = parameters.volume[0];

    // Tone: blend between low-pass and high-pass branches
    // tone = 0 → dark (LP only), tone = 1 → bright (HP only)
    const lpCutoff = 800 + tone * 3000;
    const lpRc = 1 / (2 * Math.PI * lpCutoff);
    const dt = 1 / sampleRate;
    const lpAlpha = dt / (lpRc + dt);

    const hpCutoff = 200 + (1 - tone) * 1500;
    const hpRc2 = 1 / (2 * Math.PI * hpCutoff);
    const hpAlpha = hpRc2 / (hpRc2 + dt);

    for (let ch = 0; ch < input.length; ch++) {
      const inp = input[ch];
      const out = output[ch];
      let lpS = this._lpState;
      let hpS = this._hpState;
      let hpPrev = this._hpPrevIn;

      for (let i = 0; i < inp.length; i++) {
        let x = inp[i] * sustain;

        // Stage 1: first transistor stage with slight bias
        x = Math.tanh(x + 0.08);
        // Stage 2: second gain stage
        x = Math.tanh(x * 2.0 - 0.04);
        // Stage 3: clipping diodes
        x = Math.tanh(x * 1.5);
        // Stage 4: output stage
        x = Math.tanh(x * 1.2);

        // Tone stack: blend LP and HP
        lpS = lpS + lpAlpha * (x - lpS);
        const hpOut = hpAlpha * (hpS + x - hpPrev);
        hpS = hpOut;
        hpPrev = x;

        // Blend: tone crossfades between LP and HP
        const toned = lpS * (1 - tone) + hpOut * tone;

        out[i] = toned * volume;
      }

      this._lpState = lpS;
      this._hpState = hpS;
      this._hpPrevIn = hpPrev;
    }

    return true;
  }
}

registerProcessor('fuzz-processor', FuzzProcessor);
