#!/usr/bin/env python3
"""Godot development runner. Uses only Python's standard library."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"(?:SCRIPT ERROR:|Shader compilation failed|^\s*ERROR:)", re.M)


def binary():
    config_path = ROOT / "tools/godot.local.json"
    config = json.loads(config_path.read_text()) if config_path.exists() else {}
    candidates = [os.environ.get("GODOT_BIN"), config.get("binary"), shutil.which("godot"),
                  "/Applications/Godot.app/Contents/MacOS/Godot",
                  str(Path.home() / "Downloads/Godot.app/Contents/MacOS/Godot")]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate, config.get("expected_version")
    raise RuntimeError("Godot not found. Set GODOT_BIN to its executable or update tools/godot.local.json.")


def execute(engine, arguments, output, name, timeout=60):
    command = [engine, "--log-file", str(output / (name + "-engine.log")), *arguments]
    (output / (name + "-command.json")).write_text(json.dumps(command, indent=2) + "\n")
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raw = error.stdout or b""
        text = raw.decode(errors="replace") if isinstance(raw, bytes) else raw
        (output / (name + ".log")).write_text(text)
        raise RuntimeError(f"{name} timed out after {timeout}s; see {output}") from error
    (output / (name + ".log")).write_text(result.stdout)
    print(result.stdout, end="")
    if result.returncode or ERROR.search(result.stdout):
        raise RuntimeError(f"{name} failed (exit {result.returncode}); see {output}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["doctor", "import", "smoke", "playground-test", "playground-capture", "playground", "api", "scenario", "play"])
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--scene", help="Project-relative scene, e.g. res://scenes/main.tscn")
    parser.add_argument("--seed", type=int, default=73)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--scenario", default="lance")
    parser.add_argument("--rendered", action="store_true")
    parser.add_argument("--realtime", action="store_true", help="Do not force fixed FPS; required for performance measurements")
    parser.add_argument("--resolution", default="1280x720")
    parser.add_argument("--movie", type=Path, help="Record a rendered scenario as AVI (fixed 60 FPS; not a performance measurement)")
    args = parser.parse_args()
    if args.command == "scenario" and args.scenario in ("performance", "boss_performance"):
        if not args.rendered or not args.realtime or args.movie:
            parser.error("Performance scenarios require --rendered --realtime and cannot record a movie")
    if args.movie and (args.command != "scenario" or not args.rendered or args.realtime):
        parser.error("--movie requires a rendered fixed-FPS scenario")
    engine, expected = binary()
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if args.command == "doctor":
        print(json.dumps({"binary": engine, "version": version,
                          "expected_version": expected, "version_matches": expected == version,
                          "root_project_exists": (ROOT / "project.godot").exists(),
                          "playground_exists": (ROOT / "dev/playground/project.godot").exists()}, indent=2))
        return
    if expected and expected != version:
        raise RuntimeError(f"Engine changed from {expected} to {version}; review documentation and update the local config.")
    output = args.output or ROOT / "work/runs" / datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    print("Evidence: " + str(output))
    if args.command == "api":
        destination = ROOT / "work/godot-api"
        destination.mkdir(parents=True, exist_ok=True)
        execute(engine, ["--headless", "--doctool", str(destination)], output, "api", args.timeout)
        print("API reference: " + str(destination))
        return
    playground = args.command.startswith("playground")
    project = ROOT / "dev/playground" if playground else args.project.resolve()
    if not (project / "project.godot").is_file():
        raise RuntimeError(f"No project.godot at {project}; the runner will not create one.")
    execute(engine, ["--headless", "--path", str(project), "--import"], output, "import", args.timeout)
    if args.command == "import":
        return
    if args.command in ("scenario", "play"):
        flags = ["--path", str(project)]
        if args.command == "play" or args.rendered:
            flags += ["--windowed", "--resolution", args.resolution]
        else:
            flags += ["--headless"]
        if args.command == "scenario":
            if not args.realtime:
                flags += ["--fixed-fps", "60"]
            if args.movie:
                movie = args.movie.resolve()
                movie.parent.mkdir(parents=True, exist_ok=True)
                flags += ["--write-movie", str(movie)]
            flags += ["--", "--scenario=" + args.scenario, "--output=" + str(output),
                      "--seed=" + str(args.seed), "--save=" + str(output / "test-save.json")]
        text = execute(engine, flags, output, args.command, args.timeout if args.command == "scenario" else None)
        if args.command == "scenario":
            results = [json.loads(line.removeprefix("SCENARIO_RESULT ")) for line in text.splitlines() if line.startswith("SCENARIO_RESULT ")]
            if len(results) != 1 or not results[0].get("passed"):
                raise RuntimeError("Scenario did not explicitly report success")
        return
    if playground:
        mode = {"playground-test": "test", "playground-capture": "capture", "playground": "interactive"}[args.command]
        flags = ["--headless"] if mode == "test" else ["--windowed", "--resolution", "1280x720"]
        if mode != "interactive":
            flags += ["--fixed-fps", "60"]
        arguments = [*flags, "--path", str(project), "--", "--mode=" + mode,
                     "--output=" + str(output), "--seed=" + str(args.seed)]
        text = execute(engine, arguments, output, mode, args.timeout if mode != "interactive" else None)
        if mode != "interactive":
            results = [json.loads(line.removeprefix("DEV_RESULT ")) for line in text.splitlines() if line.startswith("DEV_RESULT ")]
            if len(results) != 1 or not results[0].get("passed"):
                raise RuntimeError("Missing or failed DEV_RESULT: successful engine exit alone is insufficient.")
            if mode == "capture" and not (output / "playground.png").is_file():
                raise RuntimeError("Capture did not produce playground.png")
    else:
        flags = ["--headless", "--path", str(project), "--quit-after", "180"]
        if args.scene:
            flags += ["--scene", args.scene]
        execute(engine, flags, output, "smoke", args.timeout)
        print("Startup smoke passed. Gameplay and rendering require separate checks.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("FAILED: " + str(exc), file=sys.stderr)
        sys.exit(1)
