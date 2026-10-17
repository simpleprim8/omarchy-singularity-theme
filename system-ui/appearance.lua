-- Theme-scoped application transparency. Existing rules and app geometry stay intact.
local theme_file = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme.name", "r")
local theme = theme_file and theme_file:read("*l") or ""
if theme_file then theme_file:close() end
if theme == "singularity" then
  o.window("^org[.]gnome[.](Nautilus|DiskUtility|Calculator|SystemMonitor|FileRoller|Settings|baobab|TextEditor|Console|Evince|Zenity)$", {
    opacity = "0.90 override 0.88 override",
  })
  o.window("^(foot|Alacritty|kitty|com[.]mitchellh[.]ghostty|org[.]pulseaudio[.]pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|singularity-showcase-.*)$", {
    opacity = "0.90 override 0.88 override",
  })
end
