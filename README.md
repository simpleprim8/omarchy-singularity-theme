# Singularity

**One Omarchy theme: animated desktop, lock screen, toolbar and matching apps.**
Singularity 2.0 brings the complete experience into this repository, with one
version, one installer, checksums and a complete user-desktop rollback.

The native green spacetime mesh follows five 90-second camera routes in a
continuous 7½-minute cycle. Emerald icons, a violet clock and titles, blue
descriptions, orange selections and translucent pine surfaces frame the motion.

**[Watch a complete native camera pass](media/desktop-journey.mp4)**

![Singularity on Omarchy](preview.png)

[Browse the desktop, lock-screen and icon showcase](SHOWCASE.md)

## Install the complete theme

Requires **Omarchy 4 with Quickshell and Lua Hyprland configuration**. This
bundle is based on the installed **Omarchy 4.0.4** shell API. Dependencies:
Python 3, Quickshell, Qt Quick, Qt Shader Tools (`qsb`), `qmllint`, `qmlformat` and `grim`.
Run from an unlocked desktop as your normal user:

```bash
git clone https://github.com/simpleprim8/omarchy-singularity-theme.git
cd omarchy-singularity-theme
python3 install.py
```

This installs the palette, native animation, matching secure lock presentation,
bottom toolbar, clock, numbered workspaces, tray styling, coordinated popups,
GTK3/GTK4 application surfaces, original file-explorer icons, a matching btop
palette, static fallback wallpaper and the accepted Codex/Work window opacity
(90% focused, 88% unfocused). No companion checkout is needed. The installer
builds shaders, checks QML, backs up everything it replaces, applies the theme
through Omarchy and checks the renderer, lock service and Hyprland errors.
It may restart the shell while the session is unlocked.

Files and utility windows use the same 90% focused / 88% unfocused transparency.
GTK color overrides are disabled when switching away from Singularity.

Existing personal settings, unknown toolbar widgets, idle deadlines, weather
location, accounts and application preferences are retained. An installation
without idle settings uses a three-minute screensaver and fifteen-minute lock.
The toolbar is placed at the bottom; a new profile uses the supplied layout.
Dropbox and Tailscale styles are included without adding toolbar slots.

Verify the source and build before installing:

```bash
sha256sum -c SHA256SUMS
python3 install.py --check
```

For the palette, static wallpaper and standard shell colors alone, Omarchy's
regular installer remains supported:

```bash
omarchy theme install https://github.com/simpleprim8/omarchy-singularity-theme.git
```

Omarchy deliberately does not execute a downloaded theme's installer. Run the
complete installer above to enable the animated desktop and custom components.

## Matching encrypted-disk and account-login screens

The Plymouth boot prompt and SDDM login artwork are part of this same release.
To install them together with the desktop:

```bash
python3 install.py --with-boot
```

Only the boot/login step requests administrator authentication through `sudo`.
It supports the **Omarchy/Limine/mkinitcpio encrypted-boot pipeline**, backs up
`/boot` and affected settings, rebuilds the boot image and checks its contents.
It preserves existing autologin. See [INSTALL.md](INSTALL.md) for requirements
and separate boot rollback. Normal installation does not rebuild boot files.

The password screens use a stationary mesh and moving masked dots. Dot motion
never expires or rejects the actual password. Authentication remains with the
existing native PAM, SDDM and Plymouth handlers.

![Singularity authentication presentation](preview-unlock.png)

## Update and restore

```bash
git pull --ff-only
python3 install.py
```

Add `--with-boot` when updating the boot/login screens as well. Each run records
a full user-desktop backup under `~/.config/omarchy/backups/singularity-bundle-*`
and prints its exact restore command:

```bash
python3 install.py --restore ~/.config/omarchy/backups/singularity-bundle-TIMESTAMP
```

Runtime files are copied into `~/.local/share/singularity/`; the `spacetime`
command does not depend on keeping the downloaded checkout in place.

## Desktop controls

```bash
spacetime pause          # Freeze the current frame
spacetime start          # Resume the animation
spacetime stop           # Show the static wallpaper
spacetime status        # Perspective, time, speed and pause state
spacetime seek 180      # Third camera route
spacetime preview       # Separate native preview
spacetime restore       # Omarchy's stock background
spacetime enable        # Singularity's animated background
```

Double-click the desktop for wallpaper selection; right-double-click opens the
theme picker. Singularity selection resumes the mesh. The renderer uses native
Qt Quick shaders with no browser, video player, audio or runtime network access.
Standard weather and network widgets retain their normal service behavior.

## Keep the theme together

- `colors.toml`, `shell.toml`, `backgrounds/`: palette and static theme assets.
- `desktop/`: approved Spacetime Desktop 4.0.0 geometry, camera paths and controls.
- `plugins/`: complete coordinated toolbar, popup, background, idle and lock sources.
- `login/`: shared authentication presentation and Plymouth/SDDM assets.
- `config/`: default layout and the small Codex/Work opacity include.
- `system-ui/`: native GTK styles, 88 original SVG icons and utility transparency.
- `install.py`, `build.py`: complete user-desktop installation and shader build.
- `VERSION`, `SHA256SUMS`: the common release version and source integrity record.

After editing, run `python3 tools/release.py --refresh`, then rerun the installer.
See [CHANGELOG.md](CHANGELOG.md), [INSTALL.md](INSTALL.md) and
[VERIFICATION.md](VERIFICATION.md) for the release scope and verification limits.

## Credits and license

Created by **simpleprim8**, with AI-assisted implementation and iteration.
Original palette, artwork and shaders are MIT licensed; see [LICENSE](LICENSE).
The shell components derive from Omarchy by David Heinemeier Hansson and
contributors; see [THIRD_PARTY.md](THIRD_PARTY.md).

Rajdhani Medium is bundled with its SIL Open Font License. F5000 is supported
when already present locally; it is not redistributed. The public bundle uses
Rajdhani as the toolbar fallback. Your locally installed F5000 is retained when
building on the original desktop.
