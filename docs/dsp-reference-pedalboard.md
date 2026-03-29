# GrooveLab Pedalboard DSP Reference
## Professional Audio Engine Parameters for Web Audio API

---

# 1. PEDALS

---

## 1.1 TUNER (TC Electronic PolyTune 3 reference)

### Pitch Detection Algorithm
- **Primary**: Autocorrelation (YIN algorithm variant) -- best for guitar fundamental tracking
- **Secondary**: FFT with parabolic interpolation for initial frequency estimation
- **Hybrid approach**: FFT for coarse detection (within ~1 semitone), then autocorrelation for fine sub-cent accuracy
- YIN threshold parameter: 0.10-0.15 (lower = more accurate, higher latency)
- Window size: 2048 samples at 44.1kHz (46.4ms) -- minimum for E2 (82.4Hz) detection
- For E1 (41.2Hz bass): 4096 samples (92.9ms)

### Parameters
| Parameter | Min | Max | Default | Unit |
|---|---|---|---|---|
| Reference frequency (A4) | 430.0 | 450.0 | 440.0 | Hz |
| Detection range low | E1 (41.2Hz) | -- | -- | Hz |
| Detection range high | -- | E6 (1318.5Hz) | -- | Hz |
| Accuracy | -- | -- | +/-0.5 | cents |
| Display resolution | -- | -- | 0.1 | cents |
| Response time | -- | -- | <20 | ms |

### Note Frequency Table (A4=440Hz, Equal Temperament)
```
E1 = 41.20 Hz    E2 = 82.41 Hz    E3 = 164.81 Hz
A1 = 55.00 Hz    A2 = 110.00 Hz   A3 = 220.00 Hz
D2 = 73.42 Hz    D3 = 146.83 Hz   D4 = 293.66 Hz
G2 = 98.00 Hz    G3 = 196.00 Hz   G4 = 392.00 Hz
B2 = 123.47 Hz   B3 = 246.94 Hz   B4 = 493.88 Hz
E4 = 329.63 Hz   E5 = 659.26 Hz   E6 = 1318.51 Hz
```

### Web Audio API Mapping
- `AnalyserNode` with `fftSize: 4096` (bass) or `2048` (guitar)
- `getFloatTimeDomainData()` for autocorrelation input
- `getFloatFrequencyData()` for FFT-based coarse detection
- Process in `AudioWorkletProcessor` for consistent timing
- Cents calculation: `1200 * log2(detectedFreq / targetFreq)`

---

## 1.2 NOISE GATE (ISP Decimator II reference)

### DSP Algorithm
- RMS level detection with configurable window (2-10ms)
- Hysteresis: open threshold typically 2-6dB above close threshold to prevent chatter
- Envelope follower with separate attack/hold/release stages
- Optional look-ahead via delay line (compensated in output)

### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Threshold | -80.0 | 0.0 | -40.0 | dB | -45 dB (high gain), -30 dB (clean) |
| Attack | 0.01 | 10.0 | 0.5 | ms | 0.1 ms (fast, transparent) |
| Hold | 5.0 | 500.0 | 100.0 | ms | 80 ms |
| Release | 5.0 | 500.0 | 50.0 | ms | 30 ms (tight), 80 ms (smooth) |
| Hysteresis | 0.0 | 12.0 | 4.0 | dB | 4 dB |
| Look-ahead | 0.0 | 5.0 | 0.0 | ms | 1.5 ms |
| Detection | -- | -- | RMS | -- | RMS (peak for transients) |
| Range (depth) | -inf | 0.0 | -80.0 | dB | -80 dB (full mute) |

### Web Audio API Mapping
- **Detection**: `AnalyserNode` or `AudioWorkletProcessor` computing RMS per block
- **Gain control**: `GainNode` with `linearRampToValueAtTime()` for smooth attack/release
- **Look-ahead**: `DelayNode` (0-5ms) on the audio path, detection tapped before delay
- RMS calculation: `sqrt(sum(sample^2) / N)`
- dB conversion: `20 * log10(rms)`, floor at -120dB

### Gate State Machine
```
CLOSED -> (level > threshold) -> ATTACK -> OPEN
OPEN -> (level < threshold - hysteresis) -> HOLD -> RELEASE -> CLOSED
```

---

## 1.3 COMPRESSOR (Keeley Comp+ reference)

### DSP Algorithm
- Feed-forward compressor topology (detect at input, apply at output)
- Log-domain detection (dB scale processing)
- Ballistics: separate attack/release envelope followers
- Soft knee implemented as smooth polynomial transition around threshold
- Sidechain high-pass filter at 150Hz to prevent low-frequency pumping

### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Threshold | -60.0 | 0.0 | -24.0 | dB | -20 dB (guitar) |
| Ratio | 1.0 | 20.0 | 4.0 | :1 | 4:1 (moderate), 8:1 (heavy) |
| Attack | 0.1 | 200.0 | 10.0 | ms | 5 ms (pick attack), 20 ms (sustain) |
| Release | 10.0 | 1000.0 | 100.0 | ms | 200 ms (auto-release ideal) |
| Knee | 0.0 | 20.0 | 6.0 | dB | 6 dB (soft knee) |
| Makeup gain | -20.0 | +30.0 | 0.0 | dB | auto (compensate for GR) |
| Sidechain HPF | 20.0 | 300.0 | 150.0 | Hz | 150 Hz |
| Mix (parallel) | 0 | 100 | 100 | % | 100 (full), 50 (NY compression) |

### Gain Computation (per sample/block)
```
inputLevel_dB = 20 * log10(abs(sample))

// Soft knee
if inputLevel_dB < (threshold - knee/2):
    gainReduction = 0
elif inputLevel_dB > (threshold + knee/2):
    gainReduction = (inputLevel_dB - threshold) * (1 - 1/ratio)
else:
    // Quadratic interpolation in knee region
    x = inputLevel_dB - threshold + knee/2
    gainReduction = (1 - 1/ratio) * x^2 / (2 * knee)

outputGain_dB = -gainReduction + makeupGain
```

### Web Audio API Mapping
- `DynamicsCompressorNode` (built-in, limited control):
  - `threshold`: -100 to 0 dB
  - `knee`: 0 to 40 dB
  - `ratio`: 1 to 20
  - `attack`: 0 to 1 s
  - `release`: 0 to 1 s
  - `reduction`: read-only (current GR in dB)
- For full control: `AudioWorkletProcessor` implementing the algorithm above
- Sidechain HPF: `BiquadFilterNode` type `highpass` at 150Hz before detection

---

## 1.4 WAH (Dunlop Crybaby GCB95 reference)

### DSP Algorithm
- State-variable bandpass filter (2nd order) with sweepable center frequency
- Inductor-based resonance emulation (high Q at resonant frequency)
- The original circuit is essentially a bandpass filter with variable center frequency controlled by a potentiometer (treadle)

### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Frequency (sweep) | 350.0 | 2200.0 | 800.0 | Hz | Controlled by expression |
| Q factor | 2.0 | 15.0 | 5.0 | -- | 5.0 (classic), 10.0 (vocal) |
| Resonance peak gain | 0.0 | 24.0 | 15.0 | dB | 15 dB |
| Expression position | 0.0 | 1.0 | 0.5 | -- | Heel=0 (350Hz), Toe=1 (2.2kHz) |
| Auto-wah LFO rate | 0.5 | 8.0 | 2.0 | Hz | 2.0 Hz |
| Auto-wah depth | 0 | 100 | 80 | % | 80% |
| Envelope sensitivity | 0 | 100 | 60 | % | 60% (envelope follower mode) |

### Frequency Sweep Mapping (exponential)
```
freq = 350 * (2200/350)^position   // position: 0.0 to 1.0
freq = 350 * 6.2857^position
// At position 0.0: 350 Hz (heel down, bass)
// At position 0.5: ~930 Hz (mid)
// At position 1.0: 2200 Hz (toe down, treble)
```

### Web Audio API Mapping
- `BiquadFilterNode` with `type: "bandpass"`
- `frequency.value`: 350-2200 Hz (exponential ramp)
- `Q.value`: 2-15
- For expression pedal: `frequency.exponentialRampToValueAtTime()`
- For auto-wah: `OscillatorNode` (LFO) -> `GainNode` -> `frequency` AudioParam
- For envelope follower: `AudioWorkletProcessor` tracking RMS -> frequency mapping

---

## 1.5 OCTAVER (EHX POG2 reference)

### DSP Algorithm
- **Sub-octave (-1)**: Pitch shifting via phase vocoder or time-domain pitch synchronous overlap-add (PSOLA)
  - Simpler approach: frequency divider using zero-crossing detection
  - Professional approach: FFT-based pitch shifting (halve all bin frequencies)
- **Octave up (+1)**: Full-wave rectification (classic analog method) or pitch shift up
  - Analog emulation: `abs(sample)` produces octave-up with characteristic "ringy" tone
  - Clean digital: FFT pitch shift (double all bin frequencies)
- Low-pass filter on sub-octave to remove artifacts above fundamental

### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Sub octave level (-1) | 0 | 100 | 0 | % | 50 (subtle), 80 (prominent) |
| Octave up level (+1) | 0 | 100 | 0 | % | 40 (shimmer), 70 (12-string) |
| Dry blend | 0 | 100 | 100 | % | 70 |
| Sub LP filter | 80.0 | 500.0 | 200.0 | Hz | 200 Hz |
| Detune (sub) | -10.0 | +10.0 | 0.0 | cents | 0 |
| Detune (up) | -10.0 | +10.0 | 0.0 | cents | +3 (slight chorus) |
| Attack smoothing | 1.0 | 50.0 | 10.0 | ms | 10 ms |

