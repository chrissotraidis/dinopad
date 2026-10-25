#!/usr/bin/env python3
"""Prepare only the pinned public sources needed by the base private module."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MODULES = ('lib/N64Recomp', 'lib/N64ModernRuntime', 'lib/dino-recomp-decomp-bridge', 'lib/rt64')
RECURSIVE = ('lib/N64Recomp',)
SHELL_MODULES = MODULES + ('lib/RmlUi', 'lib/SDL_GameControllerDB', 'lib/SlotMap', 'lib/lunasvg')
SHELL_RECURSIVE = RECURSIVE + ('lib/N64ModernRuntime', 'lib/rt64', 'lib/lunasvg')


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def revision(path):
    return subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()


def lock_entry(name='dino-recomp'):
    return next(item for item in json.loads((ROOT / 'dependencies.lock.json').read_text())['entries']
                if item['name'] == name)


def gitlinks(path):
    listing = subprocess.check_output(['git', '-C', str(path), 'ls-tree', '-r', 'HEAD'], text=True)
    return {name: head.split()[2] for head, name in (line.split('\t', 1) for line in listing.splitlines())
            if head.startswith('160000 ')}


def repositories(source, initialized_only=False, shell=False):
    entry = lock_entry()
    if revision(source) != entry['commit']:
        raise ValueError(f'Preserving source with a different revision: {source}')
    links = gitlinks(source)
    if any(links.get(name) != pin for name, pin in entry['submodules'].items()):
        raise ValueError('Source gitlinks differ from the reviewed dependency lock')
    result = [(source, entry['commit'])]

    def include(path, pin, recursive):
        if not (path / '.git').exists() and initialized_only:
            if path.is_symlink() or (path.exists() and any(path.iterdir())):
                raise ValueError(f'Preserving non-Git dependency folder: {path}')
            return
        if not (path / '.git').exists() or path.is_symlink() or revision(path) != pin:
            raise ValueError(f'Preserving missing or mismatched dependency: {path}')
        result.append((path, pin))
        if recursive:
            for child, expected in gitlinks(path).items():
                include(path / child, expected, True)

    for name in SHELL_MODULES if shell else MODULES:
        include(source / name, links[name], name in (SHELL_RECURSIVE if shell else RECURSIVE))
    bridge = source / 'lib/dino-recomp-decomp-bridge'
    if (bridge / '.git').exists():
        include(bridge / 'dinosaur-planet', gitlinks(bridge)['dinosaur-planet'], False)
    if shell:
        include(source.parent / 'SDL2', lock_entry('SDL2')['commit'], False)
    return result


def patch_stack(repos):
    return [f'{path}|{patch}' for path, _pin in repos
            for patch in sorted((ROOT / 'patches' / path.name).glob('*.patch'))]


def verify_contents(repos, stack):
    allowed = {}
    for item in stack:
        folder, patch = item.split('|', 1)
        names = re.findall(r'^(?:--- a/|\+\+\+ b/)([^\t\n]+)', Path(patch).read_text(), re.M)
        allowed.setdefault(Path(folder), set()).update(names)
    for path, _pin in repos:
        dirty = subprocess.check_output(['git', '-C', str(path), 'diff', 'HEAD', '--name-only',
            '--ignore-submodules=all'], text=True, env=dict(os.environ, GIT_OPTIONAL_LOCKS='0')).splitlines()
        unknown = set(dirty) - allowed.get(path, set())
        for name in tuple(unknown):
            file = path / name
            original = subprocess.check_output(['git', '-C', str(path), 'show', f'HEAD:{name}'])
            if file.is_file() and not file.is_symlink() and file.read_bytes().replace(b'\r\n', b'\n') == original.replace(b'\r\n', b'\n'):
                unknown.remove(name)
        extra = set(subprocess.check_output(['git', '-C', str(path), 'ls-files', '--others',
                                            '--exclude-standard'], text=True).splitlines())
        unknown.update(extra - allowed.get(path, set()))
        if unknown:
            raise ValueError(f'Preserving unexpected source changes in {path}: {sorted(unknown)[:10]}')


def replay(source, stack, verify_only):
    spec = importlib.util.spec_from_file_location('dino_patch_replay', ROOT / 'scripts/apply-module-patches.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.apply(source, stack, verify_only=verify_only)


def verify(source, initialized_only=False, verify_only=True, shell=False):
    source = Path(source).resolve()
    repos = repositories(source, initialized_only, shell)
    stack = patch_stack(repos)
    verify_contents(repos, stack)
    replay(source.parent if shell else source, stack, verify_only)
    return source


def clone_pinned(source, entry):
    if source.is_symlink():
        raise ValueError(f'Preserving source symlink: {source}')
    if not (source / '.git').exists():
        if source.exists() and any(source.iterdir()):
            raise ValueError(f'Preserving non-Git source folder: {source}')
        source.parent.mkdir(parents=True, exist_ok=True)
        run('git', 'clone', '--no-checkout', '-c', 'core.autocrlf=false', entry['url'], source)
        run('git', '-C', source, 'checkout', '--detach', entry['commit'])


def prepare(shell=False):
    source = ROOT / 'ref/dino-recomp'
    clone_pinned(source, lock_entry())
    if shell:
        clone_pinned(source.parent / 'SDL2', lock_entry('SDL2'))
    # Check all initialized source contents before Git may change any dependency.
    verify(source, initialized_only=True, verify_only=False, shell=shell)
    run('git', '-C', source, '-c', 'core.autocrlf=false', '-c', 'core.longpaths=true',
        'submodule', 'update', '--init', '--', *(SHELL_MODULES if shell else MODULES))
    run('git', '-C', source, '-c', 'core.autocrlf=false', '-c', 'core.longpaths=true',
        'submodule', 'update', '--init', '--recursive', '--', *(SHELL_RECURSIVE if shell else RECURSIVE))
    run('git', '-C', source / 'lib/dino-recomp-decomp-bridge', '-c', 'core.autocrlf=false',
        '-c', 'core.longpaths=true', 'submodule', 'update', '--init', '--', 'dinosaur-planet')
    source = verify(source, verify_only=False, shell=shell)
    for path, _pin in repositories(source, shell=shell):
        run('git', '-C', path, 'remote', 'set-url', '--push', 'origin', 'DISABLED')
    return source


def select_source(source=None):
    # Explicit caches are read-only, including their Git metadata and line endings.
    return verify(source) if source is not None else prepare()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', type=Path, help='Verify an existing public source cache read-only')
    parser.add_argument('--shell', action='store_true', help='Include public iOS app dependencies; no restoration sources')
    args = parser.parse_args()
    try:
        print(verify(args.verify, shell=args.shell) if args.verify else prepare(shell=args.shell))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
