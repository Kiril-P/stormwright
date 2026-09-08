# Stormwright handoff

Open `project.godot` in Godot 4.7.2 and press F5. Choose **Enter the Circuit** for
six encounters and the guardian, or **Spell Laboratory** for immediate spell experiments.

WASD/arrows move, mouse aims, hold left mouse for Lance, right mouse for Crown,
Q for charged Cataclysm, Space to dash, Escape to pause. Run progress is not saved;
preferences and best victorious run are. No external dependencies are needed to play.

## Enemy feedback addressed

| Enemy | Health before → now | Speed before → now | New behavior |
| --- | --- | --- | --- |
| Shardling | 85 → 50 | 2.25 → 4.2 | Flanks while closing; longer committed leap, shorter recovery |
| Channeler | 115 → 68 | 1.55 → 2.8 | Circles between shots, retreats when rushed, faster bolts |
| Bulwark | 245 → 136 | 1.15 → 2.4 | Faster approach; missed slam opens shoulders/core, takes 50% extra damage during recovery |
| Warden | 2300 → 1850 | 0.8 → 1.2 | Less health padding, shorter gaps; both phases and all attack patterns retained |

Basic Lance now breaks Shardlings/Channelers in two hits and Bulwarks in four
before modifiers or the exposed-core bonus. Attack warnings remain committed,
so moving out of the marked area works rather than being tracked at impact.

[Watch the updated enemies](gameplay/enemy-showcase.mp4).
[Watch the spell showcase](gameplay/spell-showcase.mp4).

The current build passes 21 enemy checks, 32 spell checks and a rendered normal
six-encounter victory. Full details, source fingerprints and explicitly deferred
optional review are in [acceptance evidence](ACCEPTANCE.md). Human difficulty and
pacing remain for playtesting. No pending implementation approval is required.
