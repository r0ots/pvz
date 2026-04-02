'use strict';

// ─── ParameterMapper ──────────────────────────────────────────────────────
// Converts MoveNet pose keypoints into voice synth parameters.
//
// Pitch control  – how crouched a person is:
//   Body height (nose.y → ankle.y in pixels) is compared against a rolling
//   maximum (the tallest the person has stood so far).  Standing = max pitch,
//   fully crouched = min pitch.
//
// Vowel control  – average arm elevation above horizontal:
//   Arms lowered  → vowel 0 ("oo")
//   Arms at sides → vowel ~0.35 ("oh/ah")
//   Arms raised   → vowel 1 ("ee")
//
// Person → singer assignment:
//   Up to 4 people detected. Sorted by shoulder-midpoint X (left to right in
//   the MIRRORED video) → assigned to slots 0-3 = bass, tenor, mezzo, soprano.

const VOICE_ORDER = ['bass', 'tenor', 'mezzo', 'soprano'];

// Smoothing time constant (samples at 60 fps).
// A value of 0.85 means the output moves 15 % toward the target each frame.
const SMOOTH_ALPHA = 0.82;

// Rolling-max decay per frame (very slow – allows someone to walk closer)
const MAX_HEIGHT_DECAY = 0.9998;

// Minimum reliable body height in pixels (ignores tiny/distant detections)
const MIN_BODY_HEIGHT_PX = 60;

// Arm elevation range for vowel mapping (relative to body height).
// -0.15 = wrists ~15 % of body height BELOW shoulder → "oo"
//  0.35 = wrists ~35 % of body height ABOVE shoulder → "ee"
const ARM_LOW  = -0.15;
const ARM_HIGH =  0.35;

// clamp() is defined in voice-synth.js (loaded first)

class ParameterMapper {
  constructor() {
    // Per-slot state
    this._slots = VOICE_ORDER.map(() => ({
      maxBodyHeight: 0,
      smoothPitch: 0.5,   // 0-1, 1 = standing = high note
      smoothVowel: 0.35,  // 0-1
      active: false,
      // For display: raw midi note and vowel position
      midiNote: 60,
      vowelPos: 0.35,
    }));
  }

  // ── Main update ──────────────────────────────────────────────────────────
  // `poses`      – array from PoseDetector.estimatePoses (already filtered)
  // `videoWidth` – pixel width of the video frame
  // Returns array of { voiceType, midiNote, vowelPos, active } for all 4 slots.

  update(poses, videoWidth) {
    // Sort poses left→right in MIRRORED space (i.e. right→left in raw coords)
    // Raw video: x=0 is the camera's left. In the mirrored view shown to user,
    // x=0 (camera-left) appears on the right. So to sort by mirrored left→right
    // we sort by DESCENDING raw x.
    const sorted = [...poses].sort((a, b) =>
      getPoseCentreX(b) - getPoseCentreX(a)   // descending raw x → bass on left
    );

    const results = VOICE_ORDER.map((voiceType, slotIdx) => {
      const slot = this._slots[slotIdx];
      const pose = sorted[slotIdx] ?? null;

      if (!pose) {
        slot.active = false;
        return { voiceType, midiNote: slot.midiNote, vowelPos: slot.vowelPos, active: false };
      }

      // ── Body height (crouching) ──────────────────────────────────────────
      const bodyH = this._bodyHeight(pose);
      if (bodyH < MIN_BODY_HEIGHT_PX) {
        // Detection too unreliable (person very far or partial)
        slot.active = false;
        return { voiceType, midiNote: slot.midiNote, vowelPos: slot.vowelPos, active: false };
      }

      // Rolling max (auto-calibration)
      slot.maxBodyHeight = Math.max(slot.maxBodyHeight * MAX_HEIGHT_DECAY, bodyH);

      // Crouch ratio: 1.0 = standing tall, lower = crouching
      const crouchRatio = clamp(bodyH / slot.maxBodyHeight, 0, 1);

      // ── Arm elevation (vowel) ────────────────────────────────────────────
      const armElev = this._armElevation(pose, bodyH);
      const vowelRaw = clamp((armElev - ARM_LOW) / (ARM_HIGH - ARM_LOW), 0, 1);

      // ── Smooth both values ───────────────────────────────────────────────
      slot.smoothPitch = slot.smoothPitch * SMOOTH_ALPHA + crouchRatio * (1 - SMOOTH_ALPHA);
      slot.smoothVowel = slot.smoothVowel * SMOOTH_ALPHA + vowelRaw  * (1 - SMOOTH_ALPHA);

      // ── Map crouchRatio → MIDI pitch ─────────────────────────────────────
      const cfg = VOICE_CONFIG[voiceType];
      const midiNote = cfg.pitchRange.min +
        slot.smoothPitch * (cfg.pitchRange.max - cfg.pitchRange.min);

      slot.midiNote   = midiNote;
      slot.vowelPos   = slot.smoothVowel;
      slot.active     = true;

      return { voiceType, midiNote, vowelPos: slot.smoothVowel, active: true };
    });

    return results;
  }

  // ── Body height in pixels ─────────────────────────────────────────────────
  // Uses nose for the top point and the mean of visible ankles for the bottom.
  // Falls back to hip if ankles aren't visible.
  _bodyHeight(pose) {
    const nose   = getKP(pose, KP.NOSE);
    const la     = getKP(pose, KP.LEFT_ANKLE);
    const ra     = getKP(pose, KP.RIGHT_ANKLE);
    const lh     = getKP(pose, KP.LEFT_HIP);
    const rh     = getKP(pose, KP.RIGHT_HIP);

    if (!nose) return 0;

    // Best foot reference
    let footY;
    if (la && ra) footY = (la.y + ra.y) / 2;
    else if (la)  footY = la.y;
    else if (ra)  footY = ra.y;
    else if (lh && rh) {
      // Estimate ankle from hip: assume hips are ~55 % of full height
      footY = ((lh.y + rh.y) / 2 - nose.y) / 0.55 + nose.y;
    } else return 0;

    return Math.max(0, footY - nose.y);
  }

  // ── Average arm elevation relative to body height ─────────────────────────
  // Returns a value where 0 = horizontal, positive = arms up, negative = arms down.
  // Normalised by body height so it's scale-invariant.
  _armElevation(pose, bodyHeight) {
    const ls = getKP(pose, KP.LEFT_SHOULDER);
    const rs = getKP(pose, KP.RIGHT_SHOULDER);
    const lw = getKP(pose, KP.LEFT_WRIST);
    const rw = getKP(pose, KP.RIGHT_WRIST);
    const le = getKP(pose, KP.LEFT_ELBOW);
    const re = getKP(pose, KP.RIGHT_ELBOW);

    if (!bodyHeight) return 0;

    const elevs = [];

    // Left arm elevation: positive when wrist is above shoulder
    if (ls && lw) {
      elevs.push((ls.y - lw.y) / bodyHeight);  // positive = wrist above shoulder
    } else if (ls && le) {
      elevs.push((ls.y - le.y) / bodyHeight * 0.6); // partial arm
    }

    // Right arm elevation
    if (rs && rw) {
      elevs.push((rs.y - rw.y) / bodyHeight);
    } else if (rs && re) {
      elevs.push((rs.y - re.y) / bodyHeight * 0.6);
    }

    if (elevs.length === 0) return 0;
    return elevs.reduce((a, b) => a + b, 0) / elevs.length;
  }

  getSlotState(slotIdx) {
    return this._slots[slotIdx];
  }
}
