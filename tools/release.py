#!/usr/bin/env python3
"""Refresh source checksums or make a deterministic, verified release archive."""
import argparse
import gzip
import hashlib
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[1]


def sources():
    return sorted(path for path in ROOT.rglob('*') if path.is_file()
                  and not any(part in ('.git', '__pycache__', '.pytest_cache') for part in path.relative_to(ROOT).parts)
                  and path.name != 'SHA256SUMS' and path.suffix not in ('.pyc', '.qsb', '.gz', '.zip'))


def refresh():
    lines = []
    for path in sources():
        if path.is_symlink():
            raise RuntimeError('Release sources must be regular files: ' + str(path))
        lines.append(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.relative_to(ROOT).as_posix())
    (ROOT / 'SHA256SUMS').write_text('\n'.join(lines) + '\n')
    print('SHA256SUMS: ' + str(len(lines)) + ' source files')


def archive(destination):
    manifest = ROOT / 'SHA256SUMS'
    names = []
    for line in manifest.read_text().splitlines():
        expected, name = line.split('  ', 1)
        path = ROOT / name
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError('Refresh checksums before packaging: ' + name)
        names.append(name)
    if set(names) != {str(path.relative_to(ROOT)) for path in sources()}:
        raise RuntimeError('The manifest does not match the complete source tree.')
    names.append('SHA256SUMS')
    version = (ROOT / 'VERSION').read_text().strip()
    prefix = 'singularity-' + version
    destination = Path(destination).resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('wb') as stream, gzip.GzipFile(fileobj=stream, mode='wb', mtime=0, filename='') as zipped:
        with tarfile.open(fileobj=zipped, mode='w') as tar:
            for name in sorted(names):
                info = tar.gettarinfo(str(ROOT / name), arcname=prefix + '/' + name)
                info.uid = info.gid = info.mtime = 0
                info.uname = info.gname = ''
                info.mode = 0o755 if name in ('desktop/spacetime', 'hooks/80-spacetime-singularity') else 0o644
                with (ROOT / name).open('rb') as source:
                    tar.addfile(info, source)
    with tarfile.open(destination) as tar:
        expected_names = {prefix + '/' + name for name in names}
        if set(tar.getnames()) != expected_names:
            raise RuntimeError('Archive file set differs from the manifest.')
        for line in manifest.read_text().splitlines():
            expected, name = line.split('  ', 1)
            if hashlib.sha256(tar.extractfile(prefix + '/' + name).read()).hexdigest() != expected:
                raise RuntimeError('Archive verification failed: ' + name)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_name(destination.name + '.sha256').write_text(digest + '  ' + destination.name + '\n')
    print('Verified ' + str(len(names)) + ' archive members: ' + str(destination))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    if args.refresh:
        refresh()
    if args.archive:
        archive(args.archive)
    if not args.refresh and not args.archive:
        parser.error('Choose --refresh and/or --archive OUTPUT.tar.gz')
