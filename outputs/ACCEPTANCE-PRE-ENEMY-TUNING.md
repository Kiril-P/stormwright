# Stormwright — acceptance evidence

**Review updated 2026-09-08.** The game has a current rendered six-encounter victory,
a directed guardian defeat, reviewed spell recordings, passing behavioral/lifecycle
checks, and passing final dense/guardian p95 measurements. Targeted control cases,
the complete enemy motion review, and dense-spike attribution are finishing. The
remaining rows identify those specific gaps; no human playtest is claimed.

[Watch the actual spell showcase](gameplay/spell-showcase.mp4): 25.18 seconds of
Godot gameplay at its native 1280×720, 60 FPS, with stereo audio. The
[media QA](gameplay/spell-showcase-qa.md) and
[29-phase contact sheet](gameplay/spell-phase-contact-sheet.png) document its scope.

The [manifest](verification/manifest.json) records source locations, timestamps,
and source/delivery hashes for results, logs and selected media. Current final runs
supersede explicitly historical captures; raw scratch recordings remain in `work/`.

| Gate | Current evidence and status | Remaining evidence |
| --- | --- | --- |
| **A01 — Startup and controls** | **Startup verified; walkthrough finishing.** [Current root import](verification/full-run-rendered/import-engine.log) is clean. [Native observation](verification/native/summary.json) records title launch, laboratory movement/casting, pause and confirmation interaction. | Complete the targeted application-level control/menu walkthrough, combined with the existing native observations. |
| **A02 — Movement, aim, dash, camera** | **Partial.** Native input and 111 focused aim samples show accurate projection; [flow checks](verification/flow/result.json) prove menu isolation and input rearming. The [directed guardian review](verification/guided-guardian/summary.json) observes movement and successful dash counterplay. | Finish the boundary and stationary-dash cases through observed application inputs. |
| **A03 — Three signature spells** | **Verified in recorded motion and phase review.** The [25-second playable reel](gameplay/spell-showcase.mp4), [29-phase contact sheet](gameplay/spell-phase-contact-sheet.png), and [production state record](verification/spell-reel/reel-state.json) cover charge, discharge/gathering, impact/fracture, decay and empty misses for all three spell families. [Media QA](gameplay/spell-showcase-qa.md) states the staged fixture and actual movie resolution. | No missing spell sequence identified. Artistic preference remains available for user review in the playable clip. |
| **A04 — Damage rules** | **Verified in the recorded behavioral suite.** [32 spell checks](verification/spells/result.json) cover reach, ordered hits, cooldown, charge, delayed Cataclysm, per-victim limits, snapshots and secondary-effect rules; [engine log](verification/spells/engine.log) is clean. | Rerun affected checks if gameplay logic changes before delivery. |
| **A05 — Eight modifiers and replacement** | **Verified behavior and recorded compositions.** Spell checks verify all eight equip/remove paths; [72 flow checks](verification/flow/result.json) exercise choice, replacement preview, slot selection and skip. [Reel segments 04–06](gameplay/spell-showcase.mp4) show Fork + Chain, Pierce + Overload, and Gravity Well + Aftershock. A normal-run [upgrade screen](verification/full-run-rendered/upgrade-03.png) was inspected at 720p. | No additional behavior or required combination recording gap identified. |
| **A06 — Bounded effects and cleanup** | **Verified.** Spell fixtures demonstrate the 32-child and combined 128-entity limits. [20 lifecycle checks](verification/lifecycle/result.json) establish stable resource/node counts after warm-up and three heavy cast/death/reset cycles. The [final dense run](verification/dense-final/result.json) sustains 24 enemies, all spell families and eleven ultimates. | Headless resource lifetime checks do not measure GPU memory; rendered frame-time evidence is recorded separately in A14. |
| **A07 — Enemy coherence and counterplay** | **Partial.** [17 enemy checks](verification/enemies/result.json) verify committed lunge endpoints, sector danger/safety, interruption, stagger, owned-attack retirement, pulse timing, marks and Aftershock travel. | Inspect every archetype's complete moving state cycle and readable safe counterplay at gameplay scale. |
| **A08 — Two-phase guardian** | **Verified through directed agent play.** [17 observed command chunks](verification/guided-guardian/summary.json) reach phase two and victory at normal combat stats: 25.02 simulated seconds, 87 health, two ultimates. Fan, slam and expanding pulse patterns are observed across the two phases, with safe counterplay in state records and selected images. | The fixture covers encounter six and uses agent-chosen application inputs; no human or native OS-input playtest is claimed. |
| **A09 — Complete run and restart** | **Verified.** The [current rendered normal run](verification/full-run-rendered/result.json) clears all six encounters, enters phase two and wins: 101 kills, 80 health, 127.5167 simulated seconds, 230 casts and ten ultimates. [Five upgrade captures and six combat captures](verification/full-run-rendered/) accompany the [victory screen](verification/full-run-rendered/result.png). Separate flow checks exercise defeat and clean restart. | The automated run uses the real combat loop. The 10–15 minute first-time pacing goal remains an unmeasured design aspiration, not a claimed human result. |
| **A10 — Menus, pause and focus** | **Verified with combined behavioral and native evidence.** Flow checks cover paused spells/timers, held-input isolation, settings return, confirmation/cancel, restart and title cleanup. Native title/laboratory/pause/confirmation interaction and two actual focus losses followed by pause are recorded in the [observer summary](verification/native/summary.json). | The additional application walkthrough is tracked in A01; the gate does not require repeating every menu through OS automation. |
| **A11 — Persistence** | **Verified in the recorded suite.** Flow checks reload six preferences and a best-run time, kill count and three-modifier build in a fresh game instance; malformed/missing saves fall back cleanly, and laboratory results cannot change the record or save file. [Clean log](verification/flow/engine.log). | No additional behavior gap identified in this gate. |
| **A12 — Laboratory** | **Verified.** Flow checks use the production spells, three-slot selection, refill and target reset. Reset clears live projectiles/orbiters and pending Cataclysm while preserving modifiers; old targets are freed. Native casting and the [spell reel](gameplay/spell-showcase.mp4) exercise the same laboratory systems. | No additional laboratory behavior gap identified. |
| **A13 — Visual and audio coherence** | **Spell coherence reviewed; enemy motion review finishing.** The delivered reel and [media QA](gameplay/spell-showcase-qa.md) cover moving Crown attachment, spell phases, environmental aftermath and complete sound playback. [Audio mix statistics](verification/audio/state.json) show the bounded production voice pool. [Normal wave-five combat](verification/full-run-rendered/wave-05-combat.png) and the guardian sequence show mixed hostile/player effects at gameplay scale. | Finish reviewing the separate full enemy attack/reaction motion reel. |
| **A14 — Performance and layout** | **Performance threshold and layout verified; spike attribution finishing.** Final dense p95 is **10.199 ms**; guardian p95 is **10.036 ms**, both below the 20 ms target. Current full-game [720p combat](verification/full-run-rendered/wave-05-combat.png), [720p upgrade](verification/full-run-rendered/upgrade-03.png), and [1080p layout](verification/dense-final/layout-after-measurement.png) were inspected alongside UI-only layouts. | Record the profiling attribution for the reported dense spikes; this does not change the passed p95 threshold. |
| **A15 — Reproducible delivery** | **Verified documentation and artifacts.** [README](../README.md) supplies launch, controls, scenario, benchmark and observation commands. [Audio provenance](../assets/audio/PROVENANCE.md), the [playable spell reel](gameplay/spell-showcase.mp4), and this hashed evidence index document implementation sources and verification limits. | Refresh the two remaining review entries when their current runs finish. |

