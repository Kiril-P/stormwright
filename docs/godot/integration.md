# Initial integration contracts

Root simulation: `game/arena_game.gd`. Coordinates are XZ ground, Y up; arena radius
12, camera roughly (0,22,18), orthographic size 29. Agents own their assigned files.
Root may refine integration after handoff. Avoid cross-file class-name dependencies;
use preload and dynamic Node/Dictionary interfaces where appropriate.

## WorldArt (`game/world_art.gd`, extends Node3D)

- `build_arena()` constructs floor, perimeter, lights, environment. Root adds camera.
- `create_caster() -> Dictionary`: keys root (Node3D), staff_tip (Node3D), remaining
  rig data private. Root changes root position and yaw.
- `create_enemy(kind: String) -> Dictionary`: kinds shardling/channeler/bulwark/warden;
  key root (Node3D). Root adds it to the scene and controls position/yaw.
- `animate_caster(rig, time, speed, cast, dash)` where normalized cast/dash 0..1.
- `animate_enemy(rig, time, speed, attack, hit, phase)` normalized attack/hit; phase 1/2.
- Returned actors are NOT parented; root owns parenting and destruction.
- Arena setup may create WorldEnvironment/lighting but no camera, UI or gameplay.

## SpellFX (`game/spell_fx.gd`, extends Node3D)

- `beam(start: Vector3, end: Vector3, power: float = 1.0)` layered jagged lance.
- `burst(at: Vector3, power: float = 1.0, hostile: bool = false)` impact/debris/flash.
- `ring(at: Vector3, radius: float, duration: float, hostile: bool = false)` ground ring.
- `charge(at: Vector3, power: float = 1.0)` anticipation.
- `trail(start: Vector3, end: Vector3, hostile: bool = false)` projectile motion.
- `shard(at: Vector3, direction: Vector3, scale_value: float = 1.0) -> Node3D`
  returns UNPARENTED persistent crown shard root. Root parents/moves/frees it.
- `cataclysm(at: Vector3, power: float = 1.0)` large timed detonation.
- `set_quality(reduced_particles: bool, reduced_flash: bool)`
- `clear_all()` clears transient effects. Process uses delta and respects tree pause.
- Effects budget bounded; no damage logic. Marks/tells may be visual ring calls.

## GameAudio (`game/game_audio.gd`, extends Node)

- `play_sound(id: String, intensity: float = 1.0)`: lance_charge/lance/crown/crown_fire/
  cataclysm_charge/cataclysm/hit/death/dash/step/enemy_charge/enemy_attack/upgrade/victory/defeat.
- `set_levels(master: float, effects: float, ambience: float)` values 0..1.
- `start_ambience()`; sound generation offline or at load, not per frame.

## GameUI (`game/game_ui.gd`, extends CanvasLayer)

- `signal action(name: String, payload: Variant)`; root connects to dispatch.
- `show_screen(screen: String, data: Dictionary = {})` screens title/hud/upgrade/pause/
  settings/victory/defeat/lab/confirm. Unknown keys tolerated.
- `update_hud(data: Dictionary)` fields health/max_health, wave, enemy_count,
  crown_cd, charge (0..100), modifiers (Array[String]), elapsed, boss_health,
  boss_max_health, boss_phase, lab (bool), banner (String).
- `notify(text: String)` brief nonblocking status.
- `set_modifier_catalog(catalog: Array[Dictionary])` each id/name/description/spells.
- screen data: choices (array of IDs), modifiers (array IDs), settings (Dictionary),
  elapsed/kills/best for results; confirm_text for confirm; replace_id for upgrade.
- actions start/lab/settings/quit/resume/restart/title/choose_modifier (ID)/
  replace_modifier (slot int)/skip/lab_modifier (ID)/lab_refill/lab_reset/
  setting ({key,value})/back/confirm/cancel.
- Settings keys master/effects/ambience/shake (floats0..1), reduced_flash and
  reduced_particles (bool). UI keeps working while tree paused, inputs consumed.
- Settings/best persistence belongs to root. Interface is scalable, stylish, player-facing.
