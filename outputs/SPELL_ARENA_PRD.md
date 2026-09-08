# Spell Arena — Product Requirements Document

Version 1.0 · 2026-09-08 · Working title: **Stormwright**

## 1. Product intent

Create a complete, replayable single-player Godot game in which building and casting
extraordinary spells is the primary attraction. The player should feel increasingly
powerful because spells change shape, timing, targeting and consequences—not merely
because damage numbers increase.

The defining quality bar is the whole interaction: a readable casting pose leads
into a spectacular effect, an enemy reacts at the correct moment, the arena catches
the light and debris, and control remains fluid throughout. Environment and enemies
support this experience without competing with the spells for visual attention.

This document supplies the previously missing PRD. The user's confirmed priorities
are impressive spells, cohesive animation and reactions, a functioning game loop,
and Godot as the engine. Specific counts, balance values, controls and the working
title below are design decisions made for this PRD; they are not claims of separate
user approval. They define the implementation baseline and can be revised explicitly.

## 2. Intended experience and scope

A player enters a ruined storm temple, fights through six escalating encounters,
chooses spell modifiers between encounters, and defeats a guardian using a build
that visibly differs from the starting loadout. Target run length is 10–15 minutes
for a first-time player, with an immediate restart option after victory or defeat.

The first release includes:

- One polished, bounded 3D arena with an elevated gameplay camera.
- One animated, staff-wielding caster with movement, aiming and a defensive dash.
- Three signature spells: Storm Lance, Storm Crown and Cataclysm.
- Eight behavior-changing modifiers and three equipped modifier slots.
- Three regular enemy archetypes and a two-phase final guardian.
- Six encounters, upgrade choices, victory, defeat and replay.
- A player-facing spell laboratory for immediate experimentation.
- Complete HUD, pause/settings, sound, local preferences and best-run summary.
- In-engine input, state and capture hooks for repeatable verification.

Multiplayer, an open world, inventory loot, a narrative campaign, procedural level
generation, additional elemental schools and permanent power progression are
outside this release. These exclusions must not be used to cut the features above.

## 3. Core loop and progression

### Moment-to-moment loop

Move and aim → anticipate enemy telegraphs → cast Lance or Crown → exploit stagger
and positioning → build Cataclysm charge → trigger a large detonation → reposition.

Movement remains available during ordinary casting. Charge and follow-through may
reduce speed briefly, but attacks must not introduce unexplained input lockouts.
Dash provides a deliberate escape from telegraphed attacks; it is not required to
compensate for unreadable visual clutter.

### Encounter structure

| Encounter | Purpose | Required composition |
| --- | --- | --- |
| 1 | Teach aim, casting and dash through play | Small group of melee enemies; contextual control hints |
| 2 | Introduce ranged pressure | Melee enemies plus ranged enemies |
| 3 | Introduce positioning and stagger | Armored enemies mixed with melee |
| 4 | Test the first spell combinations | Mixed enemies arriving in two clearly signaled groups |
| 5 | Deliver a dense pre-finale spectacle | All regular archetypes, with a hard population cap |
| 6 | Resolve the run | Two-phase guardian with bounded supporting enemies |

Between encounters 1–5, pause combat and offer three distinct modifier choices
from the remaining pool. Picking an upgrade visibly changes the build summary.
The player may skip. If all three slots are occupied, show the replacement choice
and resulting loadout before confirming. No timer pressures this decision.

Heal 25% of maximum health between encounters, capped at maximum. Preserve the
build and Cataclysm charge. Defeat resets the run's combat state and upgrades;
preferences and best-run records persist. Victory reports elapsed time, enemies
defeated, selected modifiers and best-run comparison.

All three spell forms are available from the start. Crown is cooldown-limited and
Cataclysm is charge-limited. The player can therefore understand the spell language
early rather than unlocking the principal visual showcase only at the end.

## 4. Controls, camera and responsiveness

Keyboard and mouse are the required input devices for this release.

