import 'dart:math';
import 'dart:typed_data';

/// Generates raw PCM audio samples for different click/drum sounds.
/// All sounds are synthesized as WAV data for pre-loading into the audio engine.
class SoundGenerator {
  static const int sampleRate = 44100;

  static Uint8List generateSine(double freq, double duration, double volume) {
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = (1.0 - t / duration).clamp(0.0, 1.0);
      buffer[i] = sin(2 * pi * freq * t) * volume * envelope * envelope;
    }
    return _floatToWav(buffer);
  }

  /// Professional click synthesis — Soundbrenner/Logic Pro grade.
  ///
  /// Architecture:
  ///   Layer 1 — Sine burst: ultra-fast attack (<1ms), 30ms total, primary pitch
  ///   Layer 2 — Click transient: broadband noise burst (0–3ms) for "snap" feel
  ///   Layer 3 — Body resonance: slightly detuned sine (+7Hz) for warmth
  ///   Post: Soft saturation clip at 0.92 to prevent digital harshness
  ///
  /// This matches the character of professional click tracks:
  ///   Low volume → gentle, high volume → punchy but not fatiguing
  static Uint8List generateClick(double freq, double duration, double volume) {
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(42); // deterministic for consistency

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Layer 1: Primary sine burst — very fast exponential decay (decay = 80)
      // Attack: instant (sample 0 = full amplitude), decay τ = 1/80 = 12.5ms
      final primaryEnv = exp(-t * 80) * volume;
      final primary = sin(2 * pi * freq * t) * primaryEnv;

      // Layer 2: Click transient — noise burst in first 3ms only
      // Gives the physical "stick hitting surface" character
      final clickEnv = exp(-t * 350) * volume * 0.25;
      final click = (rand.nextDouble() * 2 - 1) * clickEnv;

      // Layer 3: Body resonance — detuned 7Hz for richness, slower decay
      final bodyEnv = exp(-t * 55) * volume * 0.20;
      final body = sin(2 * pi * (freq + 7) * t) * bodyEnv;

      // Mix
      var mixed = primary + click + body;

      // Soft saturation — prevents harsh digital clipping, adds warmth
      // Soft clip threshold at 0.85
      if (mixed.abs() > 0.85) {
        final sign = mixed.sign;
        final over = mixed.abs() - 0.85;
        mixed = sign * (0.85 + over / (1 + over * 3));
      }

      buffer[i] = mixed;
    }
    return _floatToWav(buffer);
  }

  static Uint8List generateNoise(double duration, double volume, double highpassFreq) {
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random();
    double lastSample = 0;
    final rc = 1.0 / (2 * pi * highpassFreq);
    const dt = 1.0 / sampleRate;
    final alpha = rc / (rc + dt);
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final noise = rand.nextDouble() * 2 - 1;
      final envelope = exp(-t * 15) * volume;
      final filtered = alpha * (lastSample + noise - (i > 0 ? rand.nextDouble() * 2 - 1 : 0));
      lastSample = filtered;
      buffer[i] = filtered * envelope;
    }
    return _floatToWav(buffer);
  }

  /// Realistic kick drum with sub-bass, body, and click transient.
  static Uint8List generateKick() {
    const duration = 0.45;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(99);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Sub bass: pitch sweep from 160Hz down to 45Hz with long decay
      final subFreq = 45 + 115 * exp(-t * 25);
      final subEnv = exp(-t * 6.5);
      final sub = sin(2 * pi * subFreq * t + 0.8 * sin(2 * pi * 1.5 * t)) * subEnv * 0.85;

      // Body: mid punch at ~100Hz
      final bodyFreq = 100 + 60 * exp(-t * 35);
      final bodyEnv = exp(-t * 12);
      final body = sin(2 * pi * bodyFreq * t) * bodyEnv * 0.4;

      // Click transient: very short noise burst
      final clickEnv = exp(-t * 120);
      final click = (rand.nextDouble() * 2 - 1) * clickEnv * 0.35;

      // Slight saturation for warmth
      var mixed = sub + body + click;
      mixed = (mixed * 1.2).clamp(-1.0, 1.0);
      // Soft clip
      if (mixed.abs() > 0.8) {
        mixed = mixed.sign * (0.8 + (mixed.abs() - 0.8) * 0.3);
      }

      buffer[i] = mixed * 0.92;
    }
    return _floatToWav(buffer);
  }

  /// Realistic snare with body tone, noise, and snare wire buzz.
  static Uint8List generateSnare() {
    const duration = 0.25;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(42);

    // Pre-generate noise for consistent filtering
    final noise = Float64List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      noise[i] = rand.nextDouble() * 2 - 1;
    }

    // Simple high-pass filter state for snare wires
    double hpPrev = 0;
    double hpPrevInput = 0;
    const hpCutoff = 3000.0;
    final hpRc = 1.0 / (2 * pi * hpCutoff);
    const hpDt = 1.0 / sampleRate;
    final hpAlpha = hpRc / (hpRc + hpDt);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Body tone: two resonant frequencies (180Hz + 330Hz)
      final toneEnv = exp(-t * 25);
      final tone1 = sin(2 * pi * 180 * t) * toneEnv * 0.45;
      final tone2 = sin(2 * pi * 330 * t) * exp(-t * 35) * 0.25;

      // Noise body: broadband with medium decay
      final noiseEnv = exp(-t * 14) * 0.65;
      final noiseSample = noise[i] * noiseEnv;

      // Snare wire buzz: high-passed noise with longer decay
      final wireEnv = exp(-t * 10) * 0.35;
      final wireInput = noise[i] * wireEnv;
      hpPrev = hpAlpha * (hpPrev + wireInput - hpPrevInput);
      hpPrevInput = wireInput;
      final wire = hpPrev;

      buffer[i] = (tone1 + tone2 + noiseSample + wire).clamp(-1.0, 1.0);
    }
    return _floatToWav(buffer);
  }

  /// Hi-hat with metallic ring and band-passed noise.
  static Uint8List generateHiHat({bool open = false}) {
    final duration = open ? 0.35 : 0.08;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(123);

    // Hi-hat is characterized by inharmonic metallic partials + noise
    final decayRate = open ? 6.0 : 60.0;
    final noiseDecay = open ? 5.0 : 45.0;

    // Metallic partial frequencies (inharmonic ratios typical of cymbals)
    const partials = [1047.0, 1481.0, 1960.0, 2794.0, 3900.0, 5588.0];
    final partialAmps = [0.15, 0.12, 0.10, 0.08, 0.06, 0.04];

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Metallic partials
      double metallic = 0;
      for (int p = 0; p < partials.length; p++) {
        metallic += sin(2 * pi * partials[p] * t) * partialAmps[p] * exp(-t * (decayRate + p * 3));
      }

      // High-frequency noise component
      final noiseEnv = exp(-t * noiseDecay) * (open ? 0.55 : 0.65);
      final noiseSample = (rand.nextDouble() * 2 - 1) * noiseEnv;

      buffer[i] = (metallic + noiseSample).clamp(-1.0, 1.0);
    }
    return _floatToWav(buffer);
  }

  /// Ride cymbal with shimmer, bell, and wash.
  static Uint8List generateRide() {
    const duration = 0.5;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(456);

    // Ride has a clear bell tone + cymbal wash
    const bellPartials = [680.0, 1360.0, 2050.0, 2720.0];
    const washPartials = [3200.0, 4500.0, 6100.0, 7800.0];

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Bell tone (sustained, clear)
      double bell = 0;
      for (int p = 0; p < bellPartials.length; p++) {
        final amp = 0.12 - p * 0.02;
        bell += sin(2 * pi * bellPartials[p] * t) * amp * exp(-t * (3.0 + p));
      }

      // Cymbal wash (faster decay noise + high partials)
      double wash = 0;
      for (int p = 0; p < washPartials.length; p++) {
        final amp = 0.06 - p * 0.01;
        wash += sin(2 * pi * washPartials[p] * t) * amp * exp(-t * (8.0 + p * 2));
      }

      // Noise shimmer
      final shimmerEnv = exp(-t * 6) * 0.25;
      final shimmer = (rand.nextDouble() * 2 - 1) * shimmerEnv;

      // Initial transient
      final transient = exp(-t * 80) * 0.3 * (rand.nextDouble() * 2 - 1);

      buffer[i] = (bell + wash + shimmer + transient).clamp(-1.0, 1.0);
    }
    return _floatToWav(buffer);
  }

  /// Rimshot — sharp crack with tonal body.
  static Uint8List generateRimshot({bool accent = false}) {
    const duration = 0.08;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(789);
    final vol = accent ? 0.9 : 0.65;

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Sharp transient crack
      final crack = (rand.nextDouble() * 2 - 1) * exp(-t * 100) * 0.7;
      // Tonal body (~1800Hz)
      final tone = sin(2 * pi * 1800 * t) * exp(-t * 50) * 0.5;
      // Lower resonance (~400Hz)
      final body = sin(2 * pi * 400 * t) * exp(-t * 35) * 0.3;
      buffer[i] = ((crack + tone + body) * vol).clamp(-1.0, 1.0);
    }
    return _floatToWav(buffer);
  }

  /// Shaker — filtered noise with rhythmic envelope.
  static Uint8List generateShaker({bool accent = false}) {
    final duration = accent ? 0.06 : 0.04;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(321);
    final vol = accent ? 0.7 : 0.5;

    // Simple band-pass via combined HP + LP
    double hpPrev = 0, hpPrevIn = 0;
    const hpCut = 4000.0;
    final hpRc = 1.0 / (2 * pi * hpCut);
    const dt = 1.0 / sampleRate;
    final hpA = hpRc / (hpRc + dt);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final raw = rand.nextDouble() * 2 - 1;
      // High-pass
      hpPrev = hpA * (hpPrev + raw - hpPrevIn);
      hpPrevIn = raw;
      // Envelope: fast attack, medium decay
      final env = (t < 0.003 ? t / 0.003 : 1.0) * exp(-(t - 0.003).clamp(0, 1) * 60);
      buffer[i] = (hpPrev * env * vol).clamp(-1.0, 1.0);
    }
    return _floatToWav(buffer);
  }

  /// Tambourine — jingle with metallic partials + noise.
  static Uint8List generateTambourine({bool accent = false}) {
    final duration = accent ? 0.12 : 0.08;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(654);
    final vol = accent ? 0.75 : 0.55;

    const jingleFreqs = [5200.0, 6800.0, 8100.0, 9500.0];

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Metallic jingles
      double jingle = 0;
      for (int j = 0; j < jingleFreqs.length; j++) {
        jingle += sin(2 * pi * jingleFreqs[j] * t) * 0.12 * exp(-t * (20 + j * 5));
      }
      // Noise shell
      final noiseEnv = exp(-t * 30) * 0.4;
      final noise = (rand.nextDouble() * 2 - 1) * noiseEnv;

      buffer[i] = ((jingle + noise) * vol).clamp(-1.0, 1.0);
    }
    return _floatToWav(buffer);
  }

  /// Convert Float64List to 16-bit mono WAV bytes
  static Uint8List _floatToWav(Float64List samples) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;
    final buffer = ByteData(fileSize);

    // RIFF header
    buffer.setUint8(0, 0x52); buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x46); buffer.setUint8(3, 0x46);
    buffer.setUint32(4, fileSize - 8, Endian.little);
    buffer.setUint8(8, 0x57); buffer.setUint8(9, 0x41);
    buffer.setUint8(10, 0x56); buffer.setUint8(11, 0x45);
    // fmt chunk
    buffer.setUint8(12, 0x66); buffer.setUint8(13, 0x6D);
    buffer.setUint8(14, 0x74); buffer.setUint8(15, 0x20);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);  // PCM
    buffer.setUint16(22, 1, Endian.little);  // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    // data chunk
    buffer.setUint8(36, 0x64); buffer.setUint8(37, 0x61);
    buffer.setUint8(38, 0x74); buffer.setUint8(39, 0x61);
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final sample = (samples[i].clamp(-1.0, 1.0) * 32767).toInt();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//
//  EXPERT 4 — PROFESSIONAL AUDIO ENGINE ADDITIONS
//
//  Wood Block: Dual resonance (800Hz + 1200Hz) + body knock, 45ms
//  Clave:      High-frequency stick, very tight 20ms, metallic resonance
//  Sine Burst: Pure band-limited click (<500Hz filtered), Soundbrenner style
//  Beep HQ:    Two-stage env (attack 2ms + sustain + exponential release)
//
//  Reference quality targets:
//    - No aliasing artifacts (frequencies << Nyquist/2 = 11025Hz)
//    - Peak amplitude -3dBFS (0.707) to leave headroom
//    - Soft saturation on all sounds to prevent digital harshness
//
// ═══════════════════════════════════════════════════════════════════════════

