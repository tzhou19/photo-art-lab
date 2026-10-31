# Motion specification

Save one JSON file per rendered motion artifact.

## Required fields

```json
{
  "schemaVersion": 1,
  "source": "outputs/example-relic.png",
  "outputs": {
    "mp4": "outputs/example-relic-motion-v2.mp4",
    "livePhoto": {
      "photo": "outputs/example-relic-live-v2.jpg",
      "pairedVideo": "outputs/example-relic-live-v2.mov"
    }
  },
  "canvas": { "width": 1120, "height": 1400, "fps": 30 },
  "loop": { "durationSeconds": 2.5, "seamless": true, "audio": false },
  "movingRegions": [],
  "lockedRegions": [],
  "preset": "soft-bounce",
  "parameters": {}
}
```

Each moving region records an `id`, a human-readable `description`, a bounding box or mask reference, and an optional `phaseSeconds`. Locked regions describe what must not move.

## Soft-bounce preset

Use this preset for small organic subjects such as printed mushrooms:

- duration: 2.5 seconds
- frame rate: 30 fps
- silent seamless loop
- horizontal expansion: at most 2.5%
- vertical change: at most 1.8%
- lift: at most 4 source pixels at 1120 × 1400
- damping character: playful but restrained, equivalent to a spring damping ratio around 0.55–0.65
- multi-subject phase staggering: 0–0.25 seconds
- first and last state: identical

Only the approved subject moves. The source photo, background print, paper texture, and title remain frozen unless named in `movingRegions`.

## Quality gate

- No movement or crop drift in locked regions.
- No exposed cutout holes, doubled edges, or color halos at maximum deformation.
- Motion remains legible at phone size without looking like a global zoom.
- MP4 matches the spec dimensions, duration, frame rate, and silent-audio requirement.
- If a Live Photo pair is produced, its JPEG and MOV have matching identifiers; the MOV preserves the MP4 dimensions, duration, frame rate, and audio state.
- The rendered final frame matches the first frame at the loop boundary.