| Input | Action |
| --- | --- |
| WASD / arrow keys | Camera-relative movement |
| Mouse position | Aim on the arena plane |
| Left mouse, hold | Repeat Storm Lance casts while available |
| Right mouse | Summon/release Storm Crown sequence |
| Q | Cast charged Cataclysm at the indicated area |
| Space | Dash in movement direction; aim direction if stationary |
| Escape | Pause/resume or dismiss the active menu |

Use named input actions. Show controls in the start screen and pause menu. Disable
combat input while selecting upgrades or interacting with menus. Losing window
focus pauses a run. Returning focus must not cause an unintended buffered cast.

Use an elevated orthographic camera with enough look-ahead to reveal the aim area.
Keep the player, immediate threats and ground telegraphs legible at 1280×720 and
1920×1080. Follow smoothly without noticeable aim-plane drift. Shake must be short,
bounded and adjustable to zero. Keep the playable floor free of foreground occlusion.

## 5. Signature spells

Starting timing values below are tuning targets, not reasons to retain poor feel.
Preserve each spell's role and phases when adjusting them through playtesting.

### Storm Lance — precise, repeatable force

Role: reliable aimed damage and charge generation.

Charge for roughly 0.15 seconds, discharge along a finite aimed line, then recover
for a total cast interval near 0.55 seconds. Use a consistent hit query and show the
actual reach. Default Lance strikes the first valid enemy along its path.

Visual phases:

1. Hands and staff gather spiraling filaments; the caster braces toward the aim.
2. A thick, jagged discharge erupts with a bright core, turbulent outer ribbons and
   short-lived secondary branches. It must read as a powerful volume, not a thin line.
3. Impact produces a directional fracture burst, enemy recoil and a brief local flash.
4. Residual arcs and a restrained floor trace fade as the caster follows through.

The effect must remain impressive against both a target and an empty aim direction.
Do not fabricate impact damage or enemy reactions when the cast misses.

### Storm Crown — orbiting spectacle and rhythmic coverage

Role: a deliberate burst that rewards positioning among several threats.

Start with an approximately 6-second cooldown. Gather seven conspicuous storm shards
around and above the caster over approximately 0.5 seconds. Let the constellation
settle briefly, then launch shards in a legible sequence toward valid nearby enemies.
Use the current aim direction when no target is available.

Shards have a crystalline body, surrounding fragments, and curved trails. Their
orbits must visibly move in three dimensions. Launching changes both silhouette
and motion; impacts fracture into compact electric flowers. Avoid a stationary
ring of identical particles. Attached shard origins follow the moving caster.

If a target dies before impact, a shard continues or retargets consistently within
its range; it must never snap across the arena or retain an invalid reference.

### Cataclysm — earned, delayed battlefield rupture

Role: the strongest punctuation of a fight, with an identifiable build-up and echo.

Generate charge from successful primary spell hits on living enemies. Secondary
modifier hits do not generate charge. Tune for roughly one Cataclysm per 20–30
seconds of active fighting. Charge is shown explicitly and consumed once per cast.

On Q, show a clamped aim area, mark enemies in that area and begin a roughly
0.6-second wind-up. During this interval charge glows through armor seams. Detonate
at the committed ground location even if marked enemies have moved or died.

The rupture has a star-shaped core, separated expanding ground rings, rising energy
ribbons, airborne debris and bounded arcs to nearby victims. Damage timing must
match the visible rupture. Each enemy receives the main area damage at most once.
The caster completes a forceful staff gesture; nearby surfaces respond to the flash
and the echo settles through dust, fragments and fading floor traces.

Normal enemies stagger strongly. The guardian receives damage and an appropriately
scaled response without losing its entire attack schedule to repeated stun locks.

## 6. Spell composition

Eight modifiers form the initial pool. Each card describes an actual behavior and
shows its affected spells. Modifiers apply automatically to compatible equipped
spells; they must have visible consequences beyond a numeric bonus.