### Web Audio API Mapping
- **Sub octave**: `AudioWorkletProcessor` with pitch-shift algorithm (PSOLA or phase vocoder)
  - FFT size: 2048, hop size: 512, overlap: 4x
  - Hann window for analysis/synthesis
- **Octave up (simple analog)**: `WaveShaperNode` with `abs()` curve for full-wave rectification
  ```js
  // Full-wave rectifier curve (octave up)
  const curve = new Float32Array(4096);
  for (let i = 0; i < 4096; i++) {
    const x = (i / 4096) * 2 - 1;
    curve[i] = Math.abs(x);
  }
  ```
- **Sub LP filter**: `BiquadFilterNode` type `lowpass` at 200Hz, Q=0.707
- **Mixing**: Three parallel `GainNode`s -> `ChannelMergerNode`

---

## 1.6 OVERDRIVE

### 1.6.1 Klon Centaur / Klone

#### DSP Algorithm
- Soft clipping using germanium diode pair (forward voltage ~0.3V)
- Clean blend mixed in parallel (unique to Klon: clean signal always present)
- Mid-hump EQ: broad peak at 1kHz (+3-5dB), slight bass cut below 200Hz
- The gain control crossfades between clean and clipped signal

#### Clipping Transfer Function
```
// Soft clip (tanh approximation of germanium diodes)
output = tanh(gain * input) * (1 - cleanBlend) + input * cleanBlend
// Where cleanBlend ranges from 1.0 (gain=0) to 0.0 (gain=max)
```

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Gain | 0 | 100 | 30 | % | 30 (transparent boost) |
| Treble | 0 | 100 | 50 | % | 55 |
| Output level | 0 | 100 | 70 | % | 75 (unity or slight boost) |
| Clean/drive blend | 100/0 | 0/100 | 50/50 | % | Linked to gain |
| Mid-hump freq | -- | -- | 1000 | Hz | Fixed at 1kHz |
| Mid-hump gain | -- | -- | +4 | dB | Fixed |
| Bass rolloff | -- | -- | 200 | Hz | HPF at 200Hz, 6dB/oct |

#### Web Audio API
- Pre-gain: `GainNode` (1x to 40x, mapped from 0-100%)
- Clipping: `WaveShaperNode` with `tanh` curve (oversample: '4x')
  ```js
  const curve = new Float32Array(8192);
  for (let i = 0; i < 8192; i++) {
    const x = (i / 8192) * 2 - 1;
    curve[i] = Math.tanh(x * 2.0); // Soft germanium clip
  }
  ```
- Clean blend: Parallel `GainNode` summed at output
- Mid-hump: `BiquadFilterNode` type `peaking`, freq=1000Hz, Q=0.8, gain=+4dB
- Bass rolloff: `BiquadFilterNode` type `highpass`, freq=200Hz, Q=0.707

---

### 1.6.2 Tube Screamer (Ibanez TS9)

#### DSP Algorithm
- Asymmetric soft clipping (two silicon diodes in feedback loop of op-amp)
- Signature mid-boost at 720Hz (narrow peak)
- Input buffer with bass cut at 720Hz (this creates the "thin" TS sound)
- Output is post-clipping LP filter at ~4.7kHz

#### Clipping Transfer Function
```
// Asymmetric soft clip (diodes in op-amp feedback)
if (input >= 0):
    output = input / (1 + abs(input * gain))   // softer positive clip
else:
    output = input / (1 + abs(input * gain * 1.2))  // slightly harder negative
```

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Drive (gain) | 0 | 100 | 50 | % | 40-60 (edge of breakup) |
| Tone | 0 | 100 | 50 | % | 55 (slightly bright) |
| Level | 0 | 100 | 50 | % | 70 (boost into amp) |
| Mid-boost freq | -- | -- | 720 | Hz | Fixed |
| Mid-boost gain | -- | -- | +8 | dB | Fixed |
| Input HPF | -- | -- | 720 | Hz | Fixed, 6dB/oct |
| Output LPF | -- | -- | 4700 | Hz | Linked to Tone knob |

#### Tone Control Mapping
```
// Tone knob 0-100 maps to output LPF:
lpfFreq = 800 + (toneValue / 100) * 7000   // 800 Hz to 7.8 kHz
```

#### Web Audio API
- Input HPF: `BiquadFilterNode` type `highpass`, freq=720Hz
- Pre-gain: `GainNode` (1x to 100x)
- Clipping: `WaveShaperNode` with asymmetric curve (oversample: '4x')
- Mid-boost: `BiquadFilterNode` type `peaking`, freq=720Hz, Q=2.0, gain=+8dB
- Tone: `BiquadFilterNode` type `lowpass`, freq=800-7800Hz

---

### 1.6.3 Boss Blues Driver (BD-2)

#### DSP Algorithm
- Discrete FET-based clipping (asymmetric, complex multi-stage)
- Two cascaded gain stages with different clipping characteristics
- Broader frequency response than TS (more bass, more highs)
- Asymmetric clipping produces even harmonics (tube-like warmth)

#### Clipping Transfer Function
```
// Stage 1: Soft asymmetric
stage1 = (2/pi) * atan(input * gain1 * 0.7)  // positive half
stage1 = (2/pi) * atan(input * gain1 * 1.0)  // negative half

// Stage 2: Harder clip on stage1 output
output = tanh(stage1 * gain2)
```

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Gain | 0 | 100 | 40 | % | 35-50 (blues crunch) |
| Tone | 0 | 100 | 50 | % | 50 |
| Level | 0 | 100 | 70 | % | 70 |
| Bass preservation | -- | -- | full | -- | No HPF (unlike TS) |
| Output LPF (tone) | 1000 | 10000 | 5000 | Hz | Linked to Tone knob |

#### Web Audio API
- Two cascaded `WaveShaperNode` with different curves
- Stage 1: atan-based soft clip, Stage 2: tanh-based harder clip
- No input HPF (preserves bass, unlike TS)
- Tone: `BiquadFilterNode` type `lowpass`

---

## 1.7 DISTORTION

### 1.7.1 Boss DS-1

#### DSP Algorithm
- Hard clipping to rails using silicon diode pair to ground
- Single op-amp gain stage
- Post-clipping tone circuit: single-knob LP/HP balance

#### Clipping Transfer Function
```
// Hard clip (diodes to ground)
gained = input * gain_factor  // gain_factor: 1 to 200
if gained > 0.7:   output = 0.7      // silicon diode forward voltage
elif gained < -0.7: output = -0.7
else: output = gained

// With slight softening at edges:
output = 0.7 * tanh(gained / 0.7)  // smoother approximation
```

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Distortion (gain) | 0 | 100 | 60 | % | 50-70 |
| Tone | 0 | 100 | 50 | % | 45-55 |
| Level | 0 | 100 | 50 | % | 60 |
| Clip ceiling | -- | -- | 0.7 | V | Fixed (silicon) |
| Pre-gain range | 1x | 200x | -- | -- | Mapped from Dist knob |

#### Tone Circuit
```
// DS-1 tone: crossfade between LP and HP paths
lpFreq = 1500 Hz (fixed)
hpFreq = 1500 Hz (fixed)
mix = toneValue / 100   // 0=all LP (dark), 1=all HP (bright)
output = input_lp * (1-mix) + input_hp * mix
```

#### Web Audio API
- Pre-gain: `GainNode` (1-200x)
- Clipping: `WaveShaperNode` with hard clip curve (oversample: '4x')
- Tone: Two parallel paths - `BiquadFilterNode` LP + HP at 1500Hz, crossfaded via `GainNode`s

---

### 1.7.2 ProCo RAT

#### DSP Algorithm
- Op-amp (LM308) hard clipping with diodes in feedback loop
- Unique "Filter" control: variable low-pass filter (post-distortion)
- Single gain stage with very high gain available
- Filter is a simple 1-pole LP with wide sweep

#### Clipping Transfer Function
```
// RAT: op-amp clipping with feedback diodes
// Harder than TS but with more "fizz" from the LM308 slew rate
gained = input * gain_factor
output = sign(gained) * min(abs(gained), 0.6) * (1 + 0.1 * sin(gained * 10))
// The sin term approximates the LM308 slew rate distortion

// Simplified practical version:
output = (2/pi) * atan(gained * 3.0)  // harder than tanh
```

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Distortion (gain) | 0 | 100 | 50 | % | 50 (crunch), 80 (saturated) |
| Filter (LPF) | 0 | 100 | 50 | % | 60 (slightly dark) |
| Volume | 0 | 100 | 50 | % | 50 |
| Filter freq range | 800 | 12000 | 4000 | Hz | Mapped from Filter knob |

#### Filter Mapping
```
// RAT Filter knob: 0=bright (12kHz), 100=dark (800Hz) -- INVERTED
filterFreq = 12000 * (800/12000)^(filterValue/100)
// At 0: 12000 Hz (wide open), At 100: 800 Hz (muffled)
```

#### Web Audio API
- Pre-gain: `GainNode` (1-500x)
- Clipping: `WaveShaperNode` with atan curve
- Filter: `BiquadFilterNode` type `lowpass`, freq=800-12000Hz, Q=0.707

---

### 1.7.3 Boss MT-2 Metal Zone

#### DSP Algorithm
- Dual cascaded gain stages (both with hard clipping)
- 3-band parametric EQ between stages
- Total gain: up to 70dB
- Sweepable mid frequency with variable Q

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Distortion (gain) | 0 | 100 | 70 | % | 70-90 |
| Level | 0 | 100 | 50 | % | 50 |
| Low EQ | -15 | +15 | 0 | dB | +3 dB |
| High EQ | -15 | +15 | 0 | dB | +2 dB |
| Mid freq | 200 | 5000 | 800 | Hz | 800 Hz |
| Mid level | -15 | +15 | 0 | dB | -3 to +3 dB |

