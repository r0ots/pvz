'use strict';

// ─── Voice configuration ───────────────────────────────────────────────────
// Each voice has a MIDI pitch range, formant scaling, and vibrato parameters.

const VOICE_CONFIG = {
  bass: {
    pitchRange: { min: 40, max: 64 },   // E2–E4
    formantScale: 0.84,
    singerFormant: 2400,
    singerFormantQ: 8,
    vibratoRate: 5.2,
    vibratoMaxCents: 55,
    outputGain: 0.28,
  },
  tenor: {
    pitchRange: { min: 48, max: 72 },   // C3–C5
    formantScale: 0.91,
    singerFormant: 2800,
    singerFormantQ: 9,
    vibratoRate: 5.5,
    vibratoMaxCents: 58,
    outputGain: 0.25,
  },
  mezzo: {
    pitchRange: { min: 57, max: 79 },   // A3–G5
    formantScale: 0.96,
    singerFormant: 2900,
    singerFormantQ: 10,
    vibratoRate: 5.8,
    vibratoMaxCents: 60,
    outputGain: 0.22,
  },
  soprano: {
    pitchRange: { min: 60, max: 84 },   // C4–C6
    formantScale: 1.0,
    singerFormant: 3050,
    singerFormantQ: 10,
    vibratoRate: 6.1,
    vibratoMaxCents: 65,
    outputGain: 0.20,
  },
};

// ─── Formant tables ────────────────────────────────────────────────────────
// Five vowels (oo → oh → ah → eh → ee) for the soprano register.
// Other voice types scale these by their formantScale factor.
//
// Each entry: [F1_hz, F2_hz, F3_hz]
// Bandwidths (Hz): F1≈120, F2≈160, F3≈250  (operatic singing, narrower than speech)

const SOPRANO_FORMANTS = [
  [325,  700, 2700],   // /u/ "oo"
  [550,  900, 2700],   // /o/ "oh"
  [900, 1200, 2800],   // /a/ "ah"  ← centre of range
  [620, 1900, 2800],   // /e/ "eh"
  [320, 2700, 3000],   // /i/ "ee"
];

const FORMANT_BW = [120, 160, 250];   // bandwidth per formant (Hz)

// Relative gains for each formant filter (dB peaking boost)
const FORMANT_GAIN_DB = [14, 12, 9];

// ─── Vowel labels for display ──────────────────────────────────────────────
const VOWEL_LABELS = ['oo', 'oh', 'ah', 'eh', 'ee'];

// ─── Helpers ───────────────────────────────────────────────────────────────
function midiToHz(midi) {
  return 440 * Math.pow(2, (midi - 69) / 12);
}

function midiToNoteName(midi) {
  const names = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
  return names[midi % 12] + Math.floor(midi / 12 - 1);
}

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}

// ─── Reverb impulse response (shared, created once) ───────────────────────
function buildReverbIR(ctx, durationSec = 2.2, decay = 3.5) {
  const sr = ctx.sampleRate;
  const len = Math.floor(sr * durationSec);
  const ir = ctx.createBuffer(2, len, sr);
  for (let ch = 0; ch < 2; ch++) {
    const d = ir.getChannelData(ch);
    for (let i = 0; i < len; i++) {
      const t = i / len;
      // Exponential decay envelope, slightly different per channel for stereo width
      const env = Math.pow(1 - t, decay) * (ch === 0 ? 1 : 0.95);
      d[i] = (Math.random() * 2 - 1) * env;
    }
  }
  return ir;
}

// ─── AudioEngine (singleton, manages shared nodes) ────────────────────────
class AudioEngine {
  constructor() {
    this.ctx = null;
    this.masterGain = null;
    this.compressor = null;
    this.convolver = null;
    this.dryGain = null;
    this.wetGain = null;
  }

