'use strict';

// ─── Renderer ─────────────────────────────────────────────────────────────
// Draws the skeleton overlay on a <canvas> element.
//
// Coordinate system:
//   The video element is CSS-mirrored (transform: scaleX(-1)).
//   We draw on the canvas WITHOUT any CSS transform. To match the mirrored
//   video we flip each x coordinate:  drawX = canvasWidth - (rawX * scaleX + offsetX)

// Colours per slot (bass → tenor → mezzo → soprano)
const SINGER_COLORS = [
  '#5B8CFF',   // bass    – blue
  '#4ECDC4',   // tenor   – teal
  '#FFD166',   // mezzo   – amber
  '#FF6B9D',   // soprano – pink
];

const SINGER_LABELS_TEXT = ['Bass', 'Tenor', 'Mezzo', 'Soprano'];

class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this._voiceParams = [];   // latest mapped params for label display
  }

  // Resize canvas to match its display size (call on window resize and init)
  resize() {
    this.canvas.width  = this.canvas.clientWidth  * (window.devicePixelRatio || 1);
    this.canvas.height = this.canvas.clientHeight * (window.devicePixelRatio || 1);
  }

  // `poses`       – raw pose array from PoseDetector
  // `voiceParams` – output of ParameterMapper.update()
  // `videoWidth`  – video element's natural (camera) width
  // `videoHeight` – video element's natural (camera) height
  draw(poses, voiceParams, videoWidth, videoHeight) {
    const { ctx, canvas } = this;
    this._voiceParams = voiceParams;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (!poses || poses.length === 0) return;

    // Build coordinate transform from video space → canvas space, with mirror
    const transform = this._buildTransform(videoWidth, videoHeight);

    // Sort poses same way as ParameterMapper (descending raw x = mirrored left→right)
    const sorted = [...poses].sort((a, b) =>
      getPoseCentreX(b) - getPoseCentreX(a)
    );

    sorted.forEach((pose, slotIdx) => {
      if (slotIdx >= 4) return;
      const color  = SINGER_COLORS[slotIdx];
      const params = voiceParams[slotIdx];
      if (!params) return;

      this._drawSkeleton(pose, color, transform);
      this._drawJoints(pose, color, transform);
      if (params.active) {
        this._drawLabel(pose, slotIdx, params, color, transform);
        this._drawPitchBar(pose, slotIdx, params, color, transform);
        this._drawVowelIndicator(pose, slotIdx, params, color, transform);
      }
    });
  }

  // ── Coordinate helpers ────────────────────────────────────────────────────

  _buildTransform(videoW, videoH) {
    const cw = this.canvas.width;
    const ch = this.canvas.height;

    // object-fit: cover scale
    const scaleX = cw / videoW;
    const scaleY = ch / videoH;
    const scale  = Math.max(scaleX, scaleY);

    const offsetX = (cw - videoW * scale) / 2;
    const offsetY = (ch - videoH * scale) / 2;

    return { scale, offsetX, offsetY, cw, ch };
  }

  _toCanvas(rawX, rawY, t) {
    // Map raw video coords → canvas coords, flipping X for mirror
    const canvasX = t.cw - (rawX * t.scale + t.offsetX);
    const canvasY = rawY * t.scale + t.offsetY;
    return { x: canvasX, y: canvasY };
  }

  // ── Drawing helpers ───────────────────────────────────────────────────────

  _drawSkeleton(pose, color, transform) {
    const ctx = this.ctx;
    ctx.save();
    ctx.strokeStyle = color;
    ctx.lineWidth   = Math.max(2, this.canvas.width / 400);
    ctx.globalAlpha = 0.75;
    ctx.lineCap     = 'round';

    for (const [a, b] of SKELETON_PAIRS) {
      const kpA = getKP(pose, a);
      const kpB = getKP(pose, b);
      if (!kpA || !kpB) continue;

      const pa = this._toCanvas(kpA.x, kpA.y, transform);
      const pb = this._toCanvas(kpB.x, kpB.y, transform);
      ctx.beginPath();
      ctx.moveTo(pa.x, pa.y);
      ctx.lineTo(pb.x, pb.y);
      ctx.stroke();
    }
    ctx.restore();
  }

  _drawJoints(pose, color, transform) {
    const ctx    = this.ctx;
    const radius = Math.max(4, this.canvas.width / 200);

    ctx.save();
    pose.keypoints.forEach((kp) => {
      if (kp.score < KEYPOINT_THRESHOLD) return;
      const p = this._toCanvas(kp.x, kp.y, transform);
      ctx.beginPath();
      ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
      ctx.fillStyle   = color;
      ctx.globalAlpha = 0.9;
      ctx.fill();
      ctx.strokeStyle = 'rgba(0,0,0,0.4)';
      ctx.lineWidth   = 1;
      ctx.stroke();
    });
    ctx.restore();
  }

  _drawLabel(pose, slotIdx, params, color, transform) {
    const nose = getKP(pose, KP.NOSE);
    if (!nose) return;

    const p   = this._toCanvas(nose.x, nose.y, transform);
    const ctx = this.ctx;
    const dpr = window.devicePixelRatio || 1;

    const baseFontSize = Math.max(11, this.canvas.width / 80) / dpr;
    const padding      = baseFontSize * 0.6;
    const lineH        = baseFontSize * 1.5;

    const lines = [
      SINGER_LABELS_TEXT[slotIdx],
      params.noteName ?? '',
      params.vowelLabel ?? '',
    ];

    const longest = lines.reduce((a, b) => (a.length > b.length ? a : b));
    ctx.font = `${baseFontSize * dpr}px system-ui, sans-serif`;
    const textW = ctx.measureText(longest).width;
    const boxW  = textW + padding * 2 * dpr;
    const boxH  = lines.length * lineH * dpr + padding * dpr;

    const bx = p.x - boxW / 2;
    const by = p.y - boxH - (20 * dpr);

    ctx.save();
    ctx.globalAlpha = 0.82;
    ctx.fillStyle   = 'rgba(0,0,0,0.55)';
    this._roundRect(bx, by, boxW, boxH, 6 * dpr);
    ctx.fill();

    ctx.globalAlpha = 1;
    ctx.fillStyle   = color;
    ctx.textAlign   = 'center';
    ctx.textBaseline = 'top';

    lines.forEach((line, i) => {
      const isFirst = i === 0;
      ctx.font = `${isFirst ? 600 : 400} ${baseFontSize * dpr}px system-ui, sans-serif`;
      ctx.fillText(
        line,
        p.x,
        by + (padding + lineH * i) * dpr
      );
    });
    ctx.restore();
  }

  // Small vertical bar to the right of the person showing pitch (high = standing)
  _drawPitchBar(pose, slotIdx, params, color, transform) {
    const ls = getKP(pose, KP.LEFT_SHOULDER);
    const rs = getKP(pose, KP.RIGHT_SHOULDER);
    if (!ls || !rs) return;

    const midX    = (ls.x + rs.x) / 2;
    const midY    = (ls.y + rs.y) / 2;
    const centre  = this._toCanvas(midX, midY, transform);
    const dpr     = window.devicePixelRatio || 1;
    const barH    = 60 * dpr;
    const barW    = 6  * dpr;
    const offset  = 30 * dpr; // pixels to the right of body centre in canvas

    const cfg    = VOICE_CONFIG[params.voiceType];
    const ratio  = (params.midiNote - cfg.pitchRange.min) /
                   (cfg.pitchRange.max - cfg.pitchRange.min);
    const filled = barH * ratio;

    const ctx = this.ctx;
    ctx.save();
    ctx.globalAlpha = 0.75;

    // Track (background)
    ctx.fillStyle = 'rgba(255,255,255,0.15)';
    this._roundRect(centre.x + offset, centre.y - barH / 2, barW, barH, 3 * dpr);
    ctx.fill();

    // Fill (current pitch)
    ctx.fillStyle = color;
    this._roundRect(
      centre.x + offset,
      centre.y + barH / 2 - filled,
      barW,
      filled,
      3 * dpr
    );
    ctx.fill();

    ctx.restore();
  }

  // Small arc indicator showing vowel position between the wrists
  _drawVowelIndicator(pose, slotIdx, params, color, transform) {
    const lw = getKP(pose, KP.LEFT_WRIST);
    const rw = getKP(pose, KP.RIGHT_WRIST);
    if (!lw || !rw) return;

    // Draw a small dot at the midpoint of the two wrists
    const midRaw = { x: (lw.x + rw.x) / 2, y: (lw.y + rw.y) / 2 };
    const mid    = this._toCanvas(midRaw.x, midRaw.y, transform);
    const dpr    = window.devicePixelRatio || 1;
    const r      = 10 * dpr;

    const ctx = this.ctx;
    ctx.save();

    // Outer ring
    ctx.beginPath();
    ctx.arc(mid.x, mid.y, r, 0, Math.PI * 2);
    ctx.strokeStyle = color;
    ctx.lineWidth   = 2 * dpr;
    ctx.globalAlpha = 0.6;
    ctx.stroke();

    // Filled arc: vowel position mapped to arc angle
    ctx.beginPath();
    ctx.moveTo(mid.x, mid.y);
    ctx.arc(mid.x, mid.y, r - 2 * dpr,
      -Math.PI / 2,
      -Math.PI / 2 + params.vowelPos * Math.PI * 2
    );
    ctx.fillStyle   = color;
    ctx.globalAlpha = 0.5;
    ctx.fill();

    ctx.restore();
  }

  // ── Canvas helper: rounded rectangle (works in all browsers) ─────────────
  _roundRect(x, y, w, h, r) {
    const ctx = this.ctx;
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
  }
}
