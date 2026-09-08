# Stormwright sound sources

Every WAV in this directory is original procedural synthesis created for this
game by `tools/generate_storm_audio.py`, using Python's standard library. No
external recordings, sample packs, voice models, music, or downloaded assets are
used. The reproducible script is the source for all sound assets.

Sounds use 32 kHz, signed 16-bit, stereo PCM. Spell releases contain short impact
transients, pitched bodies and fading air or granular tails. Crown summons use a
modal chord and staggered crystalline accents; launch sounds carry the rhythm.
Cataclysm's separate lead-in and detonation combine a bass sweep, high crack,
thunder, debris ticks and delayed reflections. Ambient harmonics loop over 16
seconds, with filtered-noise tails tapered at the seam.

The game adds bounded voice mixing, event throttles and a master limiter. Audio
settings independently control master, effects and ambience buses.

Regenerate from the repository root: `python3 tools/generate_storm_audio.py`.