#### Web Audio API
- Two cascaded `WaveShaperNode` (hard clip), each with `GainNode` pre-stage
- Parametric EQ: `BiquadFilterNode` type `peaking` for mid, `lowshelf`/`highshelf` for low/high
- Gain stage 1: `GainNode` -> `WaveShaperNode` -> EQ
- Gain stage 2: `GainNode` -> `WaveShaperNode`

---

## 1.8 FUZZ

### 1.8.1 Big Muff Pi (EHX)

#### DSP Algorithm
- 4 cascaded clipping stages (2 gain stages, sustain circuit, output)
- Each stage: common-emitter amplifier with silicon transistor clipping
- Tone control: classic "Big Muff" scoop (LP + HP mixed)
- Massive sustain from cascaded gain compression

#### Clipping Per Stage
```
// Each stage: soft clip with progressive hardening
stage1 = tanh(input * gain1)        // gain1: 5-50x
stage2 = tanh(stage1 * gain2)       // gain2: 5-50x
stage3 = tanh(stage2 * gain3)       // gain3: 2-10x
stage4 = tanh(stage3 * gain4)       // gain4: 2-5x

// Total gain: ~50-60dB with sustained square wave output
```

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Sustain (gain) | 0 | 100 | 70 | % | 70-85 |
| Tone | 0 | 100 | 50 | % | 40-60 |
| Volume | 0 | 100 | 50 | % | 60 |
| Stage gains | -- | -- | cascaded | -- | Linked to Sustain |

#### Tone Circuit (Big Muff specific)
```
// The Big Muff tone is a crossfade between LP and HP
// creating a mid-scoop at the crossover point (~1kHz)
lpFreq = 1000 Hz, 1-pole (-6dB/oct)
hpFreq = 1000 Hz, 1-pole (-6dB/oct)

// At Tone=0: full LP path (dark, bass-heavy)
// At Tone=50: both paths equal (mid-scooped)
// At Tone=100: full HP path (bright, cutting)
```

#### Web Audio API
- 4 cascaded `WaveShaperNode` instances with progressively harder curves
- Tone: Two parallel `BiquadFilterNode` (LP + HP at 1kHz), crossfade with `GainNode`
- Input coupling cap: `BiquadFilterNode` type `highpass` at 40Hz

---

### 1.8.2 Fuzz Face (Dallas Arbiter)

#### DSP Algorithm
- 2-transistor circuit (common-emitter cascade)
- **Germanium (NKT275)**: softer clip, temperature sensitive, voltage sag effects, ~0.2V forward
- **Silicon (BC108)**: harder clip, brighter, more sustain, ~0.6V forward
- Volume knob cleanup: responds to guitar volume for clean-to-fuzz range
- Bias point is critical (sets symmetry of clipping)

#### Clipping Transfer Function
```
// Germanium Fuzz Face
bias = 0.5 + biasOffset  // biasOffset: -0.3 to +0.3
gained = (input + bias) * gain
output_ge = tanh(gained * 1.5) * 0.85  // softer, lower output

// Silicon Fuzz Face
output_si = (2/pi) * atan(gained * 2.5)  // harder, brighter
```

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Fuzz (gain) | 0 | 100 | 80 | % | 75-90 |
| Volume | 0 | 100 | 50 | % | 60 |
| Bias | 0 | 100 | 65 | % | 65 (sweet spot, slight asymmetry) |
| Transistor type | 0 | 1 | 0 | -- | 0=Germanium, 1=Silicon |
| Input impedance | -- | -- | 10k | ohm | Low (loads guitar pickups) |

#### Web Audio API
- Pre-gain: `GainNode` (1-200x)
- Bias: DC offset added in `AudioWorkletProcessor`
- Clipping: `WaveShaperNode` with germanium or silicon curve
- Input loading: Simulated by slight HPF at 100Hz and level reduction
- Volume cleanup: Input `GainNode` simulates guitar volume interaction

---

### 1.8.3 Zvex Fuzz Factory

#### DSP Algorithm
- Modified Fuzz Face topology with exposed bias controls
- 5 knobs expose internal bias/feedback parameters
- Can produce gated fuzz, velcro fuzz, oscillation, and sputtery dying-battery tones
- Stab control: voltage starve (simulates low battery)

#### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Volume | 0 | 100 | 50 | % | 60 |
| Gate | 0 | 100 | 60 | % | 60 (clean gate) |
| Comp (compression) | 0 | 100 | 50 | % | 50 |
| Drive | 0 | 100 | 80 | % | 80 |
| Stab (stability) | 0 | 100 | 70 | % | 70 (stable), <30 (oscillation) |

#### Special Behaviors
```
// Gate: controls noise gate threshold linked to bias
gateThreshold = -60 + (gateValue / 100) * 50  // -60 to -10 dB

// Stab: voltage starve
supplyVoltage = 3.0 + (stabValue / 100) * 6.0  // 3V to 9V
// Below 5V: sputtery, dying, gated. Above 7V: stable, full fuzz

// Comp: feedback from output to input (self-oscillation possible)
feedbackAmount = compValue / 100 * 0.8  // 0 to 80%
```

#### Web Audio API
- Core: Two `WaveShaperNode` (Fuzz Face topology)
- Gate: `AudioWorkletProcessor` implementing threshold gate
- Stab: Modify waveshaper curves dynamically based on "voltage"
- Comp/Feedback: `DelayNode` (1 sample) in feedback loop through `GainNode`

---

## 1.9 EQ

### Boss GE-7 (7-band Graphic EQ)

#### Parameters
| Band | Center Frequency | Default Gain | Q Factor | Bandwidth |
|---|---|---|---|---|
| 1 | 100 Hz | 0 dB | 1.4 | 1.0 octave |
| 2 | 200 Hz | 0 dB | 1.4 | 1.0 octave |
| 3 | 400 Hz | 0 dB | 1.4 | 1.0 octave |
| 4 | 800 Hz | 0 dB | 1.4 | 1.0 octave |
| 5 | 1.6 kHz | 0 dB | 1.4 | 1.0 octave |
| 6 | 3.2 kHz | 0 dB | 1.4 | 1.0 octave |
| 7 | 6.4 kHz | 0 dB | 1.4 | 1.0 octave |

- Gain range per band: -15 dB to +15 dB
- Level control: -15 dB to +15 dB

### 10-Band Graphic EQ (MXR M108S reference)

| Band | Center Frequency | Q Factor |
|---|---|---|
| 1 | 31.25 Hz | 4.3 |
| 2 | 62.5 Hz | 4.3 |
| 3 | 125 Hz | 4.3 |
| 4 | 250 Hz | 4.3 |
| 5 | 500 Hz | 4.3 |
| 6 | 1 kHz | 4.3 |
| 7 | 2 kHz | 4.3 |
| 8 | 4 kHz | 4.3 |
| 9 | 8 kHz | 4.3 |
| 10 | 16 kHz | 4.3 |

- Gain range per band: -12 dB to +12 dB
- ISO standard octave spacing (each band is 1 octave apart)
- Q = 4.3 for 1/3 octave bandwidth in 10-band configuration

### Web Audio API Mapping
- Each band: `BiquadFilterNode` type `peaking`
- `frequency.value`: center frequency
- `Q.value`: Q factor (1.4 for 7-band, 4.3 for 10-band)
- `gain.value`: -15 to +15 dB
- Chain all bands in series
- Note: Q in Web Audio `peaking` filter = centerFreq / bandwidth

---

## 1.10 CHORUS (Boss CE-2W reference)

### DSP Algorithm
- Delay line modulated by low-frequency oscillator (LFO)
- Delay modulation creates pitch variation (Doppler effect)
- LFO waveform: triangle (CE-2) or sine (modern)
- Two-voice design: dry + modulated wet

### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Rate (LFO speed) | 0.1 | 10.0 | 1.0 | Hz | 0.8 Hz (subtle), 2.0 Hz (lush) |
| Depth (mod amount) | 0.0 | 10.0 | 3.0 | ms | 3.0 ms (CE-2 classic) |
| Base delay time | 1.0 | 30.0 | 7.0 | ms | 7.0 ms (CE-2: 5-14ms sweep) |
| Mix (wet/dry) | 0 | 100 | 50 | % | 40-50% |
| Feedback | -100 | 100 | 0 | % | 0 (chorus), 30 (flanger) |
| LFO waveform | 0 | 1 | 0 | -- | 0=triangle, 1=sine |
| LP filter (wet path) | 2000 | 20000 | 12000 | Hz | 12000 Hz |

### Delay Time Modulation
```
// LFO modulates delay time around base delay
currentDelay = baseDelay + depth * lfo(rate, time)

// CE-2 Classic:
baseDelay = 7.0 ms
depth = 3.0 ms
// Sweep range: 4.0 ms to 10.0 ms

// Triangle LFO:
lfo_triangle(t) = (2/pi) * asin(sin(2*pi*rate*t))

// Sine LFO:
lfo_sine(t) = sin(2*pi*rate*t)
```

### Web Audio API Mapping
- `DelayNode` with `delayTime` modulated by LFO
- LFO: `OscillatorNode` (type: 'triangle' or 'sine') -> `GainNode` (depth) -> `DelayNode.delayTime`
- Base delay: `DelayNode.delayTime.value = 0.007` (7ms)
- LFO depth gain: `GainNode.gain.value = 0.003` (3ms in seconds)
- LFO rate: `OscillatorNode.frequency.value = 1.0`
- Mix: Parallel dry `GainNode` + wet `GainNode` summed
- LP on wet: `BiquadFilterNode` type `lowpass` at 12kHz
- Feedback: `GainNode` from delay output back to delay input

