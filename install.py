#!/usr/bin/env python3
"""Install, update or restore the complete Singularity desktop as one bundle."""
import argparse
import copy
from datetime import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from build import build
from system_ui import configure as configure_ui, paths as ui_paths

ROOT = Path(__file__).resolve().parent
THEME_FILES = ('colors.toml', 'shell.toml', 'icons.theme', 'btop.theme', 'preview.png', 'preview-unlock.png', 'unlock.png', 'backgrounds')
OPACITY_MARKER = '-- Singularity appearance include'


def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout.strip()


def verify_integrity():
    manifest = ROOT / 'SHA256SUMS'
    if not manifest.is_file():
        raise RuntimeError('Missing SHA256SUMS; use a complete release or refresh the manifest after editing.')
    for line in manifest.read_text().splitlines():
        digest, name = line.split('  ', 1)
        path = Path(name)
        if path.is_absolute() or '..' in path.parts:
            raise RuntimeError('Unsafe integrity path: ' + name)
        source = ROOT / path
        if source.is_symlink() or not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            raise RuntimeError('Integrity check failed: ' + name)
    return hashlib.sha256(manifest.read_bytes()).hexdigest()[:12]


def require_unlocked():
    if subprocess.run(['omarchy-hyprland-session-locked'], capture_output=True).returncode != 1:
        raise RuntimeError('The compositor is locked or its state is unknown. Unlock before installing.')
    state = json.loads(run('omarchy-shell', 'lock', 'status'))
    if not state.get('passwordPam') or any(state.get(key) for key in
            ('locked', 'requested', 'sessionLocked', 'secure', 'pending', 'authenticating')):
        raise RuntimeError('The lock service must be healthy and unlocked before installing.')


def preflight(with_boot=False):
    required = ['omarchy', 'omarchy-shell', 'omarchy-hyprland-session-locked', 'hyprctl', 'quickshell', 'grim', 'gsettings', 'gtk-update-icon-cache', 'fc-cache']
    missing = [name for name in required if shutil.which(name) is None]
    missing += [name for name in ('/usr/lib/qt6/bin/qsb', '/usr/lib/qt6/bin/qmllint', '/usr/lib/qt6/bin/qmlformat') if not Path(name).is_file()]
    if with_boot:
        missing += [name for name in ('sudo', 'limine-mkinitcpio', 'lsinitcpio', 'plymouth-set-default-theme')
                    if shutil.which(name) is None]
    if missing:
        raise RuntimeError('Missing dependencies: ' + ', '.join(missing))
    require_unlocked()
    errors = run('hyprctl', 'configerrors')
    if errors:
        raise RuntimeError('Resolve existing Hyprland configuration errors first: ' + errors)


def plugin_aliases():
    aliases = {}
    for manifest in sorted((ROOT / 'plugins').glob('*/manifest.json')):
        data = json.loads(manifest.read_text())
        target = data['id']
        suffix = target.split('.', 1)[1]
        for source in (target, 'simp.' + suffix, data.get('omarchy', {}).get('clonedFrom')):
            if source:
                aliases[source] = target
    aliases['spacetime.background'] = 'singularity.background'
    return aliases


def merge_shell(current):
    """Migrate known clones; preserve unrelated widgets and all personal settings."""
    aliases = plugin_aliases()
    def migrate(value):
        if isinstance(value, dict):
            return {key: migrate(item) for key, item in value.items()}
        if isinstance(value, list):
            return [migrate(item) for item in value]
        return aliases.get(value, value) if isinstance(value, str) else value
    result = migrate(copy.deepcopy(current))
    defaults = json.loads((ROOT / 'config/shell.json').read_text())
    bar = result.setdefault('bar', {})
    for key, value in defaults['bar'].items():
        bar.setdefault(key, copy.deepcopy(value))
    bar['id'] = 'singularity.bar'
    bar['position'] = 'bottom'
    bar['transparent'] = False
    idle = result.setdefault('idle', {})
    idle.setdefault('screensaver', 180)
    idle.setdefault('lock', 900)
    services = result.setdefault('plugins', [])
    # Previous setups can contain both an original and a custom clone slot.
    services[:] = list({item['id']: item for item in services}.values())
    for name in ('background', 'idle', 'lock'):
        target = 'singularity.' + name
        if not any(item.get('id') == target for item in services):
            services.append({'id': target})
    # Loaded clone services replace their first-party counterparts; disabled
    # IDs remain first-party IDs, never migrated into disabled new clones.
    active = {item['id'] for item in services}
    disabled = {item for item in current.get('disabledPlugins', []) if item not in active}
    disabled.update('omarchy.' + name for name in ('background', 'idle', 'lock'))
    disabled.update(source for source, target in aliases.items() if source != target and target in active)
    result['disabledPlugins'] = sorted(disabled)
    result['cloneSourceRestores'] = sorted(set(result.get('cloneSourceRestores', [])) |
                                         {item for item in active if item.startswith('singularity.')})
    result.setdefault('version', 1)
    return result


