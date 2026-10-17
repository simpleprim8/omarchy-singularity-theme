# Third-party attribution

## Omarchy

Shell plugin sources under `plugins/` derive from the installed Omarchy 4.0.4
shell, with Singularity appearance, background, idle and authentication changes.
Omarchy is Copyright (c) David Heinemeier Hansson and contributors, MIT licensed.
Project: https://github.com/omacom/omarchy
The MIT permission and disclaimer are reproduced in `LICENSE` for this work.
Original contributor comments in the shell sources are retained.

## Rajdhani

`plugins/singularity.bar/PopupStyle/fonts/Rajdhani-Medium.ttf` and
`plugins/singularity.clock/fonts/Rajdhani-Medium.ttf` are distributed under the
SIL Open Font License 1.1. The full copyright, license and reserved-name terms
are included in each adjacent `OFL.txt`.
Source: https://github.com/google/fonts/tree/main/ofl/rajdhani

## Optional F5000

The original desktop uses NR74W's F5000 remake. Its source repository does not
include a redistribution license, so the font binary is excluded from this
public bundle. The builder can reuse an existing local copy; the shipped
Rajdhani face is the fallback.
Source: https://github.com/NR74W/WipEout-Fonts

## Other software

Qt, Quickshell, Hyprland, Plymouth, SDDM and their native authentication systems
are dependencies supplied by the user's operating system, not redistributed
binaries. The Plymouth theme uses the distribution's unchanged `script.so`.
