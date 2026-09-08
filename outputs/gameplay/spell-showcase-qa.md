# Spell showcase media review

The [playable MP4](spell-showcase.mp4) was converted locally from Godot's original
MJPEG/PCM AVI using `tools/video_encode.swift` and macOS AVFoundation. The original
AVI was opened read-only and retains its original modification time. Source and
output SHA-256 hashes are in [the verification report](spell-showcase.verification.json).
No downloaded encoder, external service, generated replacement frame, or edited
gameplay content was used.

The converted file contains one H.264 video track and one AAC audio track:

- 1280 × 720, 60 FPS, **1,511 video frames**, **25.1833 seconds**.
- Stereo 48 kHz audio: **1,208,800 decoded frames**, matching the source exactly.
- Full sample readback succeeds; decoded audio is non-silent, with a peak below
  full scale. Three extracted MP4 frames were used to check orientation and framing.
- Godot's 29 separate phase PNGs are 1920 × 1080. MovieWriter recorded at its initial
  1280 × 720 size; the MP4 preserves that native movie size without upscaling it.

The [contact sheet](spell-phase-contact-sheet.png) includes all 29 captured phases
in temporal order within their seven labeled laboratory segments. Still-image
inspection found no substantive missing geometry, framing, or spell-readability
defect. Lance and Fork paths are distinct, Crown's faceted shards remain visible
during gathering and launch, and Cataclysm has a bright core with separated rings.
The caster silhouette remains visible beside the major rupture. Subsequent phases
show debris and energy settling back into clear floor space; empty casts retain
their form without target reactions.

These are staged laboratory fixtures with production spell, collision, damage and
animation code. The recording and capture manifest identify target placement,
refilled ultimate charge and the hidden production HUD. This material supports
spell visual review; it is not a normal-run victory, UI-layout or performance test.
MovieWriter's fixed frame rate cannot establish real-time frame pacing. Audio and
motion coherence should be assessed by playing the MP4 as well as reviewing stills.
