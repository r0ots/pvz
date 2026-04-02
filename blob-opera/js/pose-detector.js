'use strict';

// ─── PoseDetector ─────────────────────────────────────────────────────────
// Wraps TensorFlow.js MoveNet MultiPose Lightning.
// Provides simple async API: init() then estimatePoses(videoEl).
//
// Keypoint index reference (17 points):
//  0  nose           5  left_shoulder   6  right_shoulder
//  7  left_elbow     8  right_elbow     9  left_wrist    10 right_wrist
// 11  left_hip      12  right_hip      13  left_knee     14 right_knee
// 15  left_ankle    16  right_ankle

const KP = {
  NOSE:           0,
  LEFT_EYE:       1,
  RIGHT_EYE:      2,
  LEFT_EAR:       3,
  RIGHT_EAR:      4,
  LEFT_SHOULDER:  5,
  RIGHT_SHOULDER: 6,
  LEFT_ELBOW:     7,
  RIGHT_ELBOW:    8,
  LEFT_WRIST:     9,
  RIGHT_WRIST:   10,
  LEFT_HIP:      11,
  RIGHT_HIP:     12,
  LEFT_KNEE:     13,
  RIGHT_KNEE:    14,
  LEFT_ANKLE:    15,
  RIGHT_ANKLE:   16,
};

// Skeleton connections for drawing
const SKELETON_PAIRS = [
  [KP.NOSE, KP.LEFT_EAR], [KP.NOSE, KP.RIGHT_EAR],
  [KP.LEFT_EAR, KP.LEFT_SHOULDER], [KP.RIGHT_EAR, KP.RIGHT_SHOULDER],
  [KP.LEFT_SHOULDER, KP.RIGHT_SHOULDER],
  [KP.LEFT_SHOULDER, KP.LEFT_ELBOW],  [KP.LEFT_ELBOW, KP.LEFT_WRIST],
  [KP.RIGHT_SHOULDER, KP.RIGHT_ELBOW],[KP.RIGHT_ELBOW, KP.RIGHT_WRIST],
  [KP.LEFT_SHOULDER, KP.LEFT_HIP],    [KP.RIGHT_SHOULDER, KP.RIGHT_HIP],
  [KP.LEFT_HIP, KP.RIGHT_HIP],
  [KP.LEFT_HIP, KP.LEFT_KNEE],        [KP.LEFT_KNEE, KP.LEFT_ANKLE],
  [KP.RIGHT_HIP, KP.RIGHT_KNEE],      [KP.RIGHT_KNEE, KP.RIGHT_ANKLE],
];

// Minimum score to trust a keypoint
const KEYPOINT_THRESHOLD = 0.25;

// Minimum overall pose score to consider a detection valid
const POSE_THRESHOLD = 0.20;

class PoseDetector {
  constructor() {
    this.detector = null;
    this.isReady = false;
    this._detecting = false;
    this._lastPoses = [];
  }

  async init(onProgress) {
    onProgress?.('Loading TensorFlow.js backend…');
    await tf.ready();
    await tf.setBackend('webgl');

    onProgress?.('Downloading MoveNet MultiPose model…');
    this.detector = await poseDetection.createDetector(
      poseDetection.SupportedModels.MoveNet,
      {
        modelType: poseDetection.movenet.modelType.MULTIPOSE_LIGHTNING,
        enableTracking: true,
        trackerType: poseDetection.TrackerType.BoundingBox,
      }
    );

    this.isReady = true;
    onProgress?.('Pose model ready');
  }

  // Non-blocking: skips if a detection is already in flight.
  // Returns the latest pose array (may be from a previous frame).
  async estimatePoses(videoEl) {
    if (!this.isReady || this._detecting) return this._lastPoses;

    this._detecting = true;
    try {
      const raw = await this.detector.estimatePoses(videoEl, {
        maxPoses: 4,
        flipHorizontal: false, // we flip coordinates in JS to match mirrored video
        scoreThreshold: POSE_THRESHOLD,
      });
      this._lastPoses = raw.filter(p => p.score >= POSE_THRESHOLD);
    } catch (e) {
      console.warn('Pose estimation error:', e);
    } finally {
      this._detecting = false;
    }
    return this._lastPoses;
  }

  get latestPoses() {
    return this._lastPoses;
  }
}

// ─── Utility: extract a named keypoint from a pose ─────────────────────────
function getKP(pose, index) {
  const kp = pose.keypoints[index];
  if (!kp || kp.score < KEYPOINT_THRESHOLD) return null;
  return kp;
}

// ─── Utility: get the centre-x of a pose (shoulder midpoint or nose) ───────
function getPoseCentreX(pose) {
  const ls = getKP(pose, KP.LEFT_SHOULDER);
  const rs = getKP(pose, KP.RIGHT_SHOULDER);
  if (ls && rs) return (ls.x + rs.x) / 2;
  const nose = getKP(pose, KP.NOSE);
  if (nose) return nose.x;
  // fallback: average of all visible keypoints
  const visible = pose.keypoints.filter(k => k.score >= KEYPOINT_THRESHOLD);
  if (visible.length === 0) return 0;
  return visible.reduce((s, k) => s + k.x, 0) / visible.length;
}