---

## 1.11 PHASER (MXR Phase 90 reference)

### DSP Algorithm
- Chain of allpass filters with LFO-modulated center frequency
- Each allpass stage shifts phase by 0-180 degrees depending on frequency
- When mixed with dry signal, creates notches at frequencies where phase = 180 degrees
- More stages = more notches = more complex sweep

### Allpass Filter Stages
| Phaser Type | Stages | Notches | Character |
|---|---|---|---|
| Phase 45 | 2 | 1 | Subtle, vintage |
| Phase 90 | 4 | 2 | Classic, musical |
| Phase 100 | 6 | 3 | Rich, deep |
| Small Stone | 4 or 6 | 2-3 | Variable |
| 12-stage | 12 | 6 | Very complex, lush |

### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Rate (LFO speed) | 0.05 | 10.0 | 0.5 | Hz | 0.5 Hz (Phase 90 sweet spot) |
| Depth | 0 | 100 | 100 | % | 100 (Phase 90 is fixed depth) |
| Feedback | 0 | 95 | 0 | % | 0 (Phase 90), 50 (more resonant) |
| Stages | 2 | 12 | 4 | -- | 4 (Phase 90 classic) |
| Sweep range low | 200 | 800 | 300 | Hz | 300 Hz |
| Sweep range high | 1500 | 8000 | 3000 | Hz | 3000 Hz |
| Mix | 0 | 100 | 50 | % | 50 (equal dry+wet) |
| LFO waveform | 0 | 2 | 0 | -- | 0=sine, 1=triangle, 2=square |

### Allpass Center Frequency Sweep
```
// LFO sweeps allpass center frequency exponentially
lfoValue = sin(2 * pi * rate * t)  // -1 to +1

// Map LFO to frequency (exponential sweep)
freqMin = 300   // Hz
freqMax = 3000  // Hz
currentFreq = freqMin * (freqMax/freqMin)^((lfoValue + 1) / 2)
// Sweeps from 300 Hz to 3000 Hz
```

### Web Audio API Mapping
- Each stage: `BiquadFilterNode` type `allpass`
- `frequency.value`: modulated by LFO (300-3000 Hz)
- LFO: `OscillatorNode` -> `GainNode` -> all allpass `frequency` AudioParams
- LFO center: `(log(3000) + log(300)) / 2` in log domain
- LFO depth: `(log(3000) - log(300)) / 2`
- Feedback: Output of last allpass -> `GainNode` -> input of first allpass
- Mix: Dry `GainNode` (0.5) + Wet `GainNode` (0.5) summed
- 4 stages for Phase 90 emulation

---

## 1.12 DELAY (Strymon Timeline / Boss DD-500 reference)

### DSP Algorithm
- Circular buffer (delay line) with read/write pointers
- Interpolation for non-integer delay times (linear or cubic)
- Feedback path with optional filtering (LP/HP)
- Modulation: secondary LFO on delay time for analog character

### Parameters
| Parameter | Min | Max | Default | Unit | Pro Default |
|---|---|---|---|---|---|
| Delay time | 1.0 | 2000.0 | 400.0 | ms | 375 ms (dotted 8th at 120BPM) |
| Feedback | 0 | 95 | 35 | % | 30-40% (2-3 repeats) |
| Mix (wet/dry) | 0 | 100 | 30 | % | 25-35% |
| Tone (LP on repeats) | 1000 | 20000 | 8000 | Hz | 6000 Hz (analog warmth) |
| HP on repeats | 20 | 500 | 80 | Hz | 80 Hz (removes mud) |
| Modulation rate | 0.0 | 5.0 | 0.5 | Hz | 0.5 Hz |
| Modulation depth | 0.0 | 5.0 | 0.0 | ms | 0.5 ms (subtle analog) |
| Stereo spread | 0 | 100 | 0 | % | 50 (ping-pong) |
| Time subdivision | -- | -- | 1/4 | -- | dotted 1/8 most common |

### Tap Tempo Subdivisions
| Subdivision | Multiplier | Use |
|---|---|---|
| Whole note | 4.0 | Ambient |
| Dotted half | 3.0 | Atmospheric |
| Half note | 2.0 | Slow ballads |
| Dotted quarter | 1.5 | Country, Edge-style |
| Quarter note | 1.0 | Standard sync |
| Dotted eighth | 0.75 | **Most popular** (U2, Hillsong) |
| Eighth note | 0.5 | Fast rhythmic |
| Triplet | 0.667 | Shuffle feel |
| Sixteenth | 0.25 | Slapback |

### Delay Time from BPM
```
quarterNoteMs = 60000 / bpm
delayTime = quarterNoteMs * subdivision_multiplier

// Example: 120 BPM, dotted eighth
delayTime = (60000 / 120) * 0.75 = 375 ms
```

### Feedback Behavior (number of audible repeats)
```
// Approximate repeats before -60dB:
repeats = -60 / (20 * log10(feedback/100))
// feedback=30%: ~5 repeats
// feedback=50%: ~10 repeats
// feedback=90%: ~57 repeats (near infinite)
// feedback=95%: ~114 repeats (ambient wash)
```

### Web Audio API Mapping
- `DelayNode` with `delayTime.value`: 0.001 to 2.0 seconds
- Feedback: `GainNode` from delay output back to delay input
- Tone: `BiquadFilterNode` type `lowpass` in feedback path
- HP: `BiquadFilterNode` type `highpass` in feedback path
- Mix: Parallel dry/wet `GainNode` paths
- Modulation: `OscillatorNode` -> `GainNode` -> `DelayNode.delayTime` (subtle)
- Stereo: Two `DelayNode` with offset times (L: time, R: time * 0.75 or complementary)
- Tap tempo: Calculate time from two tap timestamps

---

## 1.13 REVERB (Strymon BigSky reference)

### Types and Parameters

#### Room
| Parameter | Min | Max | Default | Unit |
|---|---|---|---|---|
| Decay | 0.2 | 1.5 | 0.6 | s |
| Pre-delay | 0 | 50 | 10 | ms |
| Damping (LP) | 2000 | 12000 | 6000 | Hz |
| Diffusion | 30 | 100 | 70 | % |
| Size | 0 | 100 | 40 | % |
| Mix | 0 | 100 | 25 | % |

#### Hall
| Parameter | Min | Max | Default | Unit |
|---|---|---|---|---|
| Decay | 1.0 | 10.0 | 3.0 | s |
| Pre-delay | 0 | 100 | 30 | ms |
| Damping (LP) | 1500 | 10000 | 4000 | Hz |
| Diffusion | 50 | 100 | 85 | % |
| Size | 0 | 100 | 70 | % |
| Mix | 0 | 100 | 30 | % |

#### Plate
| Parameter | Min | Max | Default | Unit |
|---|---|---|---|---|
| Decay | 0.5 | 8.0 | 2.0 | s |
| Pre-delay | 0 | 80 | 15 | ms |
| Damping (LP) | 3000 | 15000 | 8000 | Hz |
| Diffusion | 70 | 100 | 90 | % |
| Modulation | 0 | 100 | 30 | % |
| Mix | 0 | 100 | 30 | % |

#### Spring
| Parameter | Min | Max | Default | Unit |
|---|---|---|---|---|
| Decay | 0.5 | 4.0 | 1.5 | s |
| Pre-delay | 0 | 30 | 5 | ms |
| Damping (LP) | 2000 | 8000 | 4000 | Hz |
| Drip (transient splash) | 0 | 100 | 50 | % |
| Mix | 0 | 100 | 25 | % |

#### Shimmer
| Parameter | Min | Max | Default | Unit |
|---|---|---|---|---|
| Decay | 2.0 | 30.0 | 8.0 | s |
| Pre-delay | 0 | 100 | 20 | ms |
| Pitch shift | +12 | +24 | +12 | semitones |
| Shimmer amount | 0 | 100 | 50 | % |
| Damping (LP) | 2000 | 12000 | 6000 | Hz |
| Mix | 0 | 100 | 40 | % |

### DSP Algorithm (Freeverb / Schroeder-Moorer)
```
// Feedback Delay Network (FDN) reverb structure:
// 8-16 parallel comb filters -> 4 series allpass diffusers

// Comb filter delays (in samples at 44.1kHz):
combDelays = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116]
// Each comb: feedback = 0.84 (for ~2s decay)

// Allpass delays:
allpassDelays = [225, 556, 441, 341]
// Each allpass: coefficient = 0.5

// Damping: 1-pole LP in each comb feedback path
// dampingCoeff: 0.0 (no damping) to 1.0 (max damping)
```

### Decay to Feedback Coefficient
```
// For a comb filter with delay D samples:
feedback = 10^(-3 * D / (decayTime * sampleRate))

// Example: decay=2s, delay=1557 samples, sr=44100
feedback = 10^(-3 * 1557 / (2 * 44100)) = 0.84
```

### Web Audio API Mapping
- **ConvolverNode** (IR-based): Load impulse response buffers for each type
  - Room IR length: 0.5-1.5s
  - Hall IR length: 2-6s
  - Plate IR length: 1-4s
  - Spring IR length: 0.5-2s
- **Algorithmic** (AudioWorkletProcessor): FDN implementation for real-time parameter control
- Pre-delay: `DelayNode` before reverb
- Damping: `BiquadFilterNode` type `lowpass` in feedback paths
- Mix: Parallel dry/wet `GainNode` paths
- Shimmer: Pitch shift in feedback path using phase vocoder `AudioWorkletProcessor`
- Diffusion: Number/density of allpass stages
- Modulation: Slight LFO on internal delay times

