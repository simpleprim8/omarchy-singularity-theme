#!/usr/bin/env python3
"""Compare installed boot assets with the built UKI; no boot writes."""
from pathlib import Path
import hashlib
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
image = '/boot/EFI/Linux/omarchy_linux-omarchy.efi'
pairs = [
    ('usr/lib/plymouth/script.so', Path('/usr/lib/plymouth/script.so')),
    ('usr/share/plymouth/themes/singularity/singularity.script', root/'login/plymouth/singularity.script'),
    ('usr/share/plymouth/themes/singularity/singularity.plymouth', root/'login/plymouth/singularity.plymouth'),
    *[(f'usr/share/plymouth/themes/singularity/hud-{state}.png', root/f'login/plymouth/hud-{state}.png') for state in ('idle','checking','failed','success')],
    ('usr/share/plymouth/themes/singularity/frame-0.png', root/'login/plymouth/frame-0.png'),
]
with tempfile.TemporaryDirectory(prefix='singularity-boot-check-') as directory:
    subprocess.run(['lsinitcpio','-x',image], cwd=directory, check=True, stdout=subprocess.DEVNULL)
    for relative, source in pairs:
        actual = Path(directory)/relative
        assert hashlib.sha256(actual.read_bytes()).digest() == hashlib.sha256(source.read_bytes()).digest(), relative
print('Boot-image script, theme selection, static scene, HUD states and stock interpreter match tested sources byte for byte.')