## Performance evidence

Both final benchmarks use rendered real-time Forward+ / Metal on the Apple M5 Pro,
a 1920×1080 window, normal particle/flash settings and shake 0.45. The UI's logical
viewport is 1600×900. Each runs for 65 seconds and measures monotonic wall-clock
frame intervals after a five-second warm-up.

| Final fixture | Measured frames | Median | p95 | p99 | Maximum | Frames >20 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| [24 regular enemies](verification/dense-final/result.json) | 7,199 | 7.819 ms | **10.199 ms** | 15.830 ms | 36.609 ms | 23 |
| [Two-phase guardian](verification/guardian-performance/result.json) | 7,202 | 8.305 ms | **10.036 ms** | 11.502 ms | 17.472 ms | 0 |

The dense run repeatedly casts Lance and Crown with Fork / Chain / Resonance and
spends eleven Cataclysms. It retains the full population for sustained load. Both
fixtures raise health to keep their measurement populations alive; the separate
normal run and directed review establish victories at normal combat stats.

The dense result preserves every >20 ms interval with its timestamp and effect
counts. Profiling attribution is being collected separately; no cause is inferred
from this aggregate report. Both fixtures meet the PRD's p95 ≤20 ms target despite
the reported dense spikes. Their commands and clean logs are preserved:
[dense command](verification/dense-final/scenario-command.json),
[dense log](verification/dense-final/scenario-engine.log),
[guardian command](verification/guardian-performance/scenario-command.json),
[guardian log](verification/guardian-performance/scenario-engine.log).

