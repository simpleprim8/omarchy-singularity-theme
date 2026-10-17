#!/usr/bin/env python3
"""Apply just the new GTK/icon/application appearance to an existing Singularity desktop."""
import importlib.util
import fcntl
import os
from pathlib import Path
import shutil
from system_ui import configure, paths

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('bundle', ROOT / 'install.py')
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


def install():
    if os.geteuid() == 0:
        raise SystemExit('Run this installer as your desktop user.')
    home = Path.home()
    bundle.require_unlocked()
    name = home / '.local/state/omarchy/current/theme.name'
    if not name.is_file() or name.read_text().strip() != 'singularity':
        raise SystemExit('Select your installed Singularity theme first.')
    target = home / '.config/omarchy/themes/singularity'
    assets = ('colors.toml', 'btop.theme', 'icons.theme')
    backup = bundle.snapshot(home, [*paths(home), *[target / name for name in assets]])
    print('System UI backup: ' + str(backup), flush=True)
    try:
        for name in assets:
            shutil.copy2(ROOT / name, target / name)
        configure(home, activate_now=False)
        bundle.run('omarchy', 'theme', 'set', 'singularity')
        bundle.run('hyprctl', 'reload')
        if bundle.run('hyprctl', 'configerrors'):
            raise RuntimeError('Hyprland configuration errors after applying system UI.')
    except BaseException:
        bundle.restore(backup, home)
        raise
    print('Applied GTK3/GTK4 palette, custom icons, utility colors and 90%/88% window opacity.')
    print('Restore: python3 install.py --restore ' + str(backup))


if __name__ == '__main__':
    if os.geteuid() == 0:
        raise SystemExit('Run this installer as your desktop user.')
    lock_path = Path.home() / '.config/omarchy/backups/singularity-bundle.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        install()
