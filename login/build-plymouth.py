#!/usr/bin/env python3
"""Package the static boot scene/HUD with Plymouth's stock input handling."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'plymouth'
for name in ('frame-0.png', 'hud-idle.png', 'hud-checking.png', 'hud-failed.png', 'hud-success.png'):
    image = OUT / name
    subprocess.run(['magick', str(image), '-resize', '1280x720!', '-strip', str(image)], check=True)
subprocess.run(['magick', '-size', '32x32', 'xc:none', '-fill', '#dcffe8', '-draw', 'circle 16,16 16,5', str(OUT/'dot.png')], check=True)
(OUT/'singularity.plymouth').write_text("""[Plymouth Theme]
Name=Singularity
Description=Static spacetime mesh, causal navigation HUD and falling password dots
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/singularity
ScriptFile=/usr/share/plymouth/themes/singularity/singularity.script
ConsoleLogBackgroundColor=0x020704
Font=JetBrains Mono 12
MonospaceFont=JetBrains Mono 12
""")
print('Built Plymouth theme with native input handling:', OUT)
