import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bundle_installer', ROOT / 'install.py')
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


class ShellMigration(unittest.TestCase):
    def test_personal_settings_and_unknown_widgets_survive(self):
        original = {'idle': {'lock': 1234, 'screensaver': 234}, 'custom': {'keep': True},
                    'bar': {'layout': {'left': [{'id': 'acme.widget'}, {'id': 'simp.menu'}], 'right': [], 'center': []}},
                    'plugins': [{'id': 'omarchy.lock'}, {'id': 'acme.service'}], 'disabledPlugins': ['omarchy.lock']}
        unchanged = copy.deepcopy(original)
        result = bundle.merge_shell(original)
        self.assertEqual(original, unchanged)
        self.assertEqual(result['idle'], original['idle'])
        self.assertTrue(result['custom']['keep'])
        self.assertEqual(result['bar']['layout']['left'], [{'id': 'acme.widget'}, {'id': 'singularity.menu'}])
        self.assertIn({'id': 'acme.service'}, result['plugins'])
        self.assertNotIn('singularity.lock', result['disabledPlugins'])
        self.assertIn('omarchy.lock', result['disabledPlugins'])

    def test_empty_home_receives_complete_profile(self):
        result = bundle.merge_shell({})
        self.assertEqual(result['idle'], {'screensaver': 180, 'lock': 900})
        self.assertEqual(result['bar']['centerAnchor'], 'singularity.clock')
        self.assertEqual(result['bar']['position'], 'bottom')
        self.assertIn({'id': 'singularity.lock'}, result['plugins'])

    def test_previous_public_animation_is_migrated(self):
        result = bundle.merge_shell({'plugins': [{'id': 'spacetime.background'}]})
        self.assertEqual(result['plugins'].count({'id': 'singularity.background'}), 1)
        self.assertIn('spacetime.background', result['disabledPlugins'])

    def test_old_original_and_clone_slots_do_not_create_duplicate_services(self):
        result = bundle.merge_shell({'plugins': [{'id': 'omarchy.lock'}, {'id': 'simp.lock'}]})
        self.assertEqual(result['plugins'].count({'id': 'singularity.lock'}), 1)

    def test_readiness_waits_for_pam_after_restart(self):
        ready = {'passwordPam': True, 'singularity': True}
        status = {'version': '4.0.0', 'enabled': True, 'paused': False}
        with patch.object(bundle.subprocess, 'run') as process, patch.object(bundle, 'run',
                side_effect=[json.dumps({'passwordPam': False}), json.dumps(ready), json.dumps(status), '']), \
                patch.object(bundle.time, 'sleep') as sleep:
            process.return_value.returncode = 1
            self.assertEqual(bundle.verify_loaded(), status)
            sleep.assert_called_once()


class InstallTransaction(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home'
        self.home.mkdir()
        self.payload = Path(self.temp.name) / 'payload'
        (self.payload / 'plugins/singularity.background').mkdir(parents=True)
        (self.payload / 'plugins/singularity.background/manifest.json').write_text('{}')
        (self.payload / 'desktop').mkdir()
        (self.payload / 'desktop/spacetime').write_text('#!/bin/bash\n')
        self.shell = self.home / '.config/omarchy/shell.json'
        self.shell.parent.mkdir(parents=True)
        self.shell.write_text('{"custom": "keep", "idle": {"lock": 1321}}\n')
        self.original = self.shell.read_bytes()
        self.status = {'version': '4.0.0', 'enabled': True, 'paused': False}
        for mock in (patch.object(bundle, 'require_unlocked'), patch.object(bundle, 'run', return_value=''),
                     patch.object(bundle, 'verify_loaded', return_value=self.status), patch.object(bundle, 'configure_ui')):
            mock.start()
            self.addCleanup(mock.stop)

    def test_fresh_install_and_restore_preserve_shell_and_command_symlink(self):
        old_command = self.home / '.local/bin/spacetime'
        old_command.parent.mkdir(parents=True)
        old_command.symlink_to('/previous/spacetime')
        runtime = bundle.install(self.payload, self.home, 'test-revision')
        self.assertTrue(runtime.is_dir())
        self.assertEqual(old_command.resolve(), runtime / 'desktop/spacetime')
        self.assertEqual(json.loads(self.shell.read_text())['idle']['lock'], 1321)
        backup = next((self.home / '.config/omarchy/backups').glob('singularity-bundle-*'))
        bundle.restore(backup, self.home, reload=False)
        self.assertEqual(self.shell.read_bytes(), self.original)
        self.assertEqual(str(old_command.readlink()), '/previous/spacetime')
        self.assertFalse(runtime.exists())

    def test_renderer_failure_restores_the_entire_previous_desktop(self):
        target = self.home / '.config/omarchy/plugins/singularity.background'
        target.mkdir(parents=True)
        (target / 'known-good').write_text('old renderer')
        with patch.object(bundle, 'verify_loaded', side_effect=RuntimeError('renderer failed')):
            with self.assertRaisesRegex(RuntimeError, 'renderer failed'):
                bundle.install(self.payload, self.home, 'test-failure')
        self.assertEqual((target / 'known-good').read_text(), 'old renderer')
        self.assertEqual(self.shell.read_bytes(), self.original)
        self.assertFalse((self.home / '.local/bin/spacetime').exists())

    def test_reinstall_does_not_duplicate_the_hyprland_include(self):
        bundle.install(self.payload, self.home, 'revision-one')
        bundle.install(self.payload, self.home, 'revision-two')
        text = (self.home / '.config/hypr/hyprland.lua').read_text()
        self.assertEqual(text.count(bundle.OPACITY_MARKER), 1)

    def test_restore_rejects_traversal_before_modifying_files(self):
        backup = bundle.snapshot(self.home, [self.shell])
        manifest = backup / 'manifest.json'
        data = json.loads(manifest.read_text())
        data['entries'][0]['path'] = '.config/omarchy/../../../outside'
        manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(RuntimeError, 'Unsafe restore'):
            bundle.restore(backup, self.home, reload=False)
        self.assertEqual(self.shell.read_bytes(), self.original)

    def test_missing_backup_is_rejected_before_modifying_files(self):
        backup = bundle.snapshot(self.home, [self.shell])
        (backup / 'files/0').unlink()
        with self.assertRaisesRegex(RuntimeError, 'Incomplete restore'):
            bundle.restore(backup, self.home, reload=False)
        self.assertEqual(self.shell.read_bytes(), self.original)

    def test_failed_stage_copy_keeps_existing_payload(self):
        target = self.home / 'target'
        target.write_text('known good')
        with patch.object(bundle, 'copy_path', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                bundle.replace(self.shell, target)
        self.assertEqual(target.read_text(), 'known good')


class Validation(unittest.TestCase):
    def test_invalid_qml_is_rejected_by_native_parser(self):
        from qml_validation import validate_syntax
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'broken.qml'
            source.write_text('import QtQuick\nItem { property bool broken: }')
            with self.assertRaisesRegex(RuntimeError, 'syntax validation failed'):
                validate_syntax([source])


if __name__ == '__main__':
    unittest.main()