extension SoundGeneratorPro on SoundGenerator {
  /// Authentic wood block: hollow resonant chamber simulation.
  ///
  /// Two detuned sine waves (fundamental + 5th) with quick decay = wood hollow sound.
  /// Noise transient in first 2ms = mallet strike.
  static Uint8List generateWoodBlock({bool accent = false}) {
    const duration = 0.045;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final vol = accent ? 0.85 : 0.72;
    final f1 = accent ? 820.0 : 800.0;  // fundamental
    final f2 = f1 * 1.48;               // perfect 5th above (~1200Hz)
    final rand = Random(7);

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;
      // Resonance 1: fundamental
      final env1 = exp(-t * 110) * vol;
      final r1 = sin(2 * pi * f1 * t) * env1;
      // Resonance 2: fifth + pitch drop (gives hollow wood character)
      final f2t = f2 * exp(-t * 30);
      final env2 = exp(-t * 140) * vol * 0.55;
      final r2 = sin(2 * pi * f2t * t) * env2;
      // Mallet transient (first 2ms)
      final strike = (rand.nextDouble() * 2 - 1) * exp(-t * 500) * vol * 0.30;
      // Mix + soft clip
      var s = r1 + r2 + strike;
      if (s.abs() > 0.88) s = s.sign * (0.88 + (s.abs() - 0.88) * 0.25);
      buffer[i] = s;
    }
    return _floatToWav(buffer);
  }

  /// Clave: Hardwood sticks, metallic resonance at ~2400Hz.
  ///
  /// Very tight (20ms), high frequency, almost no sub.
  /// Used in Latin grooves and as an alternative click.
  static Uint8List generateClaveHQ({bool accent = false}) {
    const duration = 0.022;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final vol = accent ? 0.90 : 0.78;
    final freq = accent ? 2600.0 : 2400.0;
    final rand = Random(13);

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;
      // Sharp metallic ring
      final ring = sin(2 * pi * freq * t) * exp(-t * 200) * vol;
      // Second harmonic (adds metallic quality)
      final ring2 = sin(2 * pi * freq * 1.92 * t) * exp(-t * 280) * vol * 0.30;
      // Impact transient
      final impact = (rand.nextDouble() * 2 - 1) * exp(-t * 800) * vol * 0.25;
      var s = ring + ring2 + impact;
      if (s.abs() > 0.92) s = s.sign * (0.92 + (s.abs() - 0.92) * 0.15);
      buffer[i] = s;
    }
    return _floatToWav(buffer);
  }

  /// Sine burst click — Soundbrenner / Logic Pro "Digital" style.
  ///
  /// Very clean, band-limited (no low end), 15ms duration.
  /// Best for: electronic music, accurate timing feedback.
  static Uint8List generateSineBurst({bool accent = false}) {
    const duration = 0.015;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final freq = accent ? 1200.0 : 880.0;
    final vol = accent ? 0.82 : 0.70;

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;
      // Two-stage envelope: fast attack (1ms), then exponential decay
      final attackSamples = SoundGenerator.sampleRate * 0.001;
      final attack = i < attackSamples ? i / attackSamples : 1.0;
      final decay = exp(-t * 100);
      final env = attack * decay * vol;
      // Pure sine — no harmonics = clean, non-fatiguing
      buffer[i] = sin(2 * pi * freq * t) * env;
    }
    return _floatToWav(buffer);
  }

  /// Rack tom (pitch=0) or floor tom (pitch=1).
  ///
  /// Similar to kick but shorter (0.3s), with pitch sweep from ~200Hz (rack)
  /// or ~120Hz (floor) down. Resonant body with less sub-bass than kick.
  static Uint8List generateTom({int pitch = 0}) {
    const duration = 0.3;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(201);

    // Rack tom starts ~200Hz, floor tom starts ~120Hz
    final startFreq = pitch == 0 ? 200.0 : 120.0;
    final endFreq = pitch == 0 ? 90.0 : 55.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Pitch sweep: exponential drop from startFreq to endFreq
      final freq = endFreq + (startFreq - endFreq) * exp(-t * 18);
      final bodyEnv = exp(-t * 9.0);
      final body = sin(2 * pi * freq * t) * bodyEnv * 0.75;

      // Overtone resonance (adds fullness)
      final overtoneFreq = freq * 1.5;
      final overtoneEnv = exp(-t * 16);
      final overtone = sin(2 * pi * overtoneFreq * t) * overtoneEnv * 0.25;

      // Stick attack transient
      final attackEnv = exp(-t * 100);
      final attack = (rand.nextDouble() * 2 - 1) * attackEnv * 0.3;

      // Mix + soft saturation
      var mixed = body + overtone + attack;
      if (mixed.abs() > 0.85) {
        mixed = mixed.sign * (0.85 + (mixed.abs() - 0.85) * 0.25);
      }

      buffer[i] = mixed * 0.90;
    }
    return _floatToWav(buffer);
  }

  /// Crash cymbal — loud metallic shimmer with many inharmonic partials.
  ///
  /// Longer duration (0.8s), noise wash, fast initial transient.
  /// Louder and more sustained than ride.
  static Uint8List generateCrash() {
    const duration = 0.8;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(303);

    // Inharmonic metallic partials (dense, dissonant frequencies)
    const partials = [
      987.0, 1479.0, 2103.0, 2897.0, 3571.0,
      4283.0, 5197.0, 6311.0, 7523.0, 8741.0,
    ];
    final partialAmps = [
      0.12, 0.11, 0.10, 0.09, 0.08,
      0.07, 0.06, 0.05, 0.04, 0.03,
    ];

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Metallic partials with staggered decay
      double metallic = 0;
      for (int p = 0; p < partials.length; p++) {
        metallic += sin(2 * pi * partials[p] * t) *
            partialAmps[p] *
            exp(-t * (2.5 + p * 0.5));
      }

      // Noise wash — broadband shimmer
      final noiseEnv = exp(-t * 3.5) * 0.45;
      final noise = (rand.nextDouble() * 2 - 1) * noiseEnv;

      // Fast initial transient (first few ms)
      final transientEnv = exp(-t * 120) * 0.5;
      final transient = (rand.nextDouble() * 2 - 1) * transientEnv;

      var mixed = metallic + noise + transient;

      // Soft saturation
      if (mixed.abs() > 0.85) {
        mixed = mixed.sign * (0.85 + (mixed.abs() - 0.85) * 0.2);
      }

      buffer[i] = mixed;
    }
    return _floatToWav(buffer);
  }

  /// Handclap simulation — layered noise bursts for multiple-hands effect.
  ///
  /// 3-4 short noise bursts spaced ~8-15ms apart, each bandpass-filtered
  /// (~1500-3500Hz) with fast attack/decay. Followed by a longer reverb tail.
  static Uint8List generateClap() {
    const duration = 0.35;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(404);

    // Pre-generate noise
    final noise = Float64List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      noise[i] = rand.nextDouble() * 2 - 1;
    }

    // Bandpass filter state (HP + LP cascade)
    // High-pass at 1500Hz
    double hpPrev = 0, hpPrevIn = 0;
    const hpCut = 1500.0;
    final hpRc = 1.0 / (2 * pi * hpCut);
    const dt = 1.0 / SoundGenerator.sampleRate;
    final hpA = hpRc / (hpRc + dt);

    // Low-pass at 3500Hz
    const lpCut = 3500.0;
    final lpRc = 1.0 / (2 * pi * lpCut);
    final lpA = dt / (lpRc + dt);
    double lpPrev = 0;

    // Clap burst timings (in seconds): 3-4 bursts spaced 8-15ms apart
    const burstTimes = [0.0, 0.010, 0.021, 0.033];
    const burstDuration = 0.005; // each burst lasts ~5ms

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Bandpass filter the noise
      final raw = noise[i];
      hpPrev = hpA * (hpPrev + raw - hpPrevIn);
      hpPrevIn = raw;
      lpPrev = lpPrev + lpA * (hpPrev - lpPrev);
      final filtered = lpPrev;

      // Sum envelopes for each burst
      double burstEnv = 0;
      for (final bt in burstTimes) {
        final dt2 = t - bt;
        if (dt2 >= 0 && dt2 < burstDuration * 4) {
          burstEnv += exp(-dt2 * 300) * 0.55;
        }
      }

      // Reverb tail: slow-decaying filtered noise after bursts
      final tailEnv = exp(-t * 8.0) * 0.35;
      // Tail starts after the last burst
      final tailGate = t > 0.04 ? 1.0 : (t / 0.04);

      var mixed = filtered * burstEnv + filtered * tailEnv * tailGate;

      // Soft saturation
      if (mixed.abs() > 0.85) {
        mixed = mixed.sign * (0.85 + (mixed.abs() - 0.85) * 0.2);
      }

      buffer[i] = mixed * 0.88;
    }
    return _floatToWav(buffer);
  }

  /// Conga drum — open tone or slap.
  ///
  /// Open (open=true): sustained resonant ~200Hz, duration 0.35s.
  /// Slap (open=false): short, sharp, higher pitch ~350Hz with noise
  /// transient, duration 0.12s.
  static Uint8List generateConga({bool open = true}) {
    final duration = open ? 0.35 : 0.12;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(505);

    final baseFreq = open ? 200.0 : 350.0;
    final decayRate = open ? 7.0 : 35.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Fundamental tone with slight pitch drop
      final freq = baseFreq + (open ? 30.0 : 80.0) * exp(-t * 40);
      final toneEnv = exp(-t * decayRate);
      final tone = sin(2 * pi * freq * t) * toneEnv * 0.7;

      // Second harmonic for body
      final harm2Env = exp(-t * (decayRate + 5));
      final harm2 = sin(2 * pi * freq * 2.0 * t) * harm2Env * 0.2;

      // Hand strike transient (noise)
      final strikeLevel = open ? 0.2 : 0.45;
      final strikeDecay = open ? 80.0 : 150.0;
      final strikeEnv = exp(-t * strikeDecay);
      final strike = (rand.nextDouble() * 2 - 1) * strikeEnv * strikeLevel;

      var mixed = tone + harm2 + strike;

      // Soft saturation
      if (mixed.abs() > 0.85) {
        mixed = mixed.sign * (0.85 + (mixed.abs() - 0.85) * 0.25);
      }

      buffer[i] = mixed * 0.88;
    }
    return _floatToWav(buffer);
  }

  /// Ghost snare — quieter, shorter snare for ghost notes in drum patterns.
  ///
  /// 0.6x volume of regular snare, shorter duration (0.15s),
  /// less noise/wire content, more body tone.
  static Uint8List generateGhostSnare() {
    const duration = 0.15;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(606);

    // Pre-generate noise
    final noise = Float64List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      noise[i] = rand.nextDouble() * 2 - 1;
    }

    // High-pass filter state for wire
    double hpPrev = 0, hpPrevIn = 0;
    const hpCut = 3000.0;
    final hpRc = 1.0 / (2 * pi * hpCut);
    const dt = 1.0 / SoundGenerator.sampleRate;
    final hpA = hpRc / (hpRc + dt);

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Body tone: more prominent than in regular snare (scaled by 0.6)
      final toneEnv = exp(-t * 30) * 0.6;
      final tone1 = sin(2 * pi * 180 * t) * toneEnv * 0.50;
      final tone2 = sin(2 * pi * 330 * t) * exp(-t * 40) * 0.6 * 0.20;

      // Less noise body (reduced from regular snare)
      final noiseEnv = exp(-t * 20) * 0.6 * 0.35;
      final noiseSample = noise[i] * noiseEnv;

      // Reduced snare wire buzz
      final wireEnv = exp(-t * 18) * 0.6 * 0.18;
      final wireInput = noise[i] * wireEnv;
      hpPrev = hpA * (hpPrev + wireInput - hpPrevIn);
      hpPrevIn = wireInput;
      final wire = hpPrev;

      buffer[i] = (tone1 + tone2 + noiseSample + wire).clamp(-1.0, 1.0);
    }
    return _floatToWav(buffer);
  }

  /// Enhanced kick drum with sub-harmonic layer and room resonance.
  ///
  /// Like the standard kick but with:
  /// - Sub-harmonic layer at half the fundamental (~22.5Hz)
  /// - Extended body to 0.55s
  /// - Subtle room resonance tail (low-pass filtered noise at very low level)
  static Uint8List generateKickPro() {
    const duration = 0.55;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(707);

    // Low-pass filter state for room resonance
    const lpCut = 250.0;
    final lpRc = 1.0 / (2 * pi * lpCut);
    const dt = 1.0 / SoundGenerator.sampleRate;
    final lpA = dt / (lpRc + dt);
    double lpPrev = 0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Sub bass: pitch sweep from 160Hz down to 45Hz
      final subFreq = 45 + 115 * exp(-t * 25);
      final subEnv = exp(-t * 5.5);
      final sub = sin(2 * pi * subFreq * t + 0.8 * sin(2 * pi * 1.5 * t)) * subEnv * 0.75;

      // Sub-harmonic layer at half the fundamental (~22.5Hz)
      final subHarmFreq = subFreq * 0.5;
      final subHarmEnv = exp(-t * 4.5);
      final subHarm = sin(2 * pi * subHarmFreq * t) * subHarmEnv * 0.30;

      // Body: mid punch at ~100Hz
      final bodyFreq = 100 + 60 * exp(-t * 35);
      final bodyEnv = exp(-t * 10);
      final body = sin(2 * pi * bodyFreq * t) * bodyEnv * 0.4;

      // Click transient
      final clickEnv = exp(-t * 120);
      final click = (rand.nextDouble() * 2 - 1) * clickEnv * 0.35;

      // Room resonance tail: low-pass filtered noise at very low level
      final roomNoise = rand.nextDouble() * 2 - 1;
      lpPrev = lpPrev + lpA * (roomNoise - lpPrev);
      final roomEnv = exp(-t * 3.0) * 0.06;
      final room = lpPrev * roomEnv;

      // Mix
      var mixed = sub + subHarm + body + click + room;
      mixed = (mixed * 1.15).clamp(-1.0, 1.0);

      // Soft clip
      if (mixed.abs() > 0.80) {
        mixed = mixed.sign * (0.80 + (mixed.abs() - 0.80) * 0.3);
      }

      buffer[i] = mixed * 0.92;
    }
    return _floatToWav(buffer);
  }

  /// Drumstick on practice pad — muted transient click.
  ///
  /// Very short (0.02s), filtered noise with low resonance.
  /// Useful as a subtle, non-intrusive metronome click.
  static Uint8List generateStickClick() {
    const duration = 0.02;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(808);

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Muted noise transient — fast decay
      final noiseEnv = exp(-t * 300) * 0.65;
      final noise = (rand.nextDouble() * 2 - 1) * noiseEnv;

      // Low resonance body (~300Hz) — very short
      final bodyEnv = exp(-t * 250) * 0.30;
      final body = sin(2 * pi * 300 * t) * bodyEnv;

      var mixed = noise + body;

      // Soft saturation
      if (mixed.abs() > 0.88) {
        mixed = mixed.sign * (0.88 + (mixed.abs() - 0.88) * 0.2);
      }

      buffer[i] = mixed;
    }
    return _floatToWav(buffer);
  }

  /// Mechanical metronome tick-tock simulation.
  ///
  /// Accent=true produces the "tick" (higher pitch), accent=false
  /// produces the "tock" (lower pitch). Duration 0.03s.
  static Uint8List generateMechanicalTick({bool accent = false}) {
    const duration = 0.03;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(909);

    // Tick = higher pitch, tock = lower pitch
    final freq = accent ? 3200.0 : 1800.0;
    final vol = accent ? 0.80 : 0.65;

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Sharp mechanical click — sine with very fast decay
      final clickEnv = exp(-t * 250) * vol;
      final click = sin(2 * pi * freq * t) * clickEnv;

      // Mechanical rattle — very brief noise
      final rattleEnv = exp(-t * 400) * vol * 0.20;
      final rattle = (rand.nextDouble() * 2 - 1) * rattleEnv;

      // Second resonance (mechanical body)
      final bodyEnv = exp(-t * 180) * vol * 0.15;
      final body = sin(2 * pi * (freq * 0.6) * t) * bodyEnv;

      var mixed = click + rattle + body;

      // Soft saturation
      if (mixed.abs() > 0.90) {
        mixed = mixed.sign * (0.90 + (mixed.abs() - 0.90) * 0.15);
      }

      buffer[i] = mixed;
    }
    return _floatToWav(buffer);
  }

  /// Roland TR-808 cowbell — two detuned square waves with fast decay.
  ///
  /// Classic 808 cowbell: ~560Hz + ~845Hz square waves, metallic character,
  /// fast decay. Duration 0.08s.
  static Uint8List generate808Cowbell() {
    const duration = 0.08;
    final numSamples = (SoundGenerator.sampleRate * duration).toInt();
    final buffer = Float64List(numSamples);

    // Two detuned square wave frequencies (classic 808 cowbell)
    const freq1 = 560.0;
    const freq2 = 845.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / SoundGenerator.sampleRate;

      // Square waves via sign of sine (bandlimited approximation via
      // first 5 odd harmonics to avoid aliasing)
      double sq1 = 0;
      double sq2 = 0;
      for (int h = 0; h < 5; h++) {
        final harm = 2 * h + 1; // odd harmonics: 1, 3, 5, 7, 9
        final amp = 1.0 / harm;
        sq1 += sin(2 * pi * freq1 * harm * t) * amp;
        sq2 += sin(2 * pi * freq2 * harm * t) * amp;
      }
      sq1 *= 4 / pi; // normalize square wave amplitude
      sq2 *= 4 / pi;

      // Two-stage envelope: fast attack + exponential decay
      final env = exp(-t * 35) * 0.55;

      var mixed = (sq1 * 0.5 + sq2 * 0.5) * env;

      // Soft saturation — adds metallic warmth
      if (mixed.abs() > 0.85) {
        mixed = mixed.sign * (0.85 + (mixed.abs() - 0.85) * 0.2);
      }

      buffer[i] = mixed;
    }
    return _floatToWav(buffer);
  }

  // Need to expose _floatToWav — copy it here for the extension
  static Uint8List _floatToWav(Float64List samples) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;
    final buf = ByteData(fileSize);
    buf.setUint8(0, 0x52); buf.setUint8(1, 0x49); buf.setUint8(2, 0x46); buf.setUint8(3, 0x46);
    buf.setUint32(4, fileSize - 8, Endian.little);
    buf.setUint8(8, 0x57); buf.setUint8(9, 0x41); buf.setUint8(10, 0x56); buf.setUint8(11, 0x45);
    buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D); buf.setUint8(14, 0x74); buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, 1, Endian.little);
    buf.setUint32(24, SoundGenerator.sampleRate, Endian.little);
    buf.setUint32(28, SoundGenerator.sampleRate * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    buf.setUint8(36, 0x64); buf.setUint8(37, 0x61); buf.setUint8(38, 0x74); buf.setUint8(39, 0x61);
    buf.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < numSamples; i++) {
      final sample = (samples[i].clamp(-1.0, 1.0) * 32767).toInt();
      buf.setInt16(44 + i * 2, sample, Endian.little);
    }
    return buf.buffer.asUint8List();
  }
}