---

## 1.14 LOOPER (Boss RC-5 reference)

### Parameters
| Parameter | Value | Notes |
|---|---|---|
| Sample rate | 44100 | Hz, minimum for quality |
| Bit depth | 16 | bit minimum, 32-bit float internal |
| Max loop time | 13 hours (RC-5) | Practical: 5 min per loop |
| Channels | 1 (mono) or 2 (stereo) | |
| Overdub capability | Yes | Mix with existing loop |
| Undo/Redo | 1 level | Last overdub |
| Half-speed | Yes | Drops octave, doubles length |
| Reverse | Yes | Plays buffer backwards |
| Stop modes | Immediate / Fade (50ms) | Fade prevents click |
| Quantize | Off / Free / Beat-sync | Beat-sync for rhythmic loops |

### Web Audio API Mapping
- Recording: `MediaStreamAudioSourceNode` -> `AudioWorkletProcessor` (capture to Float32Array)
- Playback: `AudioBufferSourceNode` with `loop = true`
- Overdub: Mix new input with existing buffer in `AudioWorkletProcessor`
- Undo: Store previous buffer state before each overdub
- Half-speed: `AudioBufferSourceNode.playbackRate.value = 0.5`
- Reverse: Reverse the Float32Array buffer data
- Fade out: `GainNode.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.05)`

---

# 2. AMPLIFIERS

---

## 2.1 Fender Twin Reverb '65

### Clean Channel
| Parameter | Value | Notes |
|---|---|---|
| Headroom | ~12W before breakup | Stays clean up to ~6 on volume |
| Input impedance | 1M ohm | Standard guitar input |
| Preamp tubes | 4x 12AX7 | High gain factor |
| Power tubes | 4x 6L6GC | American clean |
| Power output | 85W | Very loud clean |
| Speaker | 2x 12" Jensen C12N | Bright, chimey |

### EQ Frequencies (Fender tone stack)
| Control | Center Frequency | Type | Range |
|---|---|---|---|
| Bass | 100 Hz | Shelving | -15 to +5 dB |
| Mid | 400 Hz | Scoop (fixed) | -10 dB at noon |
| Treble | 2.5 kHz | Shelving | -15 to +5 dB |
| Bright switch | 3.5 kHz | Treble bypass cap | +6 dB above 3.5kHz |

### Fender Tone Stack (interactive mid scoop)
```
// Fender tone stack is passive and inherently scoops mids
// Even with all controls at noon, there is a -10dB dip at ~400Hz
// Bass and Treble interact: turning up both increases the scoop

// Approximate digital implementation:
bass_shelf:    freq=100Hz, gain=bassKnob, Q=0.7
mid_scoop:     freq=400Hz, gain=-10 + midKnob*2, Q=1.5  // mid is actually a depth control
treble_shelf:  freq=2500Hz, gain=trebleKnob, Q=0.7
```

### Power Section (6L6GC)
| Parameter | Value |
|---|---|
| Sag | Low (high headroom, stiff power supply) |
| Compression onset | Above 75W |
| Harmonic content | Primarily even harmonics (warm) |
| Negative feedback | Moderate (tighter bass, less distortion) |

### Reverb Circuit
- Accutronics 6-spring tank (type 4AB3C1B)
- Dwell: fixed at moderate level
- Decay: ~2.5 seconds
- Pre-delay: ~30ms (spring travel time)
- Character: drip, splash on transients, metallic shimmer
- Frequency response: band-limited 200Hz-4kHz

### Web Audio API Implementation
```
Input -> HPF(80Hz) ->
  GainNode(preamp, 1-5x) ->
  WaveShaperNode(very mild soft clip, only at high gain) ->
  Tone Stack (3x BiquadFilterNode) ->
  GainNode(power amp, slight compression via AudioWorklet) ->
  Cabinet IR (ConvolverNode)
```

---

## 2.2 Marshall JCM800 2203

### Preamp Structure
| Stage | Gain | Clipping | Notes |
|---|---|---|---|
| V1a (12AX7) | ~60x | None (below clipping) | Input buffer/gain |
| V1b (12AX7) | ~60x | Soft clip at high gain | Cascaded gain stage |
| Tone stack | Passive loss ~-20dB | None | Marshall/James topology |
| V2a (12AX7) | ~60x | Clips with gain above 5 | Recovery stage |

### Marshall/James Tone Stack
| Control | Frequency | Interaction | Range |
|---|---|---|---|
| Bass | 100 Hz | Interacts with Mid | -15 to +5 dB |
| Mid | 650 Hz | Controls scoop depth | -15 to +5 dB |
| Treble | 3.2 kHz | Interacts with Presence | -15 to +5 dB |
| Presence | 4.7 kHz | Post-power amp NFB filter | -5 to +10 dB |

```
// Marshall tone stack: similar to Fender but less mid-scoop
// Mid control actually varies the depth of the scoop (unlike Fender)
// At noon: ~-5dB dip at 650Hz (less than Fender's -10dB)
bass_shelf:    freq=100Hz, gain=bass, Q=0.7
mid_scoop:     freq=650Hz, gain=mid, Q=1.2
treble_shelf:  freq=3200Hz, gain=treble, Q=0.7
presence:      freq=4700Hz, gain=presence, Q=0.7  // post-power-amp
```

### Power Section (4x EL34)
| Parameter | Value |
|---|---|
| Output power | 100W |
| Sag | Moderate (EL34 characteristic) |
| Compression onset | Above 60W |
| Harmonic content | Odd harmonics prominent (aggressive) |
| Negative feedback | Low-moderate (raw, responsive) |
| Class | AB push-pull |

### Gain Structure
```
// Preamp gain knob maps to cascaded tube stages:
// gain 0-3: clean headroom
// gain 3-6: edge of breakup, touch sensitive
// gain 6-8: moderate crunch, classic rock
// gain 8-10: full saturation, hard rock

preampGain = 1.0 + (gainKnob / 10) * 200  // 1x to 200x total
// Each stage clips at approximately ±1.5V (tube grid limiting)
```

### Web Audio API Implementation
```
Input -> HPF(70Hz) ->
  GainNode(V1a) -> WaveShaperNode(soft tube clip) ->
  GainNode(V1b) -> WaveShaperNode(soft tube clip) ->
  Tone Stack (4x BiquadFilterNode) ->
  GainNode(V2a recovery) -> WaveShaperNode(tube clip) ->
  GainNode(power amp) -> WaveShaperNode(power tube compression) ->
  BiquadFilterNode(presence) ->
  Cabinet IR (ConvolverNode)
```

---

## 2.3 Mesa/Boogie Dual Rectifier

### Channel Parameters
| Channel | Gain Range | Character | Clipping |
|---|---|---|---|
| Clean | 1-5x | Fender-like clean | None to slight |
| Raw | 5-100x | Crunchy, open | Moderate, asymmetric |
| Modern | 100-1000x | Saturated, tight | Heavy, compressed |

### Gain Structure Per Channel
```
// Clean: Single gain stage, Fender-ish
clean_gain = gainKnob * 5

// Raw: 3 cascaded stages, looser feel
raw_gain_total = gainKnob^2 * 100

// Modern: 5 cascaded stages, extremely compressed
modern_gain_total = gainKnob^3 * 1000
// Each stage clips at ±1.2V with soft saturation
```

### EQ (Mesa specific)
| Control | Frequency | Notes |
|---|---|---|
| Bass | 80 Hz | Deep bass, can be boomy |
| Mid | 750 Hz | Critical for "scooped" vs "present" |
| Treble | 2.2 kHz | Bite and articulation |
| Presence | 5.0 kHz | Air and fizz |

### Bold vs Spongy (Rectifier Mode)
```
// Bold (silicon rectifier): tight, immediate, full power
sagAmount = 0.02      // 2% voltage drop under load
attackSpeed = 0.1ms   // instant response

// Spongy (tube rectifier): loose, compressed, saggy
sagAmount = 0.15      // 15% voltage drop under load
attackSpeed = 5ms     // slower attack, natural compression
// Spongy reduces effective output by ~20%
```

### V-Shape EQ Tendency
```
// The "scooped" modern metal sound:
bass = +8 dB at 80Hz
mid = -8 dB at 750Hz
treble = +6 dB at 2.2kHz
presence = +4 dB at 5kHz
```

### Web Audio API Implementation
```
Input ->
  [Channel Select: Clean/Raw/Modern gain stages] ->
  5x cascaded (GainNode -> WaveShaperNode) ->
  Tone Stack (4x BiquadFilterNode) ->
  Sag simulation (AudioWorkletProcessor: envelope-following gain reduction) ->
  Cabinet IR (ConvolverNode)
```

---

## 2.4 Vox AC30

### Top Boost Channel
| Parameter | Value | Notes |
|---|---|---|
| Preamp tubes | EF86 (Normal), 12AX7 (Top Boost) | |
| Power tubes | 4x EL84 | Class A, low headroom |
| Output power | 30W | Breaks up early |
| Breakup onset | ~15W (halfway on volume) | |

### EQ Characteristics
| Control | Frequency | Notes |
|---|---|---|
| Bass | 120 Hz | Vox "thick" bass |
| Treble cut | 5 kHz | Cut-style control (0=bright, 10=dark) |
| Tone cut | 4 kHz | Additional high cut in NFB loop |
| Mid character | 1 kHz | Fixed mid-presence (chimey) |

