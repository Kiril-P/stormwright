# Godot development kit

## Engine and commands

The local binary and exact version are recorded in `tools/godot.local.json`.
`GODOT_BIN` can override the executable location; a changed version requires review.
Run commands from the repository root with Python 3.9 or newer. No pip/npm packages
or Godot addons are required.

```sh
python3 tools/godot_dev.py doctor
python3 tools/godot_dev.py playground-test
python3 tools/godot_dev.py playground-capture
python3 tools/godot_dev.py playground
python3 tools/godot_dev.py api
```

`playground` opens a separate diagnostic window: WASD moves the mint cube, R
resets it, F12 writes a screenshot and telemetry, Escape closes the window.
The automatic replay drives the same Input actions as keyboard control, moves into
a collision wall, reverses, resets, asserts the results, then exits. This is a
fixed-step input replay, not a guarantee of cross-platform physics determinism.
`playground-capture` also saves the rendered viewport after `frame_post_draw`.
Its renderer is Compatibility, chosen for a portable diagnostic baseline.

Each run gets a fresh `work/runs/` folder with exact argument arrays, engine logs,
console logs, and (for the playground) JSON state. `--output` chooses another
directory. The runner checks engine errors as well as exit status. Automatic
playground runs require an explicit successful `DEV_RESULT` record.

After game implementation is approved and the root project has scenes:

```sh
python3 tools/godot_dev.py import
python3 tools/godot_dev.py smoke --scene res://path/to/scene.tscn
```

These are import/startup checks; they do not establish playability or graphics
correctness. Use rendered runs and targeted gameplay assertions for those claims.
The existing capture/input adapter belongs to the diagnostic project; integrate
equivalent hooks into the actual game only during approved implementation.

## Documentation lookup

The installed engine reports **4.7.2.stable.official.ed1daf0bf**. The 4.7 manuals
were verified during setup on 2026-09-08. Prefer exact local API signatures over
memory and use the versioned manuals for explanation:

- [Command line](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)
- [GDScript](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html)
- [Scene organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/scene_organization.html)

API XML for 1,076 classes is generated directly from the installed executable in
`work/godot-api/`. It provides exact signatures, properties, constants and defaults;
this build's dump has empty prose descriptions. Use the online manual for explanations.
This is a regenerable local cache, not an always-loaded skill attachment.
Find a class file before reading it:

```sh
rg --files work/godot-api | rg '/(CharacterBody3D|Input|Viewport|Resource)\.xml$'
rg -n 'move_and_slide|frame_post_draw|parse_input_event' work/godot-api
```

`python3 tools/godot_dev.py api` refreshes the cache. Use `--help` from the exact
binary to check CLI support. Never treat `--check-only` as a whole-project test;
it applies to the selected script with `--script`.

## Development boundaries

This kit has no network server or new third-party integration. Automated inputs
are injected inside the diagnostic application. User OS keyboard control and
editor scene-tree inspection are separate capabilities, not implied by this kit.
Rendering checks use the actual Godot viewport. Performance counters from a short
fixed-FPS calibration run are diagnostic values, not a game performance benchmark.

On macOS, Godot also writes normal editor settings, cache and `user://` data under
the user's Library. The preparation runs required execution outside the filesystem
sandbox for these writes and native rendering. Future restricted sessions may need
the same execution permission. The wrapper does not bypass sandbox restrictions.
