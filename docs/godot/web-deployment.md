# Public web deployment

Published 2026-09-08:

- Source: https://github.com/Kiril-P/stormwright (public, main branch).
- Game: https://stormwright-one.vercel.app (Vercel production).

Vercel builds the Godot project from source using `tools/build_web.py` and serves
`build/web`. The pinned 4.7.2 engine and export archives are checked against their
official SHA256 digests before extraction. Export includes all runtime scripts,
shaders and audio, while excluding diagnostic harnesses and review artifacts.

The browser target uses single-threaded WebAssembly and WebGL 2 Compatibility.
Desktop keeps Forward+. Desktop keyboard and mouse are required; no touch input
scheme is claimed. Browser storage controls whether preferences persist. The web
title omits Quit because closing a native process is not a useful browser action.

Verification: the Vercel Linux build completed successfully, the production URL
returned HTTP 200 without authentication, and Chromium WebGL reached GAME_READY
with a rendered title screen and no production console errors. Local browser
checks also entered the laboratory and exercised Crown and Cataclysm inputs.
This is a browser smoke review, not a new full-run browser performance benchmark.

Deploy again from an authenticated Vercel CLI with `npx vercel --prod`.
GitHub-to-Vercel automatic deployment is not enabled; the current deployment was
published explicitly. Any future integration requires approval for ongoing access.