```
// Vox has a unique "cut" control instead of presence:
// Cut is a treble bleed from the power amp NFB
// Cut at 0: maximum brightness, jangly, chimey
// Cut at 10: dark, muffled
cut_lpf: freq = 20000 - (cutKnob/10) * 17000  // 20kHz down to 3kHz
```

### Class A Power Section
| Parameter | Value |
|---|---|
| Compression | Heavy (Class A saturates evenly) |
| Headroom | Low (breaks up around volume 5) |
| Harmonics | Strong even harmonics (warm, musical) |
| Sag | High (tube rectifier, Class A current draw) |
| Feel | Very touch-responsive, dynamic |

### Tremolo Circuit (Vox Vibrato)
| Parameter | Min | Max | Default | Unit |
|---|---|---|---|---|
| Speed | 2.0 | 12.0 | 5.0 | Hz |
| Depth | 0 | 100 | 50 | % |
| Waveform | -- | -- | Triangle | -- |

```
// Vox tremolo is actually amplitude modulation via bias modulation
// This creates a slightly asymmetric tremolo (more cut than boost)
tremGain = 1.0 - depth * (0.5 + 0.5 * triangle(speed * t))
// Range: 1.0 (no trem) to 1.0-depth (full cut)
```

### Web Audio API Implementation
```
Input -> HPF(80Hz) ->
  GainNode(preamp) -> WaveShaperNode(tube clip, soft) ->
  Tone Stack (BiquadFilterNode: bass shelf + treble cut) ->
  GainNode(power amp, Class A compression) ->
  WaveShaperNode(power tube saturation, heavy even harmonics) ->
  BiquadFilterNode(cut control, lowpass) ->
  [Optional: GainNode modulated by OscillatorNode for tremolo] ->
  Cabinet IR (ConvolverNode)
```

---

## 2.5 Peavey 5150 II (EVH)

### Channel Parameters
| Channel | Gain Range | Character |
|---|---|---|
| Rhythm (Green) | Low-moderate | Crunch, usable clean at low gain |
| Lead (Red) | Extreme high gain | Saturated, compressed, tight |

### Gain Structure
```
// Rhythm channel: 3 gain stages
rhythm_gain = gainKnob * 50  // up to 50x

// Lead channel: 5 cascaded gain stages with cathode follower
lead_gain = gainKnob^2 * 2000  // up to 2000x total
// Each stage has a coupling cap HPF at ~70Hz (tight bass)
```

### EQ
| Control | Frequency | Range |
|---|---|---|
| Low | 100 Hz | -15 to +10 dB |
| Mid | 800 Hz | -15 to +10 dB |
| High | 3 kHz | -15 to +10 dB |
| Resonance | 80 Hz | 0 to +10 dB (post power amp) |
| Presence | 5 kHz | 0 to +10 dB (post power amp) |

### Resonance Control
```
// Resonance is a bass boost in the power amp negative feedback loop
// It adds a peak at ~80Hz that tightens the low end
resonance_eq: freq=80Hz, Q=2.0, gain = resonanceKnob * 10  // 0 to +10dB
// This is NOT the same as the preamp bass control
```

### Power Section (4x 6L6GC)
| Parameter | Value |
|---|---|
| Output | 120W |
| Sag | Very low (stiff supply, designed for tightness) |
| Compression | Minimal until high volume |
| Character | Tight, precise, modern |

---

## 2.6 Orange TH30

### Channels
| Channel | Character | Gain |
|---|---|---|
| Clean | Warm, mid-forward, breaks up at ~60% volume | Low-moderate |
| Dirty | Thick, compressed, "Orange crunch" | Moderate-high |

### EQ (Orange is simple)
| Control | Frequency | Notes |
|---|---|---|
| Bass | 120 Hz | Warm, round |
| Mid | 800 Hz | **Orange mid-forward voicing** (+3dB inherent) |
| Treble | 3.5 kHz | Smooth, never harsh |

```
// Orange amps have an inherent mid-forward character
// Even flat EQ settings have ~+3dB at 600-1000Hz
// The treble never gets harsh due to built-in HF rolloff at ~7kHz
inherent_mid_bump: freq=800Hz, Q=1.0, gain=+3dB (always active)
inherent_hf_rolloff: freq=7000Hz, type=lowpass, Q=0.5
```

### Power Section (4x EL84)
| Parameter | Value |
|---|---|
| Output | 30W / 15W / 7W switchable |
| Sag | Moderate to high |
| Character | Warm, thick, compressed at lower wattages |

---

## 2.7 Friedman BE-100

### Channels
| Channel | Character | Gain Range |
|---|---|---|
| HBE | Plexi-style crunch, dynamic | Low to moderate |
| BE | High-gain modified Marshall | Moderate to extreme |

### EQ (Modified Marshall topology)
| Control | Frequency | Notes |
|---|---|---|
| Bass | 100 Hz | Tight, focused |
| Mid | 700 Hz | Present, cutting |
| Treble | 3.5 kHz | Smooth top end |
| Presence | 5.0 kHz | Air |

### Tight/Loose Switch
```
// Tight: HPF at 120Hz before gain stages (removes bass before distortion)
tight_hpf: freq=120Hz, Q=0.707, type=highpass

// Loose: HPF at 60Hz (more bass into distortion = fatter, less defined)
loose_hpf: freq=60Hz, Q=0.707, type=highpass
```

### Gain Structure
```
// HBE: 2 gain stages (Plexi-like)
hbe_gain = gainKnob * 80  // Marshall Plexi territory

// BE: 4 gain stages (hot-rodded Marshall)
be_gain = gainKnob^2 * 500  // More gain, but clear note definition
// Key: inter-stage coupling caps are selected for clarity
```

---

## 2.8 Fender Deluxe Reverb '65

### Clean Channel
| Parameter | Value | Notes |
|---|---|---|
| Headroom | ~3-4 on volume dial | Breaks up very musically |
| Output power | 22W | Perfect club amp |
| Power tubes | 2x 6V6GT | Warm, early breakup |
| Speaker | 1x 12" Jensen C12N or Oxford | |

### EQ (Fender tone stack, same topology as Twin but different values)
| Control | Frequency | Range |
|---|---|---|
| Bass | 100 Hz | -12 to +3 dB |
| Treble | 2.5 kHz | -12 to +3 dB |
| Mid scoop | 400 Hz | Fixed -8dB at noon |

### Breakup Characteristics
```
// Volume 1-3: Clean, headroom
// Volume 3-5: Edge of breakup, touch sensitive (THE sweet spot)
// Volume 5-7: Moderate breakup, bluesy
// Volume 7-10: Full crunch, compressed, sustain

// 6V6 power tube breakup:
// Softer than 6L6, earlier onset, more even harmonics
// Creates "bloom" effect: notes start clean, then compress and sustain
```

### Spring Reverb Circuit
- Accutronics 2-spring tank (type 4AB3C1A)
- Shorter springs than Twin = faster decay
- Decay: ~1.8 seconds
- Pre-delay: ~25ms
- Drippier than Twin due to fewer springs

### Web Audio API
```
Input -> HPF(70Hz) ->
  GainNode(preamp) -> WaveShaperNode(6V6 soft clip, early onset) ->
  Tone Stack (3x BiquadFilterNode) ->
  GainNode(power amp) -> WaveShaperNode(6V6 power compression) ->
  [Spring reverb: ConvolverNode or allpass chain] ->
  Cabinet IR (ConvolverNode)
```

---

# 3. CABINETS (IR Characteristics)

---

## 3.1 Marshall 1960A 4x12 (Celestion G12T-75)

| Parameter | Value |
|---|---|
| Speaker resonance | 75 Hz |
| Usable range | 75 Hz - 5.5 kHz |
| High frequency rolloff | -12 dB/oct above 5.5 kHz |
| Presence peak | 2.5 kHz (+3 dB) |
| Bass character | Tight, controlled (closed back) |
| Room modes | 120 Hz, 240 Hz (reinforcement) |
| IR length needed | 200-500ms (tight cabinet) |
| Key character | Bright, aggressive, rock/metal standard |

### EQ Approximation
```
hpf: 75Hz, Q=1.0 (speaker resonance)
peak1: 120Hz, +2dB, Q=2.0 (bass bump)
peak2: 2500Hz, +3dB, Q=1.5 (presence)
lpf: 5500Hz, -12dB/oct (speaker rolloff)
notch: 4000Hz, -2dB, Q=3.0 (cone breakup dip)
```

---

## 3.2 Orange PPC212 (Celestion Vintage 30)

| Parameter | Value |
|---|---|
| Speaker resonance | 70 Hz |
| Usable range | 70 Hz - 6 kHz |
| High frequency rolloff | -10 dB/oct above 6 kHz |
| Presence peak | 3.5 kHz (+5 dB, V30 characteristic) |
| Mid character | Prominent 1-2 kHz (+3 dB) |
| Bass character | Full, warm (open-back option available) |
| IR length needed | 300-600ms |
| Key character | Mid-forward, warm, aggressive presence peak |

### EQ Approximation
```
hpf: 70Hz, Q=1.2
peak1: 150Hz, +3dB, Q=1.5 (warmth)
peak2: 1500Hz, +3dB, Q=1.0 (midrange forward)
peak3: 3500Hz, +5dB, Q=2.0 (V30 presence spike)
lpf: 6000Hz, -10dB/oct
notch: 5000Hz, -3dB, Q=4.0 (V30 dip before rolloff)
```

---

## 3.3 Mesa Rectifier 4x12 (Celestion Vintage 30)

