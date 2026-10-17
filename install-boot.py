#!/usr/bin/env python3
"""Install the reviewed Plymouth and SDDM presentations, with boot rollback."""
from datetime import datetime
import hashlib
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from qml_validation import validate_syntax

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'login'
SDDM_FILES = ('Main.qml','PasswordFlow.qml','AuthenticationHud.qml','SingularityScene.qml','VortexMath.js','login.vert.qsb','login.frag.qsb','metadata.desktop','theme.conf')
PLYMOUTH_FILES = ('singularity.script','singularity.plymouth','dot.png','frame-0.png',*(f'hud-{state}.png' for state in ('idle','checking','failed','success')))
DESTINATIONS = (Path('/usr/share/plymouth/themes/singularity'),Path('/usr/share/sddm/themes/singularity'))
CONFIGS = (Path('/etc/plymouth/plymouthd.conf'),Path('/etc/sddm.conf.d/zz-singularity-theme.conf'))
MODULE = Path('/usr/lib/plymouth/singularity-timeout.so')
BOOT = Path('/boot')

def boot_relative(raw):
    if not isinstance(raw, str):
        raise RuntimeError('Unsafe boot backup path')
    path = Path(raw)
    if path.is_absolute() or '..' in path.parts or not path.parts:
        raise RuntimeError('Unsafe boot backup path')
    return path