The 1080p dense screenshot is a post-measurement HUD/layout view, after actor visuals
were cleared, and is not presented as evidence of visible crowd density. Normal
wave-five combat and the guardian captures provide that visual context. The
[earlier dense measurement](verification/dense-provisional/result.json) remains
historical and is superseded by the final run. Fixed-FPS normal runs and movie
recordings are not used as performance evidence.

## Repeated cleanup and directed guardian review

The [lifecycle harness](../game/lifecycle_checks.gd) creates 24 actors spanning all
four archetypes, casts all three spells with three full modifier builds, drives
actor deaths, and uses the real laboratory reset. Two identical warm-up cycles
stabilize lazy caches before three measured repetitions. Every repetition returns
`OBJECT_RESOURCE_COUNT` to **26**, scene nodes to **523**, and orphan nodes to **0**.
The named world-art caches settle at **94 meshes** and **13 materials**.

Because the resource monitor alone does not expose every procedural allocation, a
separate census follows actual mesh/material/shader/audio resources using weak
references. Each cycle peaks at **509** owned resources and **1,908** nodes, then
returns to **208** owned resources. **1,705** sampled transient resources are freed
per cycle, with **zero** sampled resources surviving outside live ownership or named
caches. Each cycle records 86 direct hits, 179 secondary hits, three ultimates and
up to 123 effects. All 15 event streams and 21 audio player nodes remain allocated
as expected. Headless mode intentionally suppresses playback; mixed-audio evidence
is separate. [Result](verification/lifecycle/result.json),
[clean log](verification/lifecycle/engine.log).

The [directed guardian sequence](verification/guided-guardian/summary.json) comprises
17 commands chosen by the root agent after inspecting each preceding state and PNG.
It uses production movement, dash and spell actions with normal combat stats. The
recorded build is Pierce / Chain / Aftershock. The sequence shows a
[slam warning](verification/guided-guardian/chunks/000005.png),
[escape while retaining 100 health](verification/guided-guardian/chunks/000006.png),
[phase transition](verification/guided-guardian/chunks/000007.png),
[phase-two support and Crown](verification/guided-guardian/chunks/000009.png),
[pulse crossing during dash](verification/guided-guardian/chunks/000012.png),
[late Cataclysm](verification/guided-guardian/chunks/000015.png), and
[victory](verification/guided-guardian/chunks/000017.png).

The guardian-only fixture finishes at 87 health with five kills, 71 direct hits,
12 secondary hits and two Cataclysms. Pulse radius increases from 1.7 to 5.1 during
the recorded inward dash while health remains 87. This supplies directed agent
counterplay evidence; it does not substitute for the native observer session,
a human playtest, or the separate six-encounter run. Screenshots establish selected
states and layout; the separate spell reel supplies moving spell sequences.

## Native observations and remaining targeted controls

The [native summary](verification/native/summary.json) derives from a 345-second
observer session with 678 state samples. It records laboratory spellcasting, movement,
dash, modifier changes, pause and confirmation interaction. Focus loss at approximately
122.61 and 320.04 seconds is followed by the paused state. It contains no normal run
or guardian defeat.

Among 111 focused, active, in-viewport samples whose aim was not arena-clamped, the
largest projected-aim error was approximately 0.000137 viewport pixels. All three
F12 captures had the pointer outside the viewport; their large aim offsets therefore
do not alone indicate a game projection error. A stale CUA window reference limited
continued OS automation. These genuine native observations are combined with the
behavioral fixtures and observed application-level review; they do not create a
requirement to repeat every menu through OS input. Boundary and stationary-dash
inspection remain targeted work. Human first-time pacing has not been measured.

## Design refinements retained in the implementation

- **Directional slams** commit to a visible sector with matching damage geometry,
  creating a readable route to safety instead of an unrelated circular impact.
- **Aftershock is an actual traveling damage ring.** Near targets are reached before
  distant targets, each is hit at most once, and its secondary damage earns no charge.
- **Stronger stagger and coordinated casting** make ordinary enemies react to heavy
  spells while preserving guardian attack continuity. Final pose work holds the
  Cataclysm gesture through its wind-up, pulses Crown launch gestures, and follows
  the moving staff attachment during Lance charge.

These refinements strengthen the PRD's spell, animation and counterplay intent. No
signature spell, modifier, encounter, enemy, menu state or laboratory feature was
removed to simplify acceptance.

The remaining work is the observed boundary/stationary-dash and menu walkthrough,
the complete enemy attack/reaction motion review, and attribution of dense frame
spikes. The measured performance threshold already passes. Any subsequent changes
require only the checks affected by them. The 10–15 minute first-time run target is
an unmeasured pacing aspiration; no automated or directed fixture is labeled as
human play-quality evidence.