  init() {
    if (this.ctx) return;

    this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    const ctx = this.ctx;

    // Compressor at the output – prevents clipping when all 4 singers are loud
    this.compressor = ctx.createDynamicsCompressor();
    this.compressor.threshold.value = -18;
    this.compressor.knee.value = 10;
    this.compressor.ratio.value = 4;
    this.compressor.attack.value = 0.003;
    this.compressor.release.value = 0.25;
    this.compressor.connect(ctx.destination);

    // Master gain
    this.masterGain = ctx.createGain();
    this.masterGain.gain.value = 0.85;
    this.masterGain.connect(this.compressor);

    // Reverb (convolution)
    this.convolver = ctx.createConvolver();
    this.convolver.buffer = buildReverbIR(ctx);

    // Dry/wet mix
    this.dryGain = ctx.createGain();
    this.dryGain.gain.value = 0.62;
    this.dryGain.connect(this.masterGain);

    this.wetGain = ctx.createGain();
    this.wetGain.gain.value = 0.38;
    this.convolver.connect(this.wetGain);
    this.wetGain.connect(this.masterGain);

    // Voices feed into both dry and wet paths via a pre-reverb summing node
    this.voiceBus = ctx.createGain();
    this.voiceBus.gain.value = 1.0;
    this.voiceBus.connect(this.dryGain);
    this.voiceBus.connect(this.convolver);
  }

  resume() {
    if (this.ctx && this.ctx.state === 'suspended') {
      return this.ctx.resume();
    }
    return Promise.resolve();
  }
}

const audioEngine = new AudioEngine();

// ─── VoiceSynth ───────────────────────────────────────────────────────────
// One instance per singer (bass / tenor / mezzo / soprano).
// Signal chain:
//   OscNode(saw) ← vibratoLFO
//   → sourceGain
//   → preLP (reduces aliasing harshness)
//   → peaking F1 → peaking F2 → peaking F3 → peaking SingerFormant
//   → ampEnv (on/off gate)
//   → outputGain
//   → voiceBus (shared)
//
//   noiseSource → noiseGain → noiseHP → F1 (also shapes the breathiness)

class VoiceSynth {
  constructor(voiceType) {
    this.voiceType = voiceType;
    this.cfg = VOICE_CONFIG[voiceType];
    this.isActive = false;
    this._currentPitchHz = midiToHz(
      Math.round((this.cfg.pitchRange.min + this.cfg.pitchRange.max) / 2)
    );
    this._currentMidi = Math.round(
      (this.cfg.pitchRange.min + this.cfg.pitchRange.max) / 2
    );
    this._currentVowel = 0.5;   // 0=oo … 1=ee

    this._built = false;
  }

