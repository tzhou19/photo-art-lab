---
name: photo-motion
description: Animate an approved still artwork as a downstream stage after any image-style skill, preserving locked regions. Create a controlled loop and, when requested, package it as an Apple Live Photo for Photos.
---

# Photo Motion

Turn an approved still image into a small, controlled motion artifact. This is a downstream stage that works after any image-style skill; never regenerate or restyle its source unless the user explicitly asks. Deliver an editable HyperFrames project and a high-quality H.264 MP4. Add an Apple Live Photo pair when requested.

## Workflow

1. Identify the approved source image and preserve it unchanged in the motion project.
2. Confirm the moving subject, locked regions, loop duration, frame rate, resolution, and motion preset. Use the defaults in `references/motion-spec.md` when the user has already approved them.
3. Write a JSON motion spec before authoring the animation. Save it beside the final outputs using the shared base name.
4. Create an editable HyperFrames project under `experiments/<base>-motion/`. Invoke the project-local `$hyperframes`, `$hyperframes-cli`, `$hyperframes-registry`, and `$media-use` skills and follow their validation workflow.
5. Search the HyperFrames catalog in English before hand-authoring a named effect. If no result fits, implement a deterministic, seek-safe effect.
6. Keep locked regions as one untouched full-frame source layer. Animate only isolated subject overlays, masks, vector reconstructions, or canvas regions.
7. Make the first and final loop states identical. Derive every frame from composition time; never use wall-clock time, timers, or unseeded randomness.
8. Run HyperFrames `lint`, then the full `check --snapshots`. Inspect the snapshots, preview when human review is available, render, and verify the encoded files with FFprobe and decoded frames.
9. For final MP4 exports, prioritize detail: use HyperFrames `--quality high --crf 8` unless the user specifies another quality/size tradeoff. This re-renders from the editable project and source artwork; never try to restore quality by transcoding an already compressed delivery MP4.
10. If the user requests an Apple Live Photo, read [references/live-photo.md](references/live-photo.md). Generate a paired still+MOV from the approved artwork and high-quality MP4. The MOV is required by the Live Photo format, but should stay H.264; do not create the large ProRes editorial MOV for this purpose. The user can import the pair together into Photos.

## Preservation rules

- The source image is the authority for composition, typography, color, texture, and crop.
- Keep the approved source image unchanged. A Live Photo pairing copy may be encoded separately to carry Apple's required pairing metadata.
- Locked regions must remain pixel-stable across the whole loop.
- Do not animate titles unless explicitly requested.
- Do not move a real photographic region merely because an abstract echo of the subject moves.
- Prefer small motion. If an isolated subject exposes a hole or duplicate edge, reduce travel or rebuild a clean plate before rendering.

## Output naming

Preserve the input's identity and style suffix. Use `<source-base>-motion-vN.mp4` for motion renders and `<source-base>-live-vN.jpg` plus `<source-base>-live-vN.mov` for a Live Photo pair. Start at `v2` if a prior approved export exists; never overwrite an approved version. Keep each pair's still and video on one matching base name.

For one source, keep the motion MP4, JSON spec, and experiment directory on a matching base name. Generate the paired MOV only when a Live Photo is requested.

## Default backend

Use HyperFrames for deterministic local motion and compositing. Generative image-to-video providers are optional future backends, not silent fallbacks. Do not invoke a paid or cloud provider without the user's explicit choice.

Read `references/motion-spec.md` for the schema and the approved soft-bounce preset.