def atomic_copy(source, destination):
    """Replace a boot artifact only after the complete copy is on disk."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.singularity-restore-', dir=destination.parent)
    try:
        with os.fdopen(fd, 'wb') as output, open(source, 'rb') as input_file:
            shutil.copyfileobj(input_file, output)
            output.flush()
            os.fsync(output.fileno())
        shutil.copystat(source, name)
        os.replace(name, destination)
    finally:
        Path(name).unlink(missing_ok=True)

def verify_boot_assets(image):
    """Reject a rebuilt image missing a theme asset or the native unlock path."""
    with tempfile.TemporaryDirectory(prefix='singularity-image-verify-') as directory:
        extracted = Path(directory)
        subprocess.run(['/usr/bin/lsinitcpio','-x',str(image)], cwd=directory,
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        for name in PLYMOUTH_FILES:
            installed = extracted/'usr/share/plymouth/themes/singularity'/name
            if not installed.is_file() or installed.read_bytes() != (SOURCE/'plymouth'/name).read_bytes():
                raise RuntimeError('Boot asset verification failed: '+name)
        interpreter = extracted/'usr/lib/plymouth/script.so'
        if not interpreter.is_file() or interpreter.read_bytes() != Path('/usr/lib/plymouth/script.so').read_bytes():
            raise RuntimeError('The boot image does not contain the stock Plymouth interpreter.')
        for required in ('init','hooks/encrypt','usr/bin/cryptsetup','usr/bin/plymouthd','usr/lib/plymouth/details.so'):
            if not (extracted/required).is_file():
                raise RuntimeError('Required boot/recovery component is missing: '+required)
        if (extracted/'usr/lib/plymouth/singularity-timeout.so').exists():
            raise RuntimeError('The obsolete password timeout adapter is still bundled.')

def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout

def restore(backup):
    manifest=json.loads((backup/'manifest.json').read_text())
    # Validate the entire manifest before changing any live configuration.
    if set(manifest['targets']) != {str(p) for p in (*DESTINATIONS,*CONFIGS,MODULE)}:
        raise RuntimeError('Incomplete configuration backup manifest')
    for raw, existed in manifest['targets'].items():
        if Path(raw) not in (*DESTINATIONS,*CONFIGS,MODULE) or not isinstance(existed, bool):
            raise RuntimeError('Unexpected restore destination: '+raw)
        saved = backup/'files'/Path(raw).relative_to('/')
        if existed and (not saved.exists() or saved.is_symlink()):
            raise RuntimeError('Missing or unsafe configuration backup: '+raw)
    for raw in manifest['boot_files']:
        saved = backup/'boot'/boot_relative(raw)
        if not saved.is_file() or saved.is_symlink():
            raise RuntimeError('Missing or unsafe boot backup: '+raw)
    for raw, existed in manifest['targets'].items():
        dest=Path(raw)
        if dest not in (*DESTINATIONS,*CONFIGS,MODULE):
            raise RuntimeError('Unexpected restore destination: '+raw)
        if dest.is_dir(): shutil.rmtree(dest)
        elif dest.exists(): dest.unlink()
        saved=backup/'files'/dest.relative_to('/')
        if existed:
            if saved.is_dir(): shutil.copytree(saved,dest)
            else: shutil.copy2(saved,dest)
    # Restore the exact known-good boot artifacts, including Limine's menu.
    for raw in manifest['boot_files']:
        relative = boot_relative(raw)
        saved=backup/'boot'/relative
        dest=BOOT/relative
        atomic_copy(saved,dest)
    # Never sweep /boot: another kernel or recovery tool may have added files.
    print('Restored boot/login configuration and original boot files from '+str(backup),flush=True)

def install():
    if Path('/var/lib/pacman/db.lck').exists():
        raise RuntimeError('A package transaction is active; finish it before updating boot assets.')
    validate_syntax(SOURCE.glob('*.qml'))
    run("/usr/lib/qt6/bin/qmllint", "--", *[str(SOURCE / name) for name in ("AuthenticationHud.qml", "SingularityScene.qml", "PasswordFlow.qml")])
    for directory, files in ((SOURCE,SDDM_FILES),(SOURCE/'plymouth',PLYMOUTH_FILES)):
        for name in files:
            p=directory/name
            if p.is_symlink() or not p.is_file() or not p.stat().st_size:
                raise RuntimeError('Missing or invalid asset: '+str(p))
    # Preserve everything before touching boot images or system configuration.
    stamp=datetime.now().strftime('%Y%m%d-%H%M%S')
    backup=Path('/var/backups/singularity-login')/stamp
    backup.mkdir(parents=True,mode=0o700)
    boot_files=[p for p in BOOT.rglob('*') if p.is_file()]
    size=sum(p.stat().st_size for p in boot_files)
    if shutil.disk_usage(backup).free < size+512*1024*1024:
        raise RuntimeError('Not enough free space for a complete boot backup.')
    manifest={'targets':{},'boot_files':[str(p.relative_to(BOOT)) for p in boot_files]}
    print('Backing up configuration and '+str(round(size/1024/1024))+' MiB of boot files to '+str(backup),flush=True)
    shutil.copytree(BOOT,backup/'boot',symlinks=True)
    for dest in (*DESTINATIONS,*CONFIGS,MODULE):
        manifest['targets'][str(dest)]=dest.exists()
        if dest.exists():
            saved=backup/'files'/dest.relative_to('/')
            saved.parent.mkdir(parents=True,exist_ok=True)
            if dest.is_dir(): shutil.copytree(dest,saved)
            else: shutil.copy2(dest,saved)
    (backup/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    try:
        for dest, directory, files in ((DESTINATIONS[0],SOURCE/'plymouth',PLYMOUTH_FILES),(DESTINATIONS[1],SOURCE,SDDM_FILES)):
            stage=dest.with_name('.singularity-stage-'+stamp)
            stage.mkdir(mode=0o755)
            for name in files:
                source=directory/name
                target=stage/name
                shutil.copyfile(source,target)
                target.chmod(0o644)
                if hashlib.sha256(source.read_bytes()).digest()!=hashlib.sha256(target.read_bytes()).digest():
                    raise RuntimeError('Installed asset mismatch: '+name)
            if dest.exists(): shutil.rmtree(dest)
            stage.rename(dest)
        CONFIGS[1].write_text('[Theme]\nCurrent=singularity\n')
        CONFIGS[1].chmod(0o644)
        run('/usr/bin/plymouth-set-default-theme','singularity')
        print('Rebuilding the boot image with the existing Omarchy/Limine pipeline…',flush=True)
        result=subprocess.run(['/usr/bin/limine-mkinitcpio'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        (backup/'rebuild.log').write_text(result.stdout)
        print(result.stdout,flush=True)
        if result.returncode or 'ERROR:' in result.stdout:
            raise RuntimeError('Boot rebuild reported an error; restoring the original files.')
        verified=[]
        for image in BOOT.rglob('*'):
            if image.is_file() and image.name.endswith(('.efi','.img')):
                result=subprocess.run(['/usr/bin/lsinitcpio','-l',str(image)],capture_output=True,text=True)
                if result.returncode==0 and all(asset in result.stdout for asset in ('usr/share/plymouth/themes/singularity/singularity.script','usr/lib/plymouth/script.so')):
                    verify_boot_assets(image)
                    verified.append(str(image))
        if not verified:
            raise RuntimeError('Could not verify the Singularity assets inside a boot image.')
        verification={'backup':str(backup),'plymouth':run('/usr/bin/plymouth-set-default-theme').strip(),'sddm':'singularity','verified_boot_images':verified,'physical_reboot_verified':False}
        (backup/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
        # Privileged output stays in the protected backup directory. The caller
        # can save stdout unprivileged; never follow a workspace receipt symlink.
        print(json.dumps(verification),flush=True)
        print('Installed and verified. Backup: '+str(backup),flush=True)
    except BaseException:
        restore(backup)
        raise

if __name__=='__main__':
    if os.geteuid()!=0:
        raise SystemExit('Administrator access required: sudo python3 '+str(Path(__file__).resolve()))
    os.environ['PATH']='/usr/bin:/bin'
    lock_fd = os.open('/run/lock/singularity-boot.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lock_fd, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if len(sys.argv)==3 and sys.argv[1]=='--restore':
            candidate=Path(sys.argv[2]).resolve()
            if candidate.parent != Path('/var/backups/singularity-login'):
                raise SystemExit('Restore requires a backup directly under /var/backups/singularity-login/.')
            restore(candidate)
        elif len(sys.argv)==1:
            install()
        else:
            raise SystemExit('Usage: install-boot.py [--restore /var/backups/singularity-login/TIMESTAMP]')