| Modifier | Behavior | Applies to |
| --- | --- | --- |
| Fork | Lance emits two weaker angled branches; Crown launches paired smaller shards | Lance, Crown |
| Chain | A direct hit sends a visible arc to up to two previously unhit nearby enemies | Lance, Crown |
| Pierce | The primary path can hit up to three distinct enemies and continues visibly | Lance, Crown |
| Echo | A weaker copy repeats after a short delay from the recorded cast origin/aim | Lance, Crown |
| Overload | Direct hits build a three-hit enemy charge, then trigger a small local burst | Lance, Crown |
| Gravity Well | Cataclysm's wind-up pulls regular enemies toward its center | Cataclysm |
| Aftershock | Cataclysm leaves a clearly timed second expanding damage ring | Cataclysm |
| Resonance | Crown's constellation grows to nine shards and uses a longer, alternating launch rhythm | Crown |

### Interaction rules

- A loadout holds three unique modifiers. Replacing a modifier removes its behavior.
- A cast snapshots the current loadout; an upgrade never mutates a projectile in flight.
- Primary shape changes apply before collision queries. Resolve pierced victims in
  travel order, then direct-hit reactions, then bounded secondary effects.
- Use cast identity and victim identity to prevent accidental duplicate direct hits.
- Chain arcs, Echo copies, Overload bursts and Aftershock damage are secondary effects.
  They cannot recursively trigger another secondary effect or generate ultimate charge.
- Echo repeats the cast's primary shape at reduced damage; it does not create another Echo.
- Chain uses a stable distance ordering and excludes victims already visited by that chain.
- Gravity Well affects regular enemies; the guardian visibly resists displacement.
- Limit any one cast to 32 spawned damaging child effects and total active damaging
  entities to 128. At the cap, omit newest optional children deterministically.
- Cosmetic quality limits may reduce dust/trail density, but cannot change hit rules.

Demonstrate at least Fork + Chain, Pierce + Overload, and Gravity Well + Aftershock
in recorded in-engine scenarios. Verify that removing a modifier restores its
absence and that a capped chain terminates without script errors or frame spikes.

## 7. Enemies and final guardian

Enemies must have recognizable silhouettes, complete idle/move/anticipate/attack/
recover/hit/death states, and attacks whose damage agrees with their telegraphs.

| Archetype | Silhouette and behavior | Counterplay |
| --- | --- | --- |
| Shardling | Small angular creature; approaches and performs a short melee lunge | Sidestep the wind-up or dash through a gap |
| Channeler | Tall, narrow floating construct; maintains distance and fires aimed bolts | Keep moving, use clear projectile paths, interrupt with damage |
| Bulwark | Broad armored construct; slow approach and directional ground slam | Move outside its marked sector; exploit long recovery |
| Tempest Warden | Large articulated guardian with exposed storm core | Learn alternating attacks and punish readable recovery windows |

The guardian appears in encounter 6. Phase one alternates a directional slam and
projectile fan. At 50% health, armor opens with a clear transition and phase two adds
expanding pulse rings and a small supporting wave. Phase change cannot cause an
unavoidable instant hit. Preserve a safe route through each attack pattern.

Regular enemy death combines directional recoil, armor fragments and rapid visual
cleanup. Bodies and effects stop damaging the player when dead. Navigation must
handle the arena boundary and other actors without indefinite wall pushing or
enemies spawning inside the player. Telegraph spawn locations before actors activate.

## 8. Art, animation and reactive environment

Use **Obsidian Circuit** as the baseline: dark faceted stone, sparse brass inlays,
ivory caster, cyan/white player magic, coral hostile telegraphs. This selection is a
PRD design default, informed by the references, and remains changeable by the user.

Reference boards:

- [Storm Lance](spell-references/storm-lance.png)
- [Storm Crown](spell-references/storm-crown.png)
- [Cataclysm](spell-references/cataclysm.png)

The boards define visual hierarchy, form and response. They are not game screenshots
or a requirement to reproduce every decorative detail. Static reference quality is
insufficient: the corresponding moving spell must look convincing at gameplay scale.

### Mandatory visual qualities

