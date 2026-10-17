# Singularity

An emerald-and-black Omarchy theme built around a native animated spacetime
desktop. A transparent wire mesh bends into a singular point as the camera
explores above and below the field. Pale green text, quiet surfaces, and
distinct semantic colors keep applications readable around the motion.

![Singularity on a real Omarchy desktop](preview.png)

**[Watch a complete 90-second camera pass](https://github.com/simpleprim8/spacetime-desktop/blob/main/media/journey.mp4)**
— the animation is the centerpiece; the theme frames it.

## Install

```bash
omarchy theme install https://github.com/simpleprim8/omarchy-singularity-theme.git
```

Tested on **Omarchy 4.0.4**. Omarchy generates its supported terminal and app
themes from the complete `colors.toml` palette. The included `shell.toml`
coordinates the bar, menus, launcher, notifications and standard lock surfaces.
Dark Prussian-green folder icons and a native 2560×1440 wallpaper are included.
GNOME apps use Adwaita dark. Applications with their own theme preferences may
need to be reopened or configured separately.

## Animated desktop

The green mesh in the screenshot comes from
[Spacetime Desktop](https://github.com/simpleprim8/spacetime-desktop): a native
Qt Quick background with five smooth 90-second camera paths around a transparent
three-dimensional funnel that tapers into darkness. The sparse wire grid, slow
opening exploration, and gradual acceleration are designed for a desktop.

The theme works by itself with the included static wallpaper. **Installing this
theme does not install or run the animation.** Follow the companion project's
instructions if you want the moving desktop. It uses one continuous mesh, with
no second tunnel grid, video player, browser, or network connection at runtime.

## Customize

- `colors.toml`: application colors, terminal ANSI palette and window borders.
- `shell.toml`: explicit shell surface and interaction colors. Update this file
  alongside the palette when changing shell colors.
- `backgrounds/`: matching static wallpapers.

Select another theme through Omarchy's regular theme picker to change palettes.
If the optional animation is installed, use `spacetime stop` for the static
wallpaper or `spacetime restore` to return to Omarchy's stock background plugin.

## Credits and license

Created by **simpleprim8**, with AI-assisted implementation and iteration.
The palette and procedural wallpaper are part of this project. Shell surface
configuration is adapted from Omarchy's theme templates. Omarchy is by David
Heinemeier Hansson and contributors; this is an independent community theme.

MIT licensed; see [LICENSE](LICENSE).