  // Must call after audioEngine.init()
  build() {
    if (this._built) return;
    this._built = true;

    const ctx = audioEngine.ctx;
    const cfg = this.cfg;

    // ── Oscillator + vibrato ──────────────────────────────────────────────
    this.osc = ctx.createOscillator();
    this.osc.type = 'sawtooth';
    this.osc.frequency.value = this._currentPitchHz;

    this.vibratoLFO = ctx.createOscillator();
    this.vibratoLFO.type = 'sine';
    this.vibratoLFO.frequency.value = cfg.vibratoRate;

    // Slight LFO rate wander (random within ±0.3 Hz) for naturalness
    this.vibratoLFO.frequency.value = cfg.vibratoRate + (Math.random() - 0.5) * 0.3;

    this.vibratoDepth = ctx.createGain();
    this.vibratoDepth.gain.value = 0;   // ramps up on gate on
    this.vibratoLFO.connect(this.vibratoDepth);
    this.vibratoDepth.connect(this.osc.frequency);

    // Tremolo LFO (amplitude shimmer correlated with vibrato, very subtle)
    this.tremoloLFO = ctx.createOscillator();
    this.tremoloLFO.type = 'sine';
    this.tremoloLFO.frequency.value = cfg.vibratoRate * 1.01; // slight detune from vibrato
    this.tremoloDepth = ctx.createGain();
    this.tremoloDepth.gain.value = 0;   // ramps up separately

    // ── Source gain ───────────────────────────────────────────────────────
    this.sourceGain = ctx.createGain();
    this.sourceGain.gain.value = 0.55;
    this.osc.connect(this.sourceGain);

    // ── Pre-lowpass (tame sawtooth harshness before formant EQ) ──────────
    this.preLP = ctx.createBiquadFilter();
    this.preLP.type = 'lowpass';
    this.preLP.frequency.value = 6500;
    this.preLP.Q.value = 0.5;
    this.sourceGain.connect(this.preLP);

    // ── Formant filters (peaking EQ, series) ─────────────────────────────
    this.filt = [0, 1, 2].map((i) => {
      const f = ctx.createBiquadFilter();
      f.type = 'peaking';
      f.gain.value = FORMANT_GAIN_DB[i];
      return f;
    });

    // Singer's formant (the 'ring' of operatic voices, ~2400-3100 Hz)
    this.sfFilt = ctx.createBiquadFilter();
    this.sfFilt.type = 'peaking';
    this.sfFilt.frequency.value = cfg.singerFormant;
    this.sfFilt.Q.value = cfg.singerFormantQ;
    this.sfFilt.gain.value = 9;

    // Chain: preLP → F1 → F2 → F3 → singerFormant
    this.preLP.connect(this.filt[0]);
    this.filt[0].connect(this.filt[1]);
    this.filt[1].connect(this.filt[2]);
    this.filt[2].connect(this.sfFilt);

    // ── Breathiness noise ─────────────────────────────────────────────────
    this.noiseSource = this._makeNoise(ctx);
    this.noiseGain = ctx.createGain();
    this.noiseGain.gain.value = 0.035;
    this.noiseHP = ctx.createBiquadFilter();
    this.noiseHP.type = 'highpass';
    this.noiseHP.frequency.value = 900;
    this.noiseSource.connect(this.noiseGain);
    this.noiseGain.connect(this.noiseHP);
    this.noiseHP.connect(this.filt[0]); // noise shaped by the same formants

    // ── Amplitude envelope (gate control) ─────────────────────────────────
    this.ampEnv = ctx.createGain();
    this.ampEnv.gain.value = 0;
    this.sfFilt.connect(this.ampEnv);

    // Tremolo modulates ampEnv
    this.tremoloLFO.connect(this.tremoloDepth);
    this.tremoloDepth.connect(this.ampEnv.gain);

    // ── Output gain (per-voice level) ────────────────────────────────────
    this.outputGain = ctx.createGain();
    this.outputGain.gain.value = cfg.outputGain;
    this.ampEnv.connect(this.outputGain);
    this.outputGain.connect(audioEngine.voiceBus);

    // ── Start oscillators ─────────────────────────────────────────────────
    this.osc.start();
    this.vibratoLFO.start();
    this.tremoloLFO.start();
    this.noiseSource.start();

    // Apply initial formants
    this._applyFormants(this._currentVowel, true);
  }

  _makeNoise(ctx) {
    const len = ctx.sampleRate * 3;
    const buf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = buf.getChannelData(0);
    // Pink-ish noise via simple IIR
    let b0=0,b1=0,b2=0,b3=0,b4=0,b5=0;
    for (let i = 0; i < len; i++) {
      const w = Math.random() * 2 - 1;
      b0=0.99886*b0+w*0.0555179; b1=0.99332*b1+w*0.0750759;
      b2=0.96900*b2+w*0.1538520; b3=0.86650*b3+w*0.3104856;
      b4=0.55000*b4+w*0.5329522; b5=-0.7616*b5-w*0.0168980;
      d[i] = (b0+b1+b2+b3+b4+b5+w*0.5362) * 0.11;
    }
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.loop = true;
    return src;
  }

