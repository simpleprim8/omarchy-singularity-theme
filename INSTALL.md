# Installation and recovery

The complete installer targets Omarchy 4.0.4's Quickshell plugin API and Lua
Hyprland configuration. It is not an installer for arbitrary Linux desktops or
older Hyprland configuration formats. Check dependencies with
`python3 install.py --check` from an unlocked desktop.

The shipped plugin sources are a coordinated snapshot of that shell version.
After a major Omarchy API change, review/rebase the shell components before
updating. The renderer and authentication appearance can be maintained in this
single repository without replacing package-owned Omarchy files.

## What is installed

The user installer writes only these user-owned paths:

- `~/.config/omarchy/themes/singularity/`: the palette and theme assets.
- `~/.config/omarchy/plugins/singularity.*/`: coordinated plugin payloads.
- `~/.config/omarchy/shell.json`: migrated plugin IDs and bottom toolbar choice.
- `~/.config/omarchy/hooks/theme-set.d/80-spacetime-singularity`: resume hook.
- `~/.config/hypr/singularity-appearance.lua`: Codex/Work opacity rule.
- `~/.config/hypr/singularity-system-ui.lua`: theme-scoped utility transparency.
- `~/.config/gtk-{3,4}.0/`: one preserved-user-CSS import and managed palette file.
- `~/.local/share/icons/Singularity/`: the original vector icon theme.
- `~/.local/share/fonts/Singularity/`: the licensed Rajdhani heading font.
- `~/.config/hypr/hyprland.lua`: one marked include for that rule.
- `~/.local/share/singularity/VERSION-CHECKSUM/`: built runtime and boot payload.
- `~/.local/bin/spacetime`: stable command pointing to the copied runtime.

Existing `simp.*` clones and the former public `spacetime.background` are
recognized and their active slots are migrated. Their directories remain in
place. Unknown services/widgets and configured idle thresholds survive the
merge. Existing toolbar positions are retained within their sections. A profile
without a layout receives the complete supplied layout.

The source checksum manifest excludes generated shader binaries. The installer
verifies every source file, compiles the shaders with the installed Qt compiler,
parses all QML and strictly lints the standalone authentication components before
writing installed theme/plugin files. `--check` performs these checks without
applying the theme; it creates only its installer lock directory and temporary
build files. Concurrent bundle installers are serialized.

If an existing F5000 font is found in the local font directory or previous bar
plugin, it is copied into the private runtime during build. Otherwise Rajdhani
Medium is used. Local font files never enter the public archive.

## User-desktop rollback

Every installation snapshots all managed paths, including prior command
symlinks, shell settings, affected Hyprland files, existing theme files and
previous plugin directories. On a failed unlocked desktop validation, the
installer restores that snapshot and previous palette automatically. If the
compositor becomes locked or its state is unknown, it retains the backup and
refuses a further shell reload; unlock before manually restoring.

Use the exact backup path printed by installation:

```bash
python3 install.py --restore ~/.config/omarchy/backups/singularity-bundle-TIMESTAMP
```

This restores the state immediately before that run. It can replace later edits
to managed paths; use the backup appropriate to the change you want to undo.
Files and plugins outside that manifest are preserved. Runtime payloads from
older successful installations are retained so their rollback paths remain
available.

## Boot/login installation and rollback

Use `python3 install.py --with-boot` to build and validate the complete payload,
install the user desktop, then request `sudo` for the matching Plymouth and SDDM
presentation. Run the entry point as your ordinary user, never through sudo.

This optional installer requires an existing Plymouth+SDDM installation using
Omarchy's `limine-mkinitcpio` pipeline, `/boot`, and native initramfs encryption
hooks. It verifies the stock Plymouth interpreter, encrypt/recovery components
and every theme asset inside a rebuilt image. It does not configure disk
encryption, change PAM policy or alter account passwords. Do not use it on a
different boot stack.

Administrator backups and receipts are kept under
`/var/backups/singularity-login/TIMESTAMP/`. A failed build or verification
restores the saved configuration and original boot artifacts. The user desktop
and boot/login steps have separate rollback records. If the optional boot step
fails, the already validated user desktop remains installed.

Restore the boot/login step from this checkout:

```bash
sudo python3 install-boot.py --restore /var/backups/singularity-login/TIMESTAMP
```

The boot restore command does not require rebuilding shaders. It restores the
known boot artifacts without deleting unrelated new recovery files. A physical
reboot and real encrypted-disk/password authentication remain manual checks;
the installer does not reboot or lock your session for testing.

## Application appearance

GTK3 and GTK4/libadwaita share the shell color roles, while keeping native widget
geometry. Utility windows use compositor opacity at 0.90 focused / 0.88 unfocused;
background CSS stays opaque so multiple alpha layers do not compound. Existing
user CSS is preserved. A theme hook clears only the managed CSS when switching
away from Singularity. Open GTK applications may need reopening for stylesheet
changes. Application-specific canvas/document colors are not forcibly replaced.

`python3 install-system-ui.py` applies just this part to an existing Singularity
desktop with its own complete rollback snapshot; it leaves the animation and
lock implementation in place. The full installer includes it automatically.

The styles use GTK [CssProvider](https://docs.gtk.org/gtk4/class.CssProvider.html)
and libadwaita [CSS variables](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/css-variables.html).
Window rules follow the current [Hyprland Lua API](https://wiki.hypr.land/Configuring/Basics/Window-Rules/).
