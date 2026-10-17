"""Theme-scoped GTK appearance and original Singularity icons."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
MARKER = '-- Singularity system UI include'
IMPORT = '@import url("singularity.css"); /* Singularity managed import */'


def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout.strip()


def paths(home):
    return [*[home / '.config' / toolkit / name
              for toolkit in ('gtk-3.0', 'gtk-4.0') for name in ('gtk.css', 'singularity.css')],
            home / '.local/share/icons/Singularity', home / '.local/share/fonts/Singularity',
            home / '.local/share/singularity/ui',
            home / '.config/omarchy/hooks/theme-set.d/85-singularity-ui',
            home / '.config/hypr/singularity-system-ui.lua', home / '.config/hypr/hyprland.lua']


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.singularity-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as output:
            output.write(text)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def install_tree(source, target):
    """Replace only this project's complete asset tree; discard stale revisions."""
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.singularity-', dir=target.parent) as directory:
        stage, previous = Path(directory) / 'new', Path(directory) / 'previous'
        shutil.copytree(source, stage)
        if target.exists():
            target.rename(previous)
        try:
            stage.rename(target)
        except BaseException:
            if previous.exists():
                previous.rename(target)
            raise


def activate(home, theme, runtime):
    # Empty managed CSS when switching themes; independent user CSS remains.
    for toolkit in ('gtk-3.0', 'gtk-4.0'):
        css = (runtime / (toolkit + '.css')).read_text() if theme == 'singularity' else '/* Singularity inactive. */\n'
        write(home / '.config' / toolkit / 'singularity.css', css)
    if theme == 'singularity':
        run('gsettings', 'set', 'org.gnome.desktop.interface', 'icon-theme', 'Singularity')
    run('hyprctl', 'reload')
    errors = run('hyprctl', 'configerrors')
    if errors:
        raise RuntimeError('Hyprland reported errors: ' + errors)


def configure(home, source=ROOT, activate_now=True):
    runtime = home / '.local/share/singularity/ui'
    assets = source / 'system-ui'
    install_tree(assets, runtime)
    shutil.copy2(source / 'system_ui.py', runtime / 'theme-ui.py')
    icons = home / '.local/share/icons/Singularity'
    icons.parent.mkdir(parents=True, exist_ok=True)
    install_tree(assets / 'icons/Singularity', icons)
    fonts = home / '.local/share/fonts/Singularity'
    fonts.parent.mkdir(parents=True, exist_ok=True)
    install_tree(assets / 'fonts', fonts)
    for toolkit in ('gtk-3.0', 'gtk-4.0'):
        entry = home / '.config' / toolkit / 'gtk.css'
        original = entry.read_text() if entry.exists() else ''
        if IMPORT not in original:
            write(entry, IMPORT + '\n' + original)
    hook = home / '.config/omarchy/hooks/theme-set.d/85-singularity-ui'
    write(hook, '#!/bin/bash\nset -euo pipefail\nexec python3 "$HOME/.local/share/singularity/ui/theme-ui.py" "${1:-}"\n')
    hook.chmod(0o755)
    write(home / '.config/hypr/singularity-system-ui.lua', (assets / 'appearance.lua').read_text())
    hyprland = home / '.config/hypr/hyprland.lua'
    text = hyprland.read_text() if hyprland.is_file() else ''
    if MARKER not in text:
        write(hyprland, text + '\n' + MARKER + '\ndofile(os.getenv("HOME") .. "/.config/hypr/singularity-system-ui.lua")\n')
    run('gtk-update-icon-cache', '-f', '-t', str(icons))
    run('fc-cache', '-f', str(fonts))
    if activate_now:
        state = home / '.local/state/omarchy/current/theme.name'
        theme = state.read_text().strip() if state.is_file() else ''
        activate(home, theme, runtime)


if __name__ == '__main__':
    activate(Path.home(), sys.argv[1] if len(sys.argv) > 1 else '', Path(__file__).resolve().parent)