def exists(path):
    return path.exists() or path.is_symlink()


def remove(path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink(missing_ok=True)


def copy_path(source, destination):
    if source.is_symlink():
        destination.symlink_to(os.readlink(source))
    elif source.is_dir():
        shutil.copytree(source, destination, symlinks=True)
    else:
        shutil.copy2(source, destination)


def replace(source, target):
    """Stage the whole file/tree before replacing its destination."""
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.singularity-stage-', dir=target.parent) as directory:
        stage = Path(directory) / 'new'
        previous = Path(directory) / 'previous'
        copy_path(source, stage)
        if exists(target):
            target.rename(previous)
        try:
            stage.rename(target)
        except BaseException:
            if exists(previous):
                previous.rename(target)
            raise


def snapshot(home, paths):
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup = home / '.config/omarchy/backups' / ('singularity-bundle-' + stamp)
    (backup / 'files').mkdir(parents=True)
    entries = []
    for index, path in enumerate(paths):
        entry = {'path': str(path.relative_to(home)), 'saved': str(index), 'existed': exists(path)}
        if entry['existed']:
            copy_path(path, backup / 'files' / str(index))
        entries.append(entry)
    state = home / '.local/state/omarchy/current/theme.name'
    previous_icons = run('gsettings', 'get', 'org.gnome.desktop.interface', 'icon-theme')
    data = {'version': 1, 'entries': entries, 'previous_theme': state.read_text().strip() if state.is_file() else '',
            'previous_icons': previous_icons}
    (backup / 'manifest.json').write_text(json.dumps(data, indent=2) + '\n')
    return backup


def restore(backup, home, reload=True):
    parent = home / '.config/omarchy/backups'
    if backup.is_symlink() or backup.resolve().parent != parent.resolve() or not backup.name.startswith('singularity-bundle-'):
        raise RuntimeError('Restore requires a Singularity bundle backup in ~/.config/omarchy/backups/.')
    data = json.loads((backup / 'manifest.json').read_text())
    # Validate everything before changing any installed files.
    entries = []
    allowed = ('.config/omarchy/', '.config/hypr/', '.config/gtk-3.0/', '.config/gtk-4.0/',
               '.local/share/icons/Singularity', '.local/share/fonts/Singularity',
               '.local/share/singularity/', '.local/bin/spacetime')
    for entry in data['entries']:
        raw = entry['path']
        path = Path(raw)
        saved = str(entry['saved'])
        if (path.is_absolute() or '..' in path.parts or not raw.startswith(allowed)
                or not saved.isdecimal() or not isinstance(entry['existed'], bool)):
            raise RuntimeError('Unsafe restore manifest')
        source = backup / 'files' / saved
        if entry['existed'] and not exists(source):
            raise RuntimeError('Incomplete restore backup: ' + raw)
        entries.append((home / path, source, entry['existed']))
    if reload:
        require_unlocked()
    for target, source, existed in reversed(entries):
        if existed:
            replace(source, target)
        elif exists(target):
            remove(target)
    if reload:
        run('omarchy', 'restart', 'shell')
        if data['previous_theme']:
            run('omarchy', 'theme', 'set', data['previous_theme'])
        if data.get('previous_icons'):
            run('gsettings', 'set', 'org.gnome.desktop.interface', 'icon-theme', data['previous_icons'])
        run('hyprctl', 'reload')
    print('Restored bundle backup: ' + str(backup))


def verify_loaded():
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        try:
            # A restarted service may need a moment to configure PAM. A real
            # compositor lock still blocks rollback/reload in install().
            if subprocess.run(['omarchy-hyprland-session-locked'], capture_output=True).returncode != 1:
                raise RuntimeError('The compositor became locked or its state is unknown.')
            lock_state = json.loads(run('omarchy-shell', 'lock', 'status'))
            if any(lock_state.get(key) for key in ('locked', 'requested', 'sessionLocked', 'secure', 'pending', 'authenticating')):
                raise RuntimeError('The desktop became locked during installation.')
            if not lock_state.get('passwordPam') or 'singularity' not in lock_state:
                time.sleep(.2)
                continue
            status = json.loads(run('omarchy-shell', 'spacetime', 'status'))
            if status.get('version') == '4.0.0' and status.get('enabled') and not status.get('paused'):
                if run('hyprctl', 'configerrors'):
                    raise RuntimeError('Hyprland reported configuration errors.')
                return status
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            pass
        time.sleep(.2)
    raise RuntimeError('The desktop did not report a healthy renderer after installation.')


def install(payload, home, revision):
    theme = home / '.config/omarchy/themes/singularity'
    shell_path = home / '.config/omarchy/shell.json'
    runtime = home / '.local/share/singularity' / revision
    hook = home / '.config/omarchy/hooks/theme-set.d/80-spacetime-singularity'
    command = home / '.local/bin/spacetime'
    opacity = home / '.config/hypr/singularity-appearance.lua'
    hyprland = home / '.config/hypr/hyprland.lua'
    plugin_targets = [home / '.config/omarchy/plugins' / path.name for path in sorted((payload / 'plugins').iterdir())]
    targets = list(dict.fromkeys([shell_path, *plugin_targets, *[theme / name for name in THEME_FILES],
                                 runtime, hook, command, opacity, hyprland, *ui_paths(home)]))
    current = json.loads(shell_path.read_text()) if shell_path.exists() else {}
    merged = merge_shell(current)
    backup = snapshot(home, targets)
    print('Complete bundle backup: ' + str(backup), flush=True)
    try:
        require_unlocked()
        replace(payload, runtime)
        for source, target in zip(sorted((payload / 'plugins').iterdir()), plugin_targets):
            require_unlocked()
            replace(source, target)
        for name in THEME_FILES:
            replace(ROOT / name, theme / name)
        replace(ROOT / 'hooks/80-spacetime-singularity', hook)
        hook.chmod(0o755)
        command.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as directory:
            link = Path(directory) / 'spacetime'
            link.symlink_to(runtime / 'desktop/spacetime')
            replace(link, command)
        replace(ROOT / 'config/agent-opacity.lua', opacity)
        text = hyprland.read_text() if hyprland.is_file() else ''
        if OPACITY_MARKER not in text:
            text += '\n' + OPACITY_MARKER + '\ndofile(os.getenv("HOME") .. "/.config/hypr/singularity-appearance.lua")\n'
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'hyprland.lua'
            file.write_text(text)
            replace(file, hyprland)
            file.write_text(json.dumps(merged, indent=2) + '\n')
            require_unlocked()
            replace(file, shell_path)
        configure_ui(home, activate_now=False)
        run('omarchy', 'restart', 'shell')
        run('omarchy', 'theme', 'set', 'singularity')
        run('omarchy-shell', 'spacetime', 'resume')
        run('hyprctl', 'reload')
        status = verify_loaded()
        receipt = {'release': (ROOT / 'VERSION').read_text().strip(), 'revision': revision,
                   'backup': str(backup), 'runtime': str(runtime), 'animation': status,
                   'real_password_unlock_verified': False, 'physical_reboot_verified': False}
        (backup / 'verification.json').write_text(json.dumps(receipt, indent=2) + '\n')
        print('Installed and verified Singularity ' + receipt['release'])
        print('Restore: python3 install.py --restore ' + str(backup))
        return runtime
    except BaseException:
        # Never restart a live secure lock client during rollback.
        try:
            require_unlocked()
        except Exception:
            print('Desktop locked or lock state unknown. No rollback reload attempted. Backup: ' + str(backup), flush=True)
            raise
        restore(backup, home)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='verify integrity, dependencies and build without installing')
    parser.add_argument('--with-boot', action='store_true', help='also install Plymouth/SDDM using sudo after desktop validation')
    parser.add_argument('--restore', type=Path, help='restore a complete user-desktop backup')
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Run as your desktop user; --with-boot requests sudo only for boot/login installation.')
    if args.restore and (args.check or args.with_boot):
        parser.error('--restore cannot be combined with install options')
    home = Path.home()
    lock_path = home / '.config/omarchy/backups/singularity-bundle.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.restore:
            restore(args.restore, home)
            return
        revision = (ROOT / 'VERSION').read_text().strip() + '-' + verify_integrity()
        preflight(args.with_boot)
        with tempfile.TemporaryDirectory(prefix='singularity-build-') as directory:
            payload = build(Path(directory) / 'payload')
            if args.check:
                print('Integrity, dependencies, shader compilation and QML checks passed; nothing installed.')
                return
            runtime = install(payload, home, revision)
        if args.with_boot:
            subprocess.run(['sudo', 'python3', str(runtime / 'install-boot.py')], check=True)


if __name__ == '__main__':
    main()
