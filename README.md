# Stormwright

**[Play in your browser](https://stormwright-one.vercel.app)** · [Public source](https://github.com/Kiril-P/stormwright)

A single-player spellcraft arena built in Godot. Fight through the Obsidian Circuit,
reshape three storm spells with eight modifiers, and confront the two-phase Tempest
Warden. The Spell Laboratory lets you experiment with any three modifiers immediately.

[Watch the 25-second spell showcase](outputs/gameplay/spell-showcase.mp4) for actual
Godot spell footage with sound. It is a staged laboratory recording at native
720p/60 FPS; [media QA](outputs/gameplay/spell-showcase-qa.md) documents its scope.

## Play

Open `project.godot` in **Godot 4.7.2** and press **F5**. Choose **Enter the Circuit**
for a run, or **Spell Laboratory** to experiment. No external service is needed to play.

From a terminal at the repository root, the included runner finds the configured
Godot executable, imports resources, and launches the game:

```sh
python3 tools/godot_dev.py doctor
python3 tools/godot_dev.py play
```

The runner requires Python 3.9 or newer. If it cannot locate Godot, set `GODOT_BIN`
to the engine executable. The local engine configuration is `tools/godot.local.json`.
Use `play --resolution 1920x1080` for a larger window.

| Input | Action |
| --- | --- |
| WASD or arrow keys | Move |
| Mouse position | Aim |
| Hold left mouse | Repeat **Storm Lance** |
| Right mouse | Summon **Storm Crown** |
| Q | Unleash **Cataclysm** when its charge reaches 100% |
| Space | Dash in your movement direction; toward your aim when stationary |
| Escape | Pause/resume; close settings or an abandon confirmation |

Lance is your repeatable aimed strike. Crown gathers a moving constellation and
launches it in sequence. Successful direct hits build Cataclysm charge; its marked
area erupts after a short wind-up. Keep moving during casts and leave coral enemy
telegraphs before they resolve.

Six encounters introduce melee, ranged, and armored enemies before the Warden.
Shardlings rush and flank; Channelers circle and retreat between aimed bolts.
Bulwarks close faster, commit to a directional slam, then expose a brighter core
and open shoulders: punish that recovery for 50% extra damage. Basic Lance takes
two hits against Shardlings/Channelers and four against a Bulwark before bonuses.
[Watch the updated enemies](outputs/gameplay/enemy-showcase.mp4) in a staged
27-second production-AI review with normal health and readable sidestep windows.
Between encounters, choose one of three modifier cards or keep your current build.
You have three slots; a replacement card previews the resulting build. Encounter
completion restores up to 25 health and preserves Cataclysm charge.

In the laboratory, click a law to equip or remove it. **Refill Health & Charge**
restores your resources; **Reset Targets** clears the previous spell experiment and
spawns fresh targets while retaining your build. Laboratory results do not count
toward the best-run record.

Pause offers resume, restart, settings, and return to title. Restarting or leaving
an active run requires confirmation. Audio levels, camera shake, reduced flash,
and reduced particles are saved locally, alongside the fastest victorious run.
Runs themselves are not saved. Losing window focus pauses combat; release held
attack buttons after resuming before casting again.

## Browser deployment

The public browser build runs on Vercel at **https://stormwright-one.vercel.app**.
Use a desktop browser with WebGL 2 and a keyboard/mouse. Mobile touch controls
are not implemented. Browser rendering uses Compatibility; desktop retains
Forward+. Lighting and post-processing can therefore look different.
Browser-local preferences require persistent site storage.

`vercel.json` runs `python3 tools/build_web.py` and serves `build/web`. The build
script pins Godot 4.7.2, verifies official archive SHA256 checksums, imports resources,
and exports the Web preset. On Linux x86_64 it downloads the engine if absent.
Locally, pass `--godot /path/to/Godot` or set `GODOT_BIN`. Generated exports, build
caches, Vercel credentials and environment files are ignored by Git.

```sh
python3 tools/build_web.py --godot /path/to/Godot
python3 -m http.server 8765 --directory build/web
# Publish from an authenticated Vercel CLI:
npx vercel --prod
```

## Development and verification

The root project uses Forward+ with Metal on macOS, a 1600×900 UI canvas, and
60 Hz physics. The independent diagnostic project remains in `dev/playground`.
Read `docs/godot/development.md` for engine commands and the local API reference;
the full design and acceptance gates are in `outputs/SPELL_ARENA_PRD.md`.

```sh
python3 tools/godot_dev.py import
python3 tools/godot_dev.py smoke --scene res://scenes/main.tscn
python3 tools/godot_dev.py playground-test
```

Import and smoke checks establish resource loading and startup. They do not verify
spell appearance, control feel, a completed run, or frame-time performance.

The production game includes bounded, seeded scenarios. Supported names are
`lance`, `crown`, `cataclysm`, `combinations`, `flow`, `run`, `boss`, `performance`,
and `boss_performance`.
The runner saves exact command arguments, engine logs, console logs, JSON results,
and selected viewport captures when rendered. Scenario saves are isolated inside
their output directories.

```sh
python3 tools/godot_dev.py scenario --scenario lance --seed 73 --output work/replay/lance
python3 tools/godot_dev.py scenario --scenario crown --rendered --resolution 1280x720 --output work/replay/crown
python3 tools/godot_dev.py scenario --scenario cataclysm --rendered --resolution 1920x1080 --output work/replay/cataclysm
python3 tools/godot_dev.py scenario --scenario combinations --rendered --output work/replay/combinations
python3 tools/godot_dev.py scenario --scenario run --timeout 1200 --output work/replay/run
```

Default scenarios use fixed 60 FPS simulation for repeatability. Their timings are
**not performance measurements**. Headless scenarios cannot assess rendering or
audio. Selected screenshots document individual moments; fluid animation requires
watching the rendered game or reviewing a motion recording. The run scenario uses
an automated player and complements manual play.

Record a rendered scenario as an AVI with `--movie`:

```sh
python3 tools/godot_dev.py scenario --scenario cataclysm --rendered --movie work/replay/cataclysm.avi --output work/replay/cataclysm-motion
```

Movie recording uses fixed 60 FPS. It cannot be combined with `--realtime` or used
as performance evidence. Repeat with `lance`, `crown`, or `combinations` to record
their motions and sound.

For real-time frame sampling, both `--rendered` and `--realtime` are required:

```sh
python3 tools/godot_dev.py scenario --scenario performance --rendered --realtime --resolution 1920x1080 --timeout 120 --output work/benchmark/populated
python3 tools/godot_dev.py scenario --scenario boss_performance --rendered --realtime --resolution 1920x1080 --timeout 120 --output work/benchmark/guardian
```

The populated benchmark keeps 24 enemies alive, casts Lance and Crown, and triggers
multiple Cataclysms during a 65-second run. Monotonic wall-clock samples after the
first five seconds report median, p95, p99, maximum, and frames above 20 ms. The
separate guardian benchmark holds the boss alive and transitions between phases
to measure both; use `boss` for the functional defeat scenario. The runner requires
rendered real-time mode for both benchmark scenarios and rejects movie recording.
Check the
actual image dimensions, hardware, quality settings, result, and logs before citing
a performance result. A successful scenario exit alone does not prove that the
PRD's p95 target or visual quality gates are met.

`game/flow_checks.gd` exercises upgrade selection/replacement/skip, input isolation,
pause, focus notifications, confirmations, clean restart, laboratory cleanup,
preferences, best-run persistence, and malformed/missing saves. Its result fixtures
test transitions; they do not establish a normal combat victory or OS-driven focus
behavior. Run it with a disposable save under `work/flow-checks`:

```sh
mkdir -p work/flow-checks
STORM_GODOT="$(python3 -c 'from tools.godot_dev import binary; print(binary()[0])')"
"$STORM_GODOT" --headless --path . --log-file "$PWD/work/flow-checks/engine.log" \
  --script game/flow_checks.gd -- --save="$PWD/work/flow-checks/check-save.json"
```

Review `work/flow-checks/result.json` together with `engine.log`. The harness refuses
save paths outside its disposable directory. For the separate spell damage,
composition and cleanup fixtures:

```sh
mkdir -p work/spell-checks
"$STORM_GODOT" --headless --path . --log-file "$PWD/work/spell-checks/engine.log" \
  --script game/spell_checks.gd
```

These fixed fixtures report to `work/spell-checks/result.json` and use a disposable
preferences file there. Keep scratch recordings and logs in
`work/`; collect reviewed delivery evidence under `outputs/`. Full acceptance
requires the separate evidence described by PRD gates A01–A15.

Enemy telegraph/damage fixtures and repeated resource cleanup are independent:

```sh
mkdir -p work/enemy-checks work/lifecycle-checks
"$STORM_GODOT" --headless --path . --log-file "$PWD/work/enemy-checks/engine.log" \
  --script game/enemy_checks.gd
"$STORM_GODOT" --headless --path . --log-file "$PWD/work/lifecycle-checks/engine.log" \
  --script game/lifecycle_checks.gd
```

Their result JSON files are saved beside those logs. Lifecycle checks warm the actual
actor/FX caches, then compare three heavy cast/death/reset cycles using Godot
resource/node monitors and sampled procedural resource weak references. Headless
mode verifies allocated audio resources; rendered audio mixing is separate.

For native observation without a scenario or automated player, launch
`game/manual_review.gd` using the same executable variable:

```sh
"$STORM_GODOT" --path . --windowed --resolution 1280x720 --script game/manual_review.gd \
  -- --output="$PWD/work/manual-review" --save="$PWD/work/manual-review/save.json"
```

F12 saves the actual viewport and aim/projection diagnostics; F11 flushes the session
log. Actual input, UI actions, focus changes, and state samples are recorded for up
to 30 minutes, with a final flush on exit. It does not control the game. Current
review status and evidence limits are in [the acceptance index](outputs/ACCEPTANCE.md).
Selected [guardian counterplay images and command records](outputs/verification/guided-guardian/summary.json)
document a normal-stat, agent-directed guardian victory. That encounter-only fixture
is separate from human/native play. The [rendered normal six-encounter run](outputs/verification/full-run-rendered/result.json)
records a complete victory with five upgrade screens and six combat captures.
Final [dense](outputs/verification/dense-final/result.json) and
[guardian](outputs/verification/guardian-performance/result.json) benchmarks report
p95 10.199 ms and 10.036 ms on the verified development machine. These benchmark numbers precede the final enemy tuning. The
[handoff notes](outputs/HANDOFF.md) identify current verification and review limits.

## Assets and provenance

Arena geometry, character rigs and animation, spell meshes, effects, materials, and
UI sigils are original procedural work in this project. UI text uses installed
system fonts with fallbacks; no font files are bundled. Every runtime WAV is
original synthesis generated by `tools/generate_storm_audio.py`; details and the
regeneration command are in `assets/audio/PROVENANCE.md`.

The images under `outputs/spell-references` are AI-generated concept references.
They guide visual direction and are not runtime graphics or evidence of the game's
rendered quality. No third-party asset pack or network dependency is required.
