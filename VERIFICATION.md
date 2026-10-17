# Singularity 2.0 verification

Validated on Omarchy 4.0.4-1, Qt 6.11.2, GTK 4.22.4, libadwaita 1.9.3 and the
active Wayland desktop on 2026-10-17.

- The approved Spacetime Desktop 4.0.0 geometry, material and QML scene match the
  prior accepted source byte for byte. Five 90-second paths remain unchanged.
- The complete shader build and syntax checks pass for 70 QML files. Strict
  native lint passes for the standalone authentication components.
- Eighteen Python checks cover migration, fresh/update installation, preserving
  personal settings and command symlinks, failed-install rollback, incomplete
  backups, traversal rejection, interrupted boot copies, asynchronous PAM
  readiness and preservation/deactivation of independent user CSS.
- Native Qt tests report 13 passes, covering login failure/retry, late editing
  after visual dots disappear, and bounded dot rendering without input truncation.
- The native Plymouth interpreter checks pass for callback behavior, static
  mesh, dot motion, recovery context, retry, success milestone and geometry.
- GTK3 and GTK4 parse their final stylesheets without diagnostics. All 88 SVG
  icons parse. The real GTK icon loader resolves folders and file types into the
  installed Singularity theme, including Documents, Downloads, Python and PDF.
- The application styling is installed and visually checked in Files, terminals
  and btop. The original workspace is restored; animation is enabled/unpaused,
  the lock service reports healthy PAM and the compositor reports no errors.
- Selector, menu, calendar and synthetic lock previews were captured from the
  real native UI. See SHOWCASE.md for video sampling and timing details.
- The full bundle's check-only command validates source integrity, dependencies,
  unlocked desktop state, shaders and QML without replacing installed plugins.
- Release packaging checks every archive member against SHA256SUMS and rejects
  a file-set mismatch. The archive has a separate SHA-256 digest.

The current system-UI update has a complete pre-change backup at
`~/.config/omarchy/backups/singularity-bundle-20261017-175645-595089/` on the
original workstation. Use its printed restore command to revert it.

The unified installer is exercised against temporary homes with mocked shell
commands. Its final complete plugin replacement has not been run against this
workstation: the installed animation/lock implementation is preserved while the
new application appearance is applied. Installation on another physical machine
remains unverified. A physical reboot and real disk/password authentication are
manual checks and are not represented by visual previews or native unit tests.

Reproduce build and checks:

```bash
sha256sum -c SHA256SUMS
python3 -m unittest discover -s tests -v
python3 build.py /tmp/singularity-build
QT_QPA_PLATFORM=offscreen QSG_RHI_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input /tmp/singularity-build/login/tests
python3 login/check-plymouth.py
python3 install.py --check
```
