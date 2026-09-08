---
name: godot-development
description: Develop and verify Godot scenes, GDScript, shaders, resource imports, and gameplay changes in this repository using the local engine and diagnostic tools.
---

# Godot development

Read the repository `AGENTS.md` for current authorization. User instructions take
precedence over this skill. Read `docs/godot/development.md` when running the engine,
looking up API signatures, or using the diagnostic playground.

## Establish the target

Run `python3 tools/godot_dev.py doctor`. Read the target `project.godot` and relevant
scenes before editing. Use the actual project's renderer and Input Map; the separate
playground's configuration is a diagnostic baseline, not the game's design.
For uncertain APIs, search the class XML in `work/godot-api/` or consult the
version-matched official manual linked from the development guide.

## Implement a playable increment

Follow the project's existing scene ownership and conventions. Prefer reusable
scenes for entities and Resources for shared configuration where appropriate.
Keep per-instance mutable state outside shared Resources unless sharing is intended.
Make dependencies between scenes explicit; check node paths, resource references,
signal connections, and ready order when changing scene composition.

For physics-driven actors use physics ticks and the appropriate body API. For input,
use named actions so manual play and scripted scenarios exercise the same behavior.
For shaders and effects, check support in the project's selected renderer before
committing to a visual technique. Keep gameplay collision and danger readable.

For composable spells, make event order, ownership, and trigger limits explicit.
Test the combinations whose interactions changed, including simultaneous effects
and bounded child spawning. Add these systems only when included in approved scope.

## Verify the changed behavior

Import the target project, then run the affected scene. Use the runner's logs;
engine exit code alone can miss script failures. A startup smoke proves startup,
not the user's requested gameplay. Exercise the changed outcome and relevant
failure/restart paths using repeatable input and observable state where practical.

For visual changes, capture the actual rendered viewport and inspect it at gameplay
scale. Assess framing, silhouettes, UI readability, occlusion, and effect timing.
Headless runs cannot verify shaders, lighting, animation appearance, or game feel.
An external editor or a manually opened window is not automatically agent-visible.

The supplied replay and capture hooks operate only in `dev/playground`. When adding
game hooks, keep them development-only and expose a small set of commands for the
needed scenarios (load seed, spawn fixture, replay input, capture, read state).
Avoid making a general remote-control server without a demonstrated need.

Stop iterating when the requested behavior and appropriate checks pass. Report the
scene exercised, evidence paths, and any limits on verification. Update guidance
only for a recurring, demonstrated project-specific issue, keeping its rule in one
place rather than accumulating generic instructions.
