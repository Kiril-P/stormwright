# Spell game workspace

The user approved game implementation on 2026-09-08; see
`docs/review/approval.md` for the exact instruction and current specification status.
Build against `outputs/SPELL_ARENA_PRD.md`. Preserve its full scope and acceptance
gates rather than treating the preliminary setup proposal as the specification.

For Godot code, scenes, shaders, imports, or runtime debugging, read
`.agents/skills/godot-development/SKILL.md` before working. For execution commands
and local API lookup, read `docs/godot/development.md`.

Preserve the user's root `project.godot` and editor-created files. The diagnostic
project lives at `dev/playground`; `dev/.gdignore` keeps it outside root imports.
Use `work/` for disposable logs and API caches; review artifacts live in `outputs/`.

Use `kp/` as the branch prefix for pull requests.