- The caster has an intentional hood/cloak/staff silhouette, articulated casting
  gestures, a readable run cycle, directional leaning and dash follow-through.
- Staff effects originate from the staff attachment throughout motion and turning.
- Enemies move through jointed poses or coherent whole-body animation; translation
  of a frozen model alone is insufficient.
- The arena has a composed floor, perimeter architecture, elevation outside combat
  space and contact shadows. Decorative surfaces must not obscure telegraphs.
- Spell flashes illuminate nearby surfaces. Impact debris, dust and transient scars
  originate at real hit positions and respond in the appropriate direction.
- Brightness has peaks and recovery. Preserve dark gaps around major effects and
  a visible player silhouette during Cataclysm and crowded Crown volleys.
- Cap and recycle transient debris, marks, trails and lights. Effects must fade
  smoothly rather than linger forever or disappear conspicuously at arbitrary times.

Use procedural geometry and animation where they serve this quality bar. Share
materials and reusable geometry. Prefer silhouette, timing and layered effects
over accumulating decorative nodes. Implementation technique does not excuse poor art.

## 9. Sound and impact

Provide distinct charge, release, travel/orbit, impact and decay layers for the
three spells. Crown's launches need audible rhythm; Cataclysm needs a clear lead-in,
low impact body and shorter high-frequency crack. Mix multiple hits without clipping.

Provide footsteps or cloth movement, dash, enemy anticipation, enemy hits/deaths,
upgrade confirmation, victory/defeat and restrained arena ambience. Original
procedural audio is acceptable if it produces cohesive results. Document provenance
for any external assets. Master, effects and ambience levels are adjustable and persist.

Brief camera impulses and optional hit-stop reinforce heavy impacts. They must not
stack into long freezes or interfere with menu input, cooldown accounting or pause.
Offer reduced flash, reduced particles and zero shake settings. Use shape and motion
alongside color to distinguish danger.

## 10. Interface and game states

Required states: title, active encounter, upgrade choice, paused, victory, defeat,
and spell laboratory. State changes clear or suspend incompatible input and timers.

The title screen offers Start Run, Spell Laboratory, Settings and Quit. HUD shows
health, encounter number, remaining enemies, Crown cooldown, Cataclysm charge and
three modifier slots. Spell names and input hints are readable without opening a guide.

Show unavailable-cast feedback near its HUD control without spamming messages.
Upgrade cards explain behavior in plain language and distinguish compatible spells.
Pause offers Resume, Restart, Settings and Return to Title. Restart begins a clean
run. Confirm abandoning an active run when returning to title or restarting.

Store audio/accessibility preferences and a best-run summary locally. Saving an
in-progress run is not required. A missing or invalid save file falls back to defaults
without preventing play. Provide immediate feedback when a preference changes.

### Spell laboratory

A separate selectable mode uses the same spells, enemies, arena materials and hit
logic as the main game. Let the player select any three modifiers, refill health
and Cataclysm charge, and reset a group of target enemies. Show concise descriptions
of the selected build. This is a polished experimentation space, not a debug console.
Returning to the title clears the laboratory state. Laboratory results do not update
best-run records.

## 11. Technical requirements

- Godot 4.7.2 is the verified local engine. Preserve any user-created root project
  settings; assess renderer requirements before modifying them.
- Use the root game project for production scenes; retain `dev/playground` as the
  independent development calibration project.
- Keep simulation, reusable model construction, visual effects, audio and UI separate
  enough to change one without rewriting unrelated systems.
- Use named input actions, fixed physics ticks for movement, explicit spell events
  and seeded scenario setup for reproducible tests.
- Use local version-matched API documentation when signatures are uncertain.
- Provide development-only scenario selection, seed selection, bounded input replay,
  JSON state output and viewport capture. These hooks must exercise actual game logic.
- Root project import, gameplay runs and supported scenarios must produce no script,
  shader, missing-resource or invalid-node errors.
- No external service or network connection is required to play.

### Performance target

