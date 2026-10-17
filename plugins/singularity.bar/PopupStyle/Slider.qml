import QtQuick
import "." as Theme
import qs.Commons
import qs.Ui as Ui
Ui.PanelSlider {
  trackColor: Util.alpha(Theme.Palette.blue, 0.18)
  fillColor: Theme.Palette.green
  knobColor: Theme.Palette.orange
}
