'use strict';

// ─── App ──────────────────────────────────────────────────────────────────
// Main orchestration class. Ties together:
//   audioEngine + 4× VoiceSynth  (voice-synth.js)
//   PoseDetector                  (pose-detector.js)
//   ParameterMapper               (parameter-mapper.js)
//   Renderer                      (renderer.js)

class App {
  constructor() {
    this.videoEl    = document.getElementById('webcam');
    this.canvasEl   = document.getElementById('overlay');
    this.startBtn   = document.getElementById('start-btn');
    this.startScreen = document.getElementById('start-screen');
    this.hudEl      = document.getElementById('hud');
    this.statusEl   = document.getElementById('status-text');
    this.singerLabelsEl = document.getElementById('singer-labels');

    this.detector   = new PoseDetector();
    this.mapper     = new ParameterMapper();
    this.renderer   = new Renderer(this.canvasEl);

    // 4 voices: bass[0], tenor[1], mezzo[2], soprano[3]
    this.voices = VOICE_ORDER.map(type => new VoiceSynth(type));

    this._running    = false;
    this._rafId      = null;
    this._videoW     = 640;
    this._videoH     = 480;

    this._bindEvents();
  }

  _bindEvents() {
    this.startBtn.addEventListener('click', () => this._onStart());
    window.addEventListener('resize', () => this.renderer.resize());
  }

  // ── Start sequence ────────────────────────────────────────────────────────
  async _onStart() {
    this.startBtn.disabled = true;
    this.startBtn.textContent = 'Starting…';

    try {
      await this._setupWebcam();
      this._setupAudio();
      await this._loadModels();
      this._enterLiveMode();
    } catch (err) {
      console.error(err);
      this.startBtn.disabled = false;
      this.startBtn.textContent = 'Start Singing';
      this._setStatus('Error: ' + (err.message || err));
      alert('Could not start: ' + (err.message || err));
    }
  }

  async _setupWebcam() {
    this._setStatus('Requesting camera…');

    const stream = await navigator.mediaDevices.getUserMedia({
      video: {
        width:  { ideal: 1280 },
        height: { ideal: 720 },
        facingMode: 'user',
      },
      audio: false,
    });

    this.videoEl.srcObject = stream;
    await new Promise((res, rej) => {
      this.videoEl.onloadedmetadata = () => {
        this._videoW = this.videoEl.videoWidth;
        this._videoH = this.videoEl.videoHeight;
        this.videoEl.play().then(res).catch(rej);
      };
    });

    // Size the canvas to match the video's actual pixel dimensions
    // (renderer will handle scaling to the display size)
    this.renderer.resize();
  }

  _setupAudio() {
    this._setStatus('Initialising audio…');
    audioEngine.init();
    audioEngine.resume();
    this.voices.forEach(v => v.build());
  }

  async _loadModels() {
    await this.detector.init((msg) => this._setStatus(msg));
  }

  _enterLiveMode() {
    // Hide start screen, show HUD
    this.startScreen.style.display = 'none';
    this.hudEl.classList.remove('hidden');
    this._buildSingerLabels();

    this._setStatus('Ready – step into frame!');
    this._running = true;
    this._loop();
  }

  _buildSingerLabels() {
    this.singerLabelsEl.innerHTML = '';
    VOICE_ORDER.forEach((type, i) => {
      const div = document.createElement('div');
      div.className = 'singer-label';
      div.id = `label-${type}`;
      div.style.color = SINGER_COLORS[i];
      div.innerHTML = `
        <div class="voice-name">${SINGER_LABELS_TEXT[i]}</div>
        <div class="note-name" id="note-${type}">—</div>
        <div class="vowel-name" id="vowel-${type}">—</div>
      `;
      this.singerLabelsEl.appendChild(div);
    });
  }

  // ── Main loop ─────────────────────────────────────────────────────────────
  _loop() {
    if (!this._running) return;

    // Kick off pose estimation (non-blocking, skips if already detecting)
    this.detector.estimatePoses(this.videoEl);

    // Use the latest available poses (may be 1-2 frames stale, that's fine)
    const poses       = this.detector.latestPoses;
    const voiceParams = this.mapper.update(poses, this._videoW);

    // Update synths and build enriched params (adds noteName / vowelLabel)
    const enriched = voiceParams.map((p, i) => {
      const voice = this.voices[i];
      voice.setActive(p.active);
      if (p.active) {
        voice.setPitch(p.midiNote);
        voice.setVowel(p.vowelPos);
      }
      const info = voice.getDisplayInfo();
      return { ...p, noteName: info.noteName, vowelLabel: info.vowelLabel };
    });

    // Render skeleton
    this.renderer.draw(poses, enriched, this._videoW, this._videoH);

    // Update HUD labels
    this._updateHUD(enriched);

    this._rafId = requestAnimationFrame(() => this._loop());
  }

  _updateHUD(enriched) {
    enriched.forEach((p, i) => {
      const type = VOICE_ORDER[i];
      const labelEl = document.getElementById(`label-${type}`);
      const noteEl  = document.getElementById(`note-${type}`);
      const vowelEl = document.getElementById(`vowel-${type}`);
      if (!labelEl) return;

      if (p.active) {
        labelEl.classList.add('active');
        noteEl.textContent  = p.noteName  ?? '—';
        vowelEl.textContent = p.vowelLabel ?? '—';
      } else {
        labelEl.classList.remove('active');
        noteEl.textContent  = '—';
        vowelEl.textContent = '—';
      }
    });

    // Status: show how many singers are active
    const activeCount = voiceParams.filter(p => p.active).length;
    if (activeCount === 0) {
      this._setStatus('Step into frame to sing!');
    } else {
      this._setStatus(
        activeCount === 1
          ? '1 singer detected'
          : `${activeCount} singers detected`
      );
    }
  }

  _setStatus(msg) {
    if (this.statusEl) this.statusEl.textContent = msg;
  }
}

// ── Bootstrap ────────────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  window._app = new App();
});
