# Stormwright — delivery verification

Updated 2026-09-08 after the user's enemy feedback. Implementation and the requested
focused enemy pass are complete. The user requested a quick handoff and accepted
the other systems; optional remaining review is explicitly deferred below.

## Current enemy build

- **21 enemy checks pass:** directional warnings/damage, lunge endpoints, interruption,
  stagger, attack retirement, phase transitions, traveling hazards, two-hit Shardlings,
  vulnerable Bulwark recovery, Channeler strafing and Shardling flanking.
  [Result](verification/enemy-final/enemy-checks.json), [log](verification/enemy-final/enemy-checks.log).
- **32 spell checks pass** after the tuning. [Result](verification/enemy-final/spell-checks.json),
  [log](verification/enemy-final/spell-checks.log).
- **All three regular enemy cycles recorded:** normal health and production AI,
  staged initial positions, reactive sidestep inputs, then aim-assisted Lance/Crown.
  Spawn, approach, wind-up, attack/recovery and death were observed in state records
  and rendered phase captures. All three sidesteps retain 100 health.
  [27-second clip](gameplay/enemy-showcase.mp4), [inspected contact sheet](gameplay/enemy-contact-sheet.jpg),
  [state records](verification/enemy-final/motion.json), [clean render log](verification/enemy-final/motion-engine.log).
  This is an agent-controlled fixture, not a human playtest.
- **New rendered full run passes:** six encounters, five upgrade transitions,
  guardian phase two and victory under normal combat rules.
  [Result](verification/enemy-final/full-run/result.json),
  [clean engine log](verification/enemy-final/full-run/scenario-engine.log),
  [wave-five capture](verification/enemy-final/full-run/wave-05-combat.png).
  Fixed-FPS replay is functional evidence, not a performance measurement.
- [Source fingerprints](verification/enemy-final/source-sha256.json) identify the delivered scripts and scenes.

## Earlier verified systems and limits

The [earlier detailed evidence index](ACCEPTANCE-PRE-ENEMY-TUNING.md) preserves the
72 menu/persistence/flow checks, 20 lifecycle checks, native aiming/focus observations,
spell recordings, layouts and directed guardian review. Those historical health,
run-time and enemy timing values precede the final tuning and are not current balance claims.
No spells, modifiers, encounters, menus or laboratory features were removed.

Earlier real-time 1080p dense/guardian benchmarks passed with p95 10.199/10.036 ms.
They precede this enemy tuning; no fresh performance claim is made from the fixed-FPS
run. Dense-spike attribution and the extra boundary/stationary-dash/menu walkthrough
are deferred for the requested quick handoff. Existing controls and menu evidence is
retained; these omitted checks are not claimed as passes. Human difficulty, enjoyment
and the original 10–15 minute first-time pacing aspiration remain unmeasured.

See [handoff](HANDOFF.md) and [launch instructions](../README.md).