  // Interpolate formant targets for a given vowel position (0-1).
  _getFormantHz(vowelPos) {
    const scale = this.cfg.formantScale;
    const n = SOPRANO_FORMANTS.length - 1;
    const idx = clamp(vowelPos * n, 0, n);
    const lo = Math.floor(idx);
    const hi = Math.min(lo + 1, n);
    const t = idx - lo;
    return SOPRANO_FORMANTS[lo].map((v, i) =>
      (v * (1 - t) + SOPRANO_FORMANTS[hi][i] * t) * scale
    );
  }

  _applyFormants(vowelPos, immediate = false) {
    const freqs = this._getFormantHz(vowelPos);
    const now = audioEngine.ctx.currentTime;
    const tau = immediate ? 0 : 0.08;

    freqs.forEach((freq, i) => {
      const q = freq / FORMANT_BW[i];
      if (immediate) {
        this.filt[i].frequency.value = freq;
        this.filt[i].Q.value = q;
      } else {
        this.filt[i].frequency.setTargetAtTime(freq, now, tau);
        this.filt[i].Q.setTargetAtTime(q, now, tau);
      }
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  setPitch(midiNote) {
    if (!this._built) return;
    this._currentMidi = midiNote;
    const hz = midiToHz(midiNote);
    this._currentPitchHz = hz;
    const now = audioEngine.ctx.currentTime;
    this.osc.frequency.setTargetAtTime(hz, now, 0.07);

    // Keep vibrato depth proportional to fundamental frequency (~60 cents)
    if (this.isActive) {
      const depthHz = hz * (Math.pow(2, this.cfg.vibratoMaxCents / 1200) - 1);
      this.vibratoDepth.gain.setTargetAtTime(depthHz, now, 0.1);
    }
  }

  setVowel(position) {
    if (!this._built) return;
    this._currentVowel = clamp(position, 0, 1);
    this._applyFormants(this._currentVowel);
  }

  setActive(active) {
    if (!this._built) return;
    const now = audioEngine.ctx.currentTime;
    const cfg = this.cfg;

    if (active && !this.isActive) {
      // Fade voice in
      this.ampEnv.gain.cancelScheduledValues(now);
      this.ampEnv.gain.setTargetAtTime(1.0, now, 0.12);

      // Ramp vibrato up over ~0.6 s (singers don't start with full vibrato)
      const targetDepth = this._currentPitchHz *
        (Math.pow(2, cfg.vibratoMaxCents / 1200) - 1);
      this.vibratoDepth.gain.cancelScheduledValues(now);
      this.vibratoDepth.gain.setValueAtTime(
        this.vibratoDepth.gain.value, now
      );
      this.vibratoDepth.gain.linearRampToValueAtTime(targetDepth, now + 0.65);

      // Subtle tremolo (amplitude shimmer)
      this.tremoloDepth.gain.setTargetAtTime(0.025, now, 0.5);

      this.isActive = true;

    } else if (!active && this.isActive) {
      // Fade out
      this.ampEnv.gain.cancelScheduledValues(now);
      this.ampEnv.gain.setTargetAtTime(0, now, 0.18);

      // Wind down vibrato
      this.vibratoDepth.gain.cancelScheduledValues(now);
      this.vibratoDepth.gain.setTargetAtTime(0, now, 0.2);
      this.tremoloDepth.gain.setTargetAtTime(0, now, 0.15);

      this.isActive = false;
    }
  }

  // Returns human-readable state for the HUD
  getDisplayInfo() {
    return {
      voiceType: this.voiceType,
      noteName: midiToNoteName(Math.round(this._currentMidi)),
      vowelLabel: this._getVowelLabel(),
      isActive: this.isActive,
    };
  }

  _getVowelLabel() {
    const idx = Math.round(this._currentVowel * (VOWEL_LABELS.length - 1));
    return VOWEL_LABELS[clamp(idx, 0, VOWEL_LABELS.length - 1)];
  }
}
