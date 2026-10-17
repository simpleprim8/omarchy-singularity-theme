from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import system_ui

class SystemUi(unittest.TestCase):
    def test_reinstall_preserves_existing_user_css_without_duplicate_imports(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(system_ui, 'run'):
            home = Path(directory)
            css = home / '.config/gtk-4.0/gtk.css'
            css.parent.mkdir(parents=True)
            original = '/* Personal adjustment */\nlabel { letter-spacing: 1px; }\n'
            css.write_text(original)
            system_ui.configure(home, activate_now=False)
            system_ui.configure(home, activate_now=False)
            self.assertEqual(css.read_text().count(system_ui.IMPORT), 1)
            self.assertTrue(css.read_text().endswith(original))
            hypr = (home / '.config/hypr/hyprland.lua').read_text()
            self.assertEqual(hypr.count(system_ui.MARKER), 1)

    def test_switching_themes_disables_only_the_managed_css(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(system_ui, 'run') as run:
            run.return_value = ''
            home = Path(directory)
            runtime = Path(system_ui.ROOT) / 'system-ui'
            system_ui.activate(home, 'singularity', runtime)
            managed = home / '.config/gtk-4.0/singularity.css'
            self.assertIn('--headerbar-fg-color: #b4a0d2', managed.read_text())
            run.reset_mock()
            system_ui.activate(home, 'ethereal', runtime)
            self.assertEqual(managed.read_text(), '/* Singularity inactive. */\n')
            self.assertFalse(any(call.args[0] == 'gsettings' for call in run.call_args_list))

if __name__ == '__main__': unittest.main()
