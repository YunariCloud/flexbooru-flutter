"""Package the Windows runtime and keep releases limited to APK + ZIP."""

import argparse
import json
import os
import re
import subprocess
from pathlib import Path
from urllib.parse import quote
from zipfile import ZIP_DEFLATED, ZipFile


def package_names(label):
    if not re.fullmatch(r"v\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?", label):
        raise ValueError("Invalid artifact label")
    return (
        f"flexbooru-flutter-{label}-android-universal.apk",
        f"flexbooru-flutter-{label}-windows-x64.zip",
    )


def package_windows(runtime, output, license_file):
    runtime, output, license_file = map(Path, (runtime, output, license_file))
    for required in [runtime / "flexbooru.exe", runtime / "flutter_windows.dll",
                     runtime / "data/app.so", license_file]:
        if not required.is_file():
            raise ValueError(f"Required runtime file missing: {required}")
    files = [runtime / "flexbooru.exe"]
    files += sorted(p for p in runtime.iterdir() if p.is_file() and p.suffix.lower() == ".dll")
    files += sorted(p for p in (runtime / "data").rglob("*") if p.is_file())
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        for file in files:
            archive.write(file, file.relative_to(runtime).as_posix())
        archive.write(license_file, "LICENSE")
    print(f"Packaged {len(files) + 1} runtime files: {output.name}")


def redundant_assets(assets, label):
    expected = set(package_names(label))
    by_name = {asset["name"]: asset for asset in assets}
    if not expected <= by_name.keys():
        raise ValueError("Both APK and Windows ZIP must exist before removing attachments")
    for name in expected:
        if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", by_name[name].get("digest") or ""):
            raise ValueError(f"Missing GitHub SHA-256 digest: {name}")
    return sorted(by_name.keys() - expected)


def clean_release(tag, label):
    repo = os.environ["GH_REPO"]
    endpoint = f"repos/{repo}/releases/tags/{quote(tag, safe='')}"
    release = json.loads(subprocess.check_output(["gh", "api", endpoint], encoding="utf-8"))
    for name in redundant_assets(release["assets"], label):
        subprocess.run(["gh", "release", "delete-asset", "--yes", "--", tag, name], check=True)
        print(f"Removed redundant attachment: {name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    windows = commands.add_parser("windows")
    windows.add_argument("--runtime", type=Path, required=True)
    windows.add_argument("--output", type=Path, required=True)
    windows.add_argument("--license", type=Path, default=Path("LICENSE"))
    cleanup = commands.add_parser("clean-release")
    cleanup.add_argument("--tag", required=True)
    cleanup.add_argument("--label", required=True)
    args = parser.parse_args()
    if args.command == "windows":
        package_windows(args.runtime, args.output, args.license)
    else:
        clean_release(args.tag, args.label)


if __name__ == "__main__":
    main()