| Parameter | Value |
|---|---|
| Speaker resonance | 70 Hz |
| Usable range | 65 Hz - 5.5 kHz |
| High frequency rolloff | -14 dB/oct above 5.5 kHz (deeper cab = more rolloff) |
| Presence peak | 3.5 kHz (+4 dB) |
| Bass character | Deep, massive (oversized closed back) |
| Low-mid bump | 200 Hz (+4 dB, cabinet resonance) |
| IR length needed | 400-800ms (large cabinet, more resonance) |
| Key character | Deep, massive, dark, scooped with V30 presence |

### EQ Approximation
```
hpf: 65Hz, Q=1.5
peak1: 200Hz, +4dB, Q=1.2 (massive low-mid)
scoop: 500Hz, -2dB, Q=1.5 (natural V-shape)
peak2: 3500Hz, +4dB, Q=2.0 (V30)
lpf: 5500Hz, -14dB/oct (darker than Marshall)
```

---

## 3.4 Fender Twin 2x12 (Jensen C12N)

| Parameter | Value |
|---|---|
| Speaker resonance | 90 Hz |
| Usable range | 90 Hz - 8 kHz |
| High frequency rolloff | -8 dB/oct above 8 kHz (brighter than Celestion) |
| Presence peak | 2 kHz (+2 dB, gentle) |
| Bass character | Open, airy (open back) |
| High end | Extended, chimey, bell-like |
| IR length needed | 200-400ms |
| Key character | Bright, open, clean, chimey, sparkly |

### EQ Approximation
```
hpf: 90Hz, Q=0.8 (softer resonance)
peak1: 200Hz, +1dB, Q=1.0 (gentle warmth)
peak2: 2000Hz, +2dB, Q=0.8 (clarity)
peak3: 5000Hz, +1dB, Q=1.0 (sparkle)
lpf: 8000Hz, -8dB/oct (extended compared to Celestion)
```

---

## 3.5 Vox V212C (Celestion G12M Greenback)

| Parameter | Value |
|---|---|
| Speaker resonance | 75 Hz |
| Usable range | 75 Hz - 5 kHz |
| High frequency rolloff | -12 dB/oct above 5 kHz |
| Presence peak | 2.2 kHz (+4 dB) |
| Mid character | Rich, warm, "woody" |
| Bass character | Controlled, focused (semi-open back) |
| IR length needed | 300-500ms |
| Key character | Classic British crunch tone, woody, warm presence |

### EQ Approximation
```
hpf: 75Hz, Q=1.0
peak1: 180Hz, +2dB, Q=1.2 (warmth)
peak2: 700Hz, +2dB, Q=1.0 (woody mids)
peak3: 2200Hz, +4dB, Q=1.5 (Greenback presence)
lpf: 5000Hz, -12dB/oct
notch: 3500Hz, -2dB, Q=3.0 (Greenback character dip)
```

---

# 4. MICROPHONES

---

## 4.1 Shure SM57

| Parameter | Value |
|---|---|
| Type | Dynamic, cardioid |
| Frequency response | 40 Hz - 15 kHz |
| Key characteristics | Presence peak at 5-6 kHz (+5-7 dB) |
| Proximity effect | +6 dB at 100 Hz when < 5cm |
| Roll-off below | 200 Hz (gentle -3 dB/oct) |
| Industry standard for | Guitar cabs, snare drum |

### Frequency Response EQ Curve
```
hpf: 40Hz, -18dB/oct (transformer rolloff)
shelf: 200Hz, -2dB (gentle bass rolloff in midfield)
peak1: 2000Hz, +2dB, Q=1.0 (upper-mid clarity)
peak2: 5500Hz, +6dB, Q=1.5 (presence peak - THE SM57 sound)
peak3: 8000Hz, +3dB, Q=2.0 (air)
lpf: 15000Hz, -12dB/oct (capsule rolloff)
```

---

## 4.2 Sennheiser MD421

| Parameter | Value |
|---|---|
| Type | Dynamic, cardioid |
| Frequency response | 30 Hz - 17 kHz |
| Key characteristics | Flatter than SM57, fuller bass, less presence peak |
| Proximity effect | Moderate |
| 5-position bass rolloff switch | Flat to -10dB at 100Hz |
| Used for | Guitar cabs, toms, bass cabs, broadcast |

### Frequency Response EQ Curve
```
hpf: 30Hz, -18dB/oct
// Relatively flat 100Hz-10kHz
peak1: 1500Hz, +2dB, Q=0.8 (broad upper-mid presence)
peak2: 4000Hz, +3dB, Q=1.5 (subtle presence, less than SM57)
lpf: 17000Hz, -12dB/oct
// Bass rolloff switch (M position = most cut):
// M: hpf at 300Hz, S: hpf at 100Hz, full range: no HPF
```

---

## 4.3 Neumann U87

| Parameter | Value |
|---|---|
| Type | Large diaphragm condenser, multi-pattern |
| Frequency response | 20 Hz - 20 kHz |
| Key characteristics | Slight presence rise at 8-12 kHz, very smooth |
| Patterns | Omni, Cardioid, Figure-8 |
| Self-noise | 12 dBA |
| Max SPL | 127 dB (with pad: 140 dB) |
| Used for | Room mic, acoustic guitar, vocals (not typical for close-mic cabs) |

### Frequency Response EQ Curve
```
// Very flat with subtle presence
hpf: 20Hz, -12dB/oct
peak1: 8000Hz, +2dB, Q=0.5 (broad, subtle presence rise)
peak2: 12000Hz, +3dB, Q=1.0 (air/sheen)
lpf: 20000Hz, -6dB/oct (gentle rolloff)
// HPF switch: 80Hz, -12dB/oct
// Pad: -10dB
```

---

## 4.4 Royer R-121

| Parameter | Value |
|---|---|
| Type | Ribbon, figure-8 (bidirectional) |
| Frequency response | 30 Hz - 15 kHz |
| Key characteristics | Smooth, dark, natural, NO presence peak |
| Proximity effect | Strong (figure-8 pattern) |
| Max SPL | 135 dB |
| Used for | Guitar cabs (pairs beautifully with SM57), brass |

### Frequency Response EQ Curve
```
hpf: 30Hz, -12dB/oct
// Remarkably flat from 40Hz to 10kHz
// Gentle, natural rolloff above 10kHz (no harshness)
shelf: 10000Hz, -3dB (gentle high rolloff)
lpf: 15000Hz, -12dB/oct
// The key: NO presence peak = smooth, vintage tone
// Often blended 50/50 with SM57 for best of both worlds
```

---

## 4.5 Sennheiser E609

| Parameter | Value |
|---|---|
| Type | Dynamic, supercardioid |
| Frequency response | 40 Hz - 15 kHz |
| Key characteristics | Flat design for draping over cab, scooped mids |
| Mid character | Slight dip at 500-800 Hz (-2 dB) |
| Presence | Moderate peak at 3-5 kHz (+4 dB) |
| Used for | Guitar cabs (live and studio, "hang and go") |

### Frequency Response EQ Curve
```
hpf: 40Hz, -18dB/oct
peak1: 150Hz, +2dB, Q=1.0 (proximity/bass)
scoop: 600Hz, -2dB, Q=1.0 (characteristic mid scoop)
peak2: 3500Hz, +4dB, Q=1.2 (presence, less sharp than SM57)
lpf: 15000Hz, -12dB/oct
```

---

## 4.6 AKG C414

| Parameter | Value |
|---|---|
| Type | Large diaphragm condenser, multi-pattern |
| Frequency response | 20 Hz - 20 kHz |
| Patterns | Omni, Wide Cardioid, Cardioid, Hypercardioid, Figure-8 |
| Key characteristics | Extended top end, detailed, slightly clinical |
| Presence | Broad rise 3-8 kHz (+2-3 dB) |
| Max SPL | 140 dB (with pad: 158 dB) |
| Used for | Overheads, room mic, acoustic instruments |

### Frequency Response EQ Curve
```
hpf: 20Hz, -12dB/oct
// Very flat 30Hz-3kHz
peak1: 4000Hz, +2dB, Q=0.6 (broad presence)
peak2: 8000Hz, +3dB, Q=0.8 (air/detail)
peak3: 14000Hz, +1dB, Q=1.0 (sparkle)
lpf: 20000Hz, -6dB/oct
// Pad options: -6dB, -12dB, -18dB
// HPF switch: 40Hz, 80Hz, 160Hz
```

---

## 4.7 Shure SM7B

| Parameter | Value |
|---|---|
| Type | Dynamic, cardioid |
| Frequency response | 50 Hz - 20 kHz |
| Key characteristics | Smooth, warm, controlled proximity, built-in bass rolloff |
| Presence | Broad peak 2-8 kHz (+3-5 dB), controllable via switch |
| Used for | Vocals, podcast, guitar cabs (thick tone) |

### Frequency Response EQ Curve
```
hpf: 50Hz, -18dB/oct
// Warm fundamental range 100-500Hz
peak1: 3000Hz, +3dB, Q=0.5 (broad presence boost)
peak2: 6000Hz, +5dB, Q=1.0 (presence peak, switchable)
lpf: 20000Hz, -12dB/oct

// Bass rolloff switch: HPF at 400Hz, -6dB/oct (for proximity compensation)
// Presence switch: boosts 2-8kHz shelf by +3dB additional
```

---

## Microphone Placement Parameters

### Distance from Cone
| Distance | Effect | Typical Use |
|---|---|---|
| 0 cm (touching grille) | Maximum bass (proximity), brightest, tightest | Extreme close-mic |
| 1-3 cm | Heavy proximity, focused, present | Standard close-mic |
| 5-10 cm | Balanced proximity, room starts to enter | Slightly backed off |
| 15-20 cm | Less proximity, more room, broader sound | Semi-distance |
| 30+ cm | Minimal proximity, room dominant | Room mic |

