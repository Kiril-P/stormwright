#!/usr/bin/env python3
"""Export the pinned Godot game locally or on Vercel (Linux x86_64)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '4.7.2'
BASE = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/'
ARCHIVES = {
    'templates': (f'Godot_v{VERSION}-stable_export_templates.tpz', 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'),
    'linux': (f'Godot_v{VERSION}-stable_linux.x86_64.zip', 'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4'),
}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def archive(kind, cache, supplied=None):
    name, expected = ARCHIVES[kind]
    destination = Path(supplied).resolve() if supplied else cache / name
    if not destination.exists():
        if supplied:
            raise RuntimeError(f'Archive not found: {destination}')
        print(f'Downloading official {name}', flush=True)
        partial = destination.with_suffix(destination.suffix + '.partial')
        urllib.request.urlretrieve(BASE + name, partial)
        partial.replace(destination)
    if digest(destination) != expected:
        raise RuntimeError(f'SHA256 mismatch: {destination}')
    return destination


def run(command):
    print('Running:', ' '.join(map(str, command)), flush=True)
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, flush=True)
    if result.returncode or re.search(r'(?m)^(?:SCRIPT ERROR|ERROR):', result.stdout):
        raise RuntimeError('Godot command failed; inspect the output above')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN'))
    parser.add_argument('--templates-archive')
    args = parser.parse_args()
    cache = ROOT / 'work' / 'web-toolchain'
    cache.mkdir(parents=True, exist_ok=True)
    engine = args.godot or shutil.which('godot') or shutil.which('godot4')
    config = ROOT / 'tools' / 'godot.local.json'
    if not engine and config.exists():
        local = json.loads(config.read_text())
        candidate = local.get('binary')
        if candidate and Path(candidate).exists():
            engine = candidate
    if not engine:
        if platform.system() != 'Linux' or platform.machine() not in ('x86_64', 'AMD64'):
            raise RuntimeError('Install Godot 4.7.2 or set GODOT_BIN on this platform')
        binary_name = f'Godot_v{VERSION}-stable_linux.x86_64'
        engine = str(cache / binary_name)
        if not Path(engine).exists():
            with zipfile.ZipFile(archive('linux', cache)) as source:
                (cache / binary_name).write_bytes(source.read(binary_name))
            Path(engine).chmod(0o755)
    version = subprocess.check_output([engine, '--version'], text=True).strip()
    if not version.startswith(VERSION + '.stable.'):
        raise RuntimeError(f'Expected Godot {VERSION}.stable, got {version}')
    if platform.system() == 'Darwin':
        data = Path.home() / 'Library' / 'Application Support' / 'Godot'
    else:
        data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local' / 'share'))) / 'godot'
    templates = data / 'export_templates' / f'{VERSION}.stable'
    required = ['web_nothreads_release.zip', 'web_nothreads_debug.zip', 'version.txt']
    if not all((templates / name).exists() for name in required):
        templates.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive('templates', cache, args.templates_archive)) as source:
            for name in required:
                (templates / name).write_bytes(source.read('templates/' + name))
    output = ROOT / 'build' / 'web'
    output.mkdir(parents=True, exist_ok=True)
    run([engine, '--headless', '--path', str(ROOT), '--editor', '--import'])
    run([engine, '--headless', '--path', str(ROOT), '--export-release', 'Web', str(output / 'index.html')])
    for name in ['index.html', 'index.js', 'index.wasm', 'index.pck']:
        if not (output / name).is_file() or not (output / name).stat().st_size:
            raise RuntimeError(f'Missing exported artifact: {name}')
    print(f'Browser build ready: {output}', flush=True)


if __name__ == '__main__':
    main()
