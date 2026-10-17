import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
def module(name, filename):
    spec=importlib.util.spec_from_file_location(name,ROOT/filename)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result
boot=module('boot_installer','install-boot.py')

class BootRestore(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.backup=self.root/'backup';self.disk=self.root/'boot'
        self.disk.mkdir();(self.backup/'boot').mkdir(parents=True)
        self.destinations=(self.root/'theme-a',self.root/'theme-b')
        self.configs=(self.root/'config-a',self.root/'config-b');self.module=self.root/'adapter'
        self.patches=[patch.object(boot,'BOOT',self.disk),patch.object(boot,'DESTINATIONS',self.destinations),patch.object(boot,'CONFIGS',self.configs),patch.object(boot,'MODULE',self.module)]
        for p in self.patches:p.start();self.addCleanup(p.stop)
        self.manifest={'targets':{str(p):False for p in (*self.destinations,*self.configs,self.module)},'boot_files':['kernel.efi']}
        (self.disk/'kernel.efi').write_bytes(b'new-kernel')
        (self.backup/'boot/kernel.efi').write_bytes(b'known-good-kernel')
    def save(self): (self.backup/'manifest.json').write_text(json.dumps(self.manifest))
    def test_restores_known_file_without_deleting_unrelated_boot_files(self):
        unrelated=self.disk/'new-recovery.efi';unrelated.write_bytes(b'keep-me')
        self.save();boot.restore(self.backup)
        self.assertEqual((self.disk/'kernel.efi').read_bytes(),b'known-good-kernel')
        self.assertEqual(unrelated.read_bytes(),b'keep-me')
    def test_traversal_rejected_before_live_configuration_changes(self):
        self.destinations[0].mkdir();marker=self.destinations[0]/'marker';marker.write_text('live')
        self.manifest['boot_files']=['../outside'];self.save()
        with self.assertRaises(RuntimeError):boot.restore(self.backup)
        self.assertEqual(marker.read_text(),'live')
    def test_missing_backup_rejected_before_live_configuration_changes(self):
        self.destinations[0].mkdir();marker=self.destinations[0]/'marker';marker.write_text('live')
        (self.backup/'boot/kernel.efi').unlink();self.save()
        with self.assertRaises(RuntimeError):boot.restore(self.backup)
        self.assertEqual(marker.read_text(),'live')
    def test_interrupted_copy_keeps_existing_boot_artifact(self):
        with patch.object(boot.shutil,'copyfileobj',side_effect=OSError('simulated full disk')):
            with self.assertRaises(OSError):boot.atomic_copy(self.backup/'boot/kernel.efi',self.disk/'kernel.efi')
        self.assertEqual((self.disk/'kernel.efi').read_bytes(),b'new-kernel')
        self.assertEqual(list(self.disk.glob('.singularity-restore-*')),[])