Target 60 FPS at 1920×1080 on the verified Apple M5 Pro development machine, using
a documented renderer and quality setting. Measure a 60-second populated encounter
after warm-up with approximately 24 regular enemies, an active Crown, Lance casting
and at least two Cataclysm detonations. The guardian encounter requires a separate run.

Record frame-time median and 95th percentile; target p95 at or below 20 ms. Report
spikes and their cause rather than concealing them in an average. Also verify 1280×720
layout. A sparse scene, headless run or fixed-FPS recording is not performance evidence.
If the target is missed, profile and improve the bottleneck while retaining spell
identity. Performance shortfalls remain open acceptance issues.

## 12. Implementation sequence

These are internal milestones within the full release scope, not alternate definitions
of completion and not additional approval gates.

1. **Representative spell interaction:** camera, caster pose, finished Lance layers,
   one reacting enemy, local arena lighting and sound. Inspect motion before multiplying effects.
2. **Complete spell language:** Crown and Cataclysm, their full animation/audio phases,
   bounded damage rules, cooldown/charge and development scenarios.
3. **Composition and enemy variety:** all eight modifiers, three slots, upgrade UI,
   all regular enemies and the required interaction combinations.
4. **Complete run:** six encounters, two-phase guardian, win/lose/restart, settings,
   persistence and spell laboratory.
5. **Polish and acceptance:** dense-combat readability, performance, lifecycle cleanup,
   audio mix, resizing, complete manual run and evidence against every gate below.

## 13. Acceptance gates

| ID | Requirement | Evidence required |
| --- | --- | --- |
| A01 | Clean startup and accessible controls | Root import log; launch from title; first-time control walkthrough |
| A02 | Responsive movement, aim, dash and camera | Manual play plus input replay; boundary and stationary-dash cases |
| A03 | All three spells meet their distinct visual roles | In-engine motion sequences showing charge, action, impact and decay for each, including misses |
| A04 | Spell rules match damage | State assertions for reach, cooldown, charge spending, damage timing and per-victim hit limits |
| A05 | Eight modifiers and three-slot replacement work | Equip/remove/replace checks; recordings of the three required combinations |
| A06 | Effects terminate and remain bounded | Dense combination stress test; child limits and stable node/resource counts after cleanup |
| A07 | Enemy attacks and reactions are coherent | Every archetype's full state cycle; damage aligned to telegraphs; safe counterplay observed |
| A08 | Guardian has two functional phases | Phase-transition and attack-pattern replay plus a manual defeat of the guardian |
| A09 | Full run is playable end to end | A normal six-encounter victory run; separate defeat and clean restart; no progression bypass used as sole evidence |
| A10 | Menus, pause and focus transitions are sound | Upgrade input isolation, pause during effects, focus loss/return, abandon confirmation and title return |
| A11 | Settings and best-run persistence work | Relaunch verification, corrupt/missing-save handling, lab excluded from records |
| A12 | Laboratory uses the real spell systems | Three-form testing, modifier selection, target reset and return-to-title checks |
| A13 | Visual and audio coherence | Gameplay-scale inspection of crowded spell overlap, moving attachment points, recoil, environmental response and complete sound layers |
| A14 | Performance and layout meet targets | Specified populated and guardian frame-time reports; inspected 720p and 1080p captures |
| A15 | Delivery is reproducible | Run instructions, input guide, scenario commands, asset provenance and evidence index |

Behavioral tests complement visual inspection; neither substitutes for the other.
A green startup test cannot establish A03, A09 or A13. A staged spell screenshot
cannot establish fluid animation, progression or performance. Mark any unmet gate
explicitly and continue addressing it before declaring the game complete.

## 14. Deliverables

Deliver a runnable Godot project with the complete scope above; concise launch and
controls documentation; a player-visible title screen; and an evidence index mapping
A01–A15 to logs, scenarios, screenshots, motion sequences and performance results.
Store review evidence under `outputs/` and disposable captures under `work/`.

Finish with a clear account of what is playable, how to launch it and any remaining
acceptance failures. Do not present a calibration scene, isolated VFX demo or partial
wave prototype as the completed game.