### Angle (0-45 degrees)
| Angle | Effect |
|---|---|
| 0 degrees (on-axis) | Brightest, most presence, most detailed |
| 15 degrees | Slightly reduced high-end, still bright |
| 30 degrees | Smoother, less harsh, mellower |
| 45 degrees (off-axis) | Darkest, smoothest, most rolled off |

### Position on Speaker Cone
| Position | Effect | Frequency Character |
|---|---|---|
| Center (dust cap) | Maximum brightness, harshest | +6dB at 4kHz vs edge |
| Between center and edge | Balanced, most common | Flat-ish |
| Edge of cone | Warmest, least bright | -6dB above 3kHz |

### Web Audio API Mic Simulation
```
// Distance -> proximity effect (bass boost/cut):
proximityGain_dB = 6 * (1 - distance/30)  // +6dB at 0cm, 0dB at 30cm
proximityFreq = 200  // Hz, shelving

// Angle -> high frequency rolloff:
angleRolloff_dB = -angle * 0.3  // 0dB at 0deg, -13.5dB at 45deg
angleRolloffFreq = 4000  // Hz and above affected

// Position -> brightness:
brightnessOffset_dB = (1 - position) * 6  // center=+6dB, edge=0dB
brightnessFreq = 3000  // Hz peak frequency

// Implementation:
BiquadFilterNode("lowshelf", 200Hz, proximityGain_dB)
BiquadFilterNode("highshelf", 4000Hz, angleRolloff_dB)
BiquadFilterNode("peaking", 3000Hz, brightnessOffset_dB, Q=1.5)
```

---

# 5. SIGNAL CHAIN

---

## Optimal Pedal Order

```
Guitar ->
  [1] Tuner (buffered, always first or in tuner out) ->
  [2] Wah / Envelope Filter (before dirt for classic wah-into-drive) ->
  [3] Compressor (before drive: tightens input, evens dynamics) ->
  [4] Octaver (needs clean signal for tracking accuracy) ->
  [5] Overdrive/Distortion/Fuzz (gain section) ->
      NOTE: Fuzz Face specifically needs to see guitar impedance directly
      if using traditional Fuzz Face, place BEFORE buffer/compressor
  [6] Noise Gate (after gain to catch noise from drive pedals) ->
  [7] EQ (post-drive: shape the distorted tone) ->

  === AMP INPUT ===
  Amp Preamp -> Amp Power Section

  === AMP EFFECTS LOOP (send/return) ===
  [8] Chorus / Phaser (modulation in loop: cleaner, not distorted) ->
  [9] Delay (in loop: repeats stay clean, not re-distorted) ->
  [10] Reverb (always last in chain before output) ->

  === AMP OUTPUT -> CABINET -> MICROPHONE ===

  [Post-amp processing]:
  [11] Cabinet simulation (if going direct / no physical cab) ->
  [12] Microphone simulation (if going direct) ->
  [13] Looper (very last: captures the entire processed signal)
```

## Gain Staging Between Components

### Input Stage
| Point | Level | Impedance | Notes |
|---|---|---|---|
| Guitar output (passive) | -20 to -10 dBu | 5-15k ohm | Depends on pickup type |
| Guitar output (active) | -10 to 0 dBu | 1k ohm | Hotter, lower impedance |
| Pedal input impedance | 500k-1M ohm | -- | High-Z to not load guitar |
| Buffer output | -10 dBu | 100-1k ohm | Low-Z, drives cable/pedals |

### Pedal-to-Pedal Gain Structure
| Transition | Nominal Level | Headroom | Notes |
|---|---|---|---|
| Guitar -> Tuner | -20 to -10 dBu | N/A | Tuner is passive tap |
| Tuner -> Wah | -20 to -10 dBu | 18 dB | Match input level |
| Wah -> Compressor | -10 to 0 dBu | 15 dB | Wah can boost +10dB |
| Compressor -> Drive | -10 to 0 dBu | 12 dB | Comp evens level |
| Drive -> Noise Gate | 0 to +10 dBu | 10 dB | Drive boosts signal |
| Noise Gate -> EQ | 0 to +10 dBu | 15 dB | Gate passes signal |
| EQ -> Amp input | -10 to +4 dBu | 18 dB | Amp expects instrument level |
| FX Loop Send | +4 dBu (line level) | 15 dB | Pro loop is line level |
| Chorus -> Delay | +4 dBu | 15 dB | Line level through loop |
| Delay -> Reverb | +4 dBu | 15 dB | Maintain line level |
| Reverb -> FX Return | +4 dBu | 15 dB | Back into power amp |

### Digital Implementation Gain Staging
```
// In Web Audio API, work in -1.0 to +1.0 float range
// Target operating level: -18 dBFS (leaves 18dB headroom)
// Peak should not exceed -3 dBFS

// Input gain calibration:
inputGain = 0.125  // ~-18 dBFS from typical guitar signal

// Between effects, maintain unity gain:
// Each effect should output approximately the same level as input
// Use makeup gain or level controls to compensate for gain changes

// Metering points (insert AnalyserNode):
// Post-input: target -18 dBFS average, -6 dBFS peak
// Post-drive: target -12 dBFS average (drive adds level)
// Post-amp: target -12 dBFS average
// Master output: target -6 dBFS peak maximum
```

### Impedance Matching in Web Audio
```
// Web Audio operates at "voltage" level (no real impedance)
// But we simulate impedance effects for realism:

// High-Z guitar into pedal (1M ohm): no change needed
// Guitar into low-Z input (Fuzz Face, 10k ohm):
//   - Bass loss: HPF at 100Hz, -3dB
//   - Level drop: -2dB
//   - Affects pickup resonance peak

// Pedal buffer to cable:
//   - Long cable after buffer: no loss (low output impedance)
//   - Long cable before buffer: treble loss
//     cable_lpf = 20000 / (1 + cableLength_feet / 20)  // approx
//     15ft cable: LPF at ~11.4kHz
//     30ft cable: LPF at ~8kHz
```

### Effects Loop Placement
```
// Pre-amp effects (before amp distortion):
// Tuner, Wah, Compressor, Octaver, Drive, Noise Gate, EQ
// These shape the signal BEFORE amp saturation

// Post-amp effects (in effects loop or after power amp):
// Chorus, Phaser, Flanger, Delay, Reverb
// These process the already-distorted signal cleanly

// For GrooveLab pedalboard (no physical amp loop):
// The "amp" block serves as the dividing point
// Pre-amp pedals -> Amp model -> Post-amp pedals -> Cabinet -> Mic
```

---

# 6. WEB AUDIO API NODE MAPPING SUMMARY

## Complete Signal Chain Node Graph

```
AudioContext.createMediaStreamSource(micInput)
  |
  v
GainNode (input trim, -18dBFS calibration)
  |
  v
[TUNER TAP: AnalyserNode, fftSize=4096, no output connection]
  |
  v
[WAH: BiquadFilterNode(bandpass, f=350-2200Hz, Q=5)]
  |        ^-- modulated by: OscillatorNode(LFO) or AudioWorklet(envelope)
  v
[COMPRESSOR: DynamicsCompressorNode or AudioWorkletNode]
  |
  v
[OCTAVER: AudioWorkletNode(pitch shift) parallel paths -> merger]
  |
  v
[DRIVE: GainNode(pre) -> WaveShaperNode(oversample:4x) -> BiquadFilterNode(tone)]
  |
  v
[NOISE GATE: AudioWorkletNode(gate logic) -> GainNode(envelope)]
  |
  v
[EQ: 5-10x BiquadFilterNode(peaking) in series]
  |
  v
[AMP: multiple GainNode->WaveShaperNode stages -> BiquadFilterNode tone stack]
  |
  v
[CHORUS: DelayNode <- OscillatorNode(LFO), parallel dry/wet mix]
  |
  v
[PHASER: 4-12x BiquadFilterNode(allpass) <- OscillatorNode(LFO), mixed with dry]
  |
  v
[DELAY: DelayNode(0.001-2.0s) -> GainNode(feedback loop) -> BiquadFilterNode(tone)]
  |
  v
[REVERB: ConvolverNode(IR) or AudioWorkletNode(FDN algorithm)]
  |
  v
[CABINET: ConvolverNode(IR) or multi-band BiquadFilterNode approximation]
  |
  v
[MIC SIM: BiquadFilterNode(lowshelf) + BiquadFilterNode(highshelf) + BiquadFilterNode(peaking)]
  |
  v
[LOOPER: AudioWorkletNode (record/playback/overdub)]
  |
  v
GainNode (master volume)
  |
  v
AudioContext.destination
```

## Critical Web Audio API Considerations

### Latency
- Minimum achievable: ~5ms with `latencyHint: 'interactive'`
- Typical: 10-25ms depending on buffer size
- Buffer sizes: 128 (best latency, ~2.9ms) to 4096 (worst, ~93ms) samples
- For real-time guitar processing: target 128 or 256 sample buffer

### WaveShaperNode Oversampling
- ALWAYS use `oversample: '4x'` for distortion/drive/fuzz
- Without oversampling: aliasing artifacts above Nyquist (harsh digital artifacts)
- '2x' is acceptable compromise for CPU savings
- '4x' provides professional quality

### AudioWorklet vs ScriptProcessor
- AudioWorklet: preferred, runs on dedicated audio thread, low latency
- ScriptProcessorNode: deprecated, runs on main thread, higher latency
- Use AudioWorklet for: noise gate, octaver, looper, custom reverb

### Sample Rate
- Default: 44100 Hz (CD quality, sufficient for guitar)
- 48000 Hz: better for video sync
- Internal processing: always Float32 (-1.0 to +1.0)
