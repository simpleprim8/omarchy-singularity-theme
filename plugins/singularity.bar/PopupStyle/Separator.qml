import QtQuick
import qs.Commons
import qs.Ui as Ui
import "." as Theme
Ui.PanelSeparator {
  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop { position: 0; color: Util.alpha(Theme.Palette.green, 0.44) }
    GradientStop { position: 0.5; color: Util.alpha(Theme.Palette.title, 0.25) }
    GradientStop { position: 1; color: Util.alpha(Theme.Palette.blue, 0.12) }
  }
}
