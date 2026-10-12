import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

from release_packages import package_names, package_windows, redundant_assets


class ReleasePackagesTests(unittest.TestCase):
    def test_windows_archive_keeps_runtime_and_license_but_no_build_extras(self):
        with tempfile.TemporaryDirectory(prefix="flexbooru-package-test-") as directory:
            root = Path(directory).resolve()
            self.assertTrue(root.is_relative_to(Path(tempfile.gettempdir()).resolve()))
            runtime = root / "runtime"
            required = ["flexbooru.exe", "flutter_windows.dll", "sqlite3.dll",
                        "data/app.so", "data/flutter_assets/NativeAssetsManifest.json",
                        "data/flutter_assets/fonts/font.otf"]
            for name in required + ["README.md", "runner.pdb", "runner.lib", "build.log"]:
                file = runtime / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(b"fixture")
            license_file = root / "LICENSE"
            license_file.write_text("GPL-3.0", encoding="utf-8")
            output = root / "dist/windows.zip"
            package_windows(runtime, output, license_file)
            with ZipFile(output) as archive:
                self.assertEqual(set(archive.namelist()), set(required) | {"LICENSE"})
                self.assertIsNone(archive.testzip())

    def test_missing_native_runtime_prevents_incomplete_zip(self):
        with tempfile.TemporaryDirectory(prefix="flexbooru-package-test-") as directory:
            root = Path(directory).resolve()
            self.assertTrue(root.is_relative_to(Path(tempfile.gettempdir()).resolve()))
            with self.assertRaises(ValueError):
                package_windows(root, root / "out.zip", root / "LICENSE")
            self.assertFalse((root / "out.zip").exists())

    def test_cleanup_preserves_installers_and_removes_extra_attachments(self):
        assets = [{"name": name, "digest": "sha256:" + "a" * 64}
                  for name in package_names("v1.2.0")]
        extras = ["android.aab", "android-SHA256SUMS.txt", "windows-SHA256SUMS.txt", "LICENSE"]
        assets += [{"name": name} for name in extras]
        self.assertEqual(redundant_assets(assets, "v1.2.0"), sorted(extras))

    def test_cleanup_requires_both_packages_and_their_digests(self):
        names = package_names("v1.2.0")
        for assets in [[], [{"name": names[0]}], [{"name": name} for name in names]]:
            with self.subTest(assets=assets), self.assertRaises(ValueError):
                redundant_assets(assets, "v1.2.0")

    def test_package_labels_allow_ci_builds_and_reject_traversal(self):
        self.assertTrue(package_names("v1.2.0-build.16")[0].endswith(".apk"))
        for label in ["../v1.2.0", "--help", "v1.2.0\nother", ""]:
            with self.subTest(label=label), self.assertRaises(ValueError):
                package_names(label)


if __name__ == "__main__":
    unittest.main()
