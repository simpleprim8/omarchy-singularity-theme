"""Parse every payload QML file before any live installation takes place."""
from pathlib import Path
import subprocess

def validate_syntax(paths):
    paths = [Path(path) for path in paths]
    if not paths or any(not path.is_file() for path in paths):
        raise RuntimeError('Missing QML source for validation.')
    # qmlformat parses QML natively without resolving unavailable qs.* aliases
    # or doing pathological cross-file type inference. Discard its formatted
    # output; never rewrite the input. Standalone components also get strict
    # qmllint type checks in build.py and the optional boot installer.
    for path in paths:
        result = subprocess.run(['/usr/lib/qt6/bin/qmlformat','--ignore-settings',str(path)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=15)
        if result.returncode:
            raise RuntimeError('QML syntax validation failed: '+str(path)+'\n'+result.stderr)
