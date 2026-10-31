# Apple Live Photo export

## Pair structure

An Apple Live Photo is a still image and a short movie stored as one Photos asset. The image and movie must carry the same content identifier; the movie also needs a timed `still-image-time` marker. Apple's capture path supports HEIF or JPEG stills. This skill's helper writes a maximum-quality JPEG copy with the Apple MakerNote and a MOV that retains the input H.264 stream while adding Apple's movie metadata. The approved PNG remains untouched.

The MOV is required as the paired video resource. It is not a ProRes editing master: use H.264 and keep the file compact. Pairing an already compressed MP4 without first re-rendering it will preserve its existing compression, so create the final MP4 from the editable HyperFrames composition and original artwork first.

## Export workflow

1. Render from the approved composition and source artwork at high quality. For this project the user prefers `--quality high --crf 8` to keep texture and fine print detail.
2. Use the approved still artwork and that high-quality MP4 as helper inputs:

   ```sh
   swift -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk \
     -module-cache-path /tmp/swift-module-cache \
     .agents/skills/photo-motion/scripts/make_live_photo.swift \
     <approved-still.png> <high-quality-motion.mp4> <output-base>
   ```

   Omit the output extension. The helper creates `<output-base>.jpg` and `<output-base>.mov`, with the same base name.

3. Check the MOV with `ffprobe`: it should retain the input dimensions, frame rate, H.264 video stream, and duration; include the QuickTime content identifier plus a timed data track. Confirm the identifier matches the JPEG MakerNote. The helper checks that the MakerNote identifier can be read back. Decode the MOV to ensure it is not corrupt.
4. Have the user import both files together into Apple Photos. Keep the original still PNG and motion MP4 as project deliverables; the pair is a compatibility copy for Photos.

Use a new version suffix for each revision, such as `<source-base>-live-v2.jpg` and `<source-base>-live-v2.mov`. Never overwrite an approved pair. If the user hasn't asked to import the pair into their library, create the files and explain how to import them rather than changing Photos on their behalf.

## Quality tradeoffs

- The JPEG helper uses ImageIO quality `1.0`, the highest JPEG quality setting. JPEG remains lossy; keep the PNG as the exact still master.
- HyperFrames CRF is the video quality control: lower CRF means higher quality and larger files. CRF 8 is this user's preference for the final Live Photo motion. It is not mathematical losslessness.
- The helper copies the already encoded video samples into MOV instead of re-encoding them, so adding Live Photo metadata does not introduce another video-generation loss.
- For a smaller deliverable, ask or follow the user's stated size preference before increasing CRF. Do not silently use a delivery/default render when the user has prioritized texture detail.

## Metadata basis

Apple pairs the movie's `com.apple.quicktime.content.identifier` with the still image's MakerNote identifier. A timed `com.apple.quicktime.still-image-time` sample marks the corresponding still frame in the movie timeline. See [Apple's Live Photo capture and save guide](https://developer.apple.com/documentation/avfoundation/capturing-and-saving-live-photos?changes=_9) and [movie metadata reference](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/livephotomoviemetadata?changes=__9_5&language=objc).
