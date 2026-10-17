#!/usr/bin/env python3
"""Build the complete reviewed bundle without touching the desktop."""
import argparse
from pathlib import Path
import shutil
import subprocess
from qml_validation import validate_syntax

ROOT = Path(__file__).resolve().parent


def build(destination):
    destination = Path(destination)
    if destination.exists():
        raise RuntimeError('Build destination must not exist: ' + str(destination))
    destination.mkdir(parents=True)
    for directory in ('plugins', 'desktop', 'login'):
        shutil.copytree(ROOT / directory, destination / directory,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.qsb'))
    for filename in ('install-boot.py', 'qml_validation.py'):
        shutil.copy2(ROOT / filename, destination / filename)
    qsb = '/usr/lib/qt6/bin/qsb'
    for directory, stem in (('desktop', 'spacetime'), ('plugins/singularity.background', 'spacetime'),
                            ('plugins/singularity.lock', 'aether'), ('plugins/singularity.lock', 'drain'),
                            ('login', 'login')):
        for extension in ('vert', 'frag'):
            source = destination / directory / (stem + '.' + extension)
            if source.exists():
                options = ['--batchable'] if extension == 'vert' else []
                subprocess.run([qsb, '--qt6', *options, '-o', str(source) + '.qsb', str(source)], check=True)
    for extension in ('vert', 'frag'):
        name = 'login.' + extension + '.qsb'
        shutil.copy2(destination / 'login' / name, destination / 'plugins/singularity.lock' / name)
    # Optional locally owned font; the public tree includes the OFL Rajdhani face.
    candidates = [Path.home() / '.local/share/fonts/F5000.ttf',
                  Path.home() / '.config/omarchy/plugins/simp.bar/fonts/F5000.ttf',
                  Path.home() / '.config/omarchy/plugins/singularity.bar/fonts/F5000.ttf']
    for font in candidates:
        if font.is_file():
            bar = destination / 'plugins/singularity.bar'
            (bar / 'fonts').mkdir(exist_ok=True)
            shutil.copy2(font, bar / 'fonts/F5000.ttf')
            source = bar / 'Bar.qml'
            source.write_text(source.read_text().replace('PopupStyle/fonts/Rajdhani-Medium.ttf', 'fonts/F5000.ttf'))
            break
    validate_syntax(sorted(destination.rglob('*.qml')))
    for directory in ('login', 'plugins/singularity.lock'):
        subprocess.run(['/usr/lib/qt6/bin/qmllint', '--', *[str(destination / directory / name)
                        for name in ('AuthenticationHud.qml', 'SingularityScene.qml', 'PasswordFlow.qml')]], check=True, timeout=60)
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    print(build(args.destination))
