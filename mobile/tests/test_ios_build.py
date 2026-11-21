"""Build-contract tests; fixture ZIPs are not compiled applications."""
import importlib.util
import json
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "mobile" / "scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare = load("prepare-ios")
verifier = load("verify-ipa")


class BuildContractTests(unittest.TestCase):
    def test_management_entry_is_forced(self):
        self.assertEqual(prepare.admin_url("https://studio.example/"), "https://studio.example/?mobile=1&native=ios#/admin")
        self.assertTrue(prepare.admin_url("https://studio.example/?mobile=0#/booking").endswith("?mobile=1&native=ios#/admin"))

    def test_unsafe_urls_are_rejected(self):
        for url in ["http://studio.example", "https://user:private@studio.example/", "https://", "https://studio.example/\n", "https://studio.example:99999/", "https://studio.example/?token=private"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                prepare.admin_url(url)

    def test_build_inputs_reject_invalid_versions_and_paths(self):
        defaults = json.loads((ROOT / "mobile" / "ios" / "build-config.json").read_text(encoding="utf-8"))
        for key, value in [("HOAN_APP_VERSION", "../../bad"), ("HOAN_APP_VERSION", "1.0"), ("HOAN_BUILD_NUMBER", "0"), ("HOAN_BUILD_NUMBER", "-1")]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                prepare.build_config(defaults, {key: value, "GITHUB_SHA": "fixture"})
        config = prepare.build_config(defaults, {"HOAN_BUILD_NUMBER": "12", "GITHUB_SHA": "fixture"})
        self.assertEqual(config["filename"], "HOAN-Admin-1.0.0-12-unsigned.ipa")

    def test_design_source_is_usable_for_native_icons(self):
        prepare.check_icon(prepare.ICON)

    def fixture(self, path, *, cpu=0x0100000C, platform=2, extra=None, executable=True):
        info = {
            "CFBundleIdentifier": "vn.hoanmakeup.admin", "CFBundleExecutable": "HoanAdmin",
            "CFBundleName": "HoanAdmin", "CFBundleDisplayName": "HOÀN Admin", "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0",
            "HOANAdminURL": "https://studio.example/?mobile=1&native=ios#/admin",
            "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["AppIcon60x60"]}},
        }
        base = "Payload/HoanAdmin.app/"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr(base + "Info.plist", plistlib.dumps(info))
            archive.writestr(base + "Assets.car", b"fixture-icon-catalog")
            if executable:
                member = zipfile.ZipInfo(base + "HoanAdmin")
                member.create_system = 3
                member.external_attr = 0o100755 << 16
                archive.writestr(member, struct.pack("<IIIIIIII", 0xFEEDFACF, cpu, 0, 2, 1, 24, 0, 0)
                                 + struct.pack("<IIIIII", 0x32, 24, platform, 0x000F0000, 0x001A0000, 0))
            if extra:
                for name, data in extra.items():
                    archive.writestr(name, data)

    def test_valid_archive_structure(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.ipa"
            self.fixture(path)
            self.assertEqual(verifier.verify_ipa(path)["bundle_id"], "vn.hoanmakeup.admin")

    def test_missing_executable_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.ipa"
            self.fixture(path, executable=False)
            with self.assertRaises(KeyError):
                verifier.verify_ipa(path)

    def test_simulator_binary_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.ipa"
            self.fixture(path, cpu=0x01000007)
            with self.assertRaisesRegex(ValueError, "ARM64"):
                verifier.verify_ipa(path)

    def test_traversal_and_private_files_are_rejected(self):
        for name in ["Payload/../outside", "outside.txt", "Payload/HoanAdmin.app/.dev.vars", "Payload/HoanAdmin.app/database.sqlite"]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "fixture.ipa"
                self.fixture(path, extra={name: b"fixture"})
                with self.assertRaises(ValueError):
                    verifier.verify_ipa(path)

    def test_arm64_simulator_and_catalyst_are_rejected(self):
        for platform in [6, 7]:
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "fixture.ipa"
                self.fixture(path, platform=platform)
                with self.assertRaisesRegex(ValueError, "iPhone devices"):
                    verifier.verify_ipa(path)

    def test_truncated_load_command_table_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.ipa"
            self.fixture(path)
            with zipfile.ZipFile(path) as archive:
                members = [(entry, archive.read(entry)) for entry in archive.infolist()]
            with zipfile.ZipFile(path, "w") as archive:
                for entry, content in members:
                    if entry.filename.endswith("/HoanAdmin"):
                        content = content[:32]
                    archive.writestr(entry, content)
            with self.assertRaisesRegex(ValueError, "load command"):
                verifier.verify_ipa(path)

    def test_signing_state_is_explicit(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.ipa"
            self.fixture(path, extra={"Payload/HoanAdmin.app/embedded.mobileprovision": b"fixture"})
            with self.assertRaisesRegex(ValueError, "unsigned"):
                verifier.verify_ipa(path)


if __name__ == "__main__":
    unittest.main()
