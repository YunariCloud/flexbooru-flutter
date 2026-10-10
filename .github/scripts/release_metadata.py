"""Compute validated version metadata for CI, tags and manual releases."""

import os
import re
import subprocess
from pathlib import Path


def prepare_metadata(environment, pubspec):
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?\s*$", pubspec, re.M)
    if not match:
        raise ValueError("pubspec.yaml must contain version: MAJOR.MINOR.PATCH+BUILD")
    version, base_build = match.groups()
    event = environment.get("GITHUB_EVENT_NAME", "")
    is_tag = event == "push" and environment.get("GITHUB_REF_TYPE") == "tag"
    publish = is_tag or (
        event == "workflow_dispatch" and environment.get("INPUT_PUBLISH") == "true"
    )
    tag = environment.get("GITHUB_REF_NAME", "") if is_tag else environment.get("INPUT_TAG", "").strip()
    if tag:
        tag_match = re.fullmatch(r"v(\d+\.\d+\.\d+)(?:-([0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*))?", tag)
        if not tag_match:
            raise ValueError("Release tag must be vMAJOR.MINOR.PATCH, optionally with -rc.1 / -beta.1")
        version = tag_match.group(1)
    elif publish:
        raise ValueError("A release tag is required when publishing manually")
    run_number = int(environment["GITHUB_RUN_NUMBER"])
    build_number = int(base_build or 0) + run_number
    if not 0 < build_number <= 65535:
        raise ValueError("Build number must fit the Windows version field (1..65535)")
    return {
        "version": version,
        "build_number": str(build_number),
        "tag": tag,
        "publish": str(publish).lower(),
        "prerelease": str(bool(tag and "-" in tag)).lower(),
        "label": tag or f"v{version}-build.{build_number}",
    }


def main():
    metadata = prepare_metadata(os.environ, Path("pubspec.yaml").read_text(encoding="utf-8"))
    if metadata["publish"] == "true":
        tag = metadata["tag"]
        exists = subprocess.run(
            ["git", "show-ref", "--verify", "--quiet", f"refs/tags/{tag}"], check=False
        ).returncode == 0
        if exists:
            tagged_commit = subprocess.check_output(
                ["git", "rev-list", "-n", "1", tag], text=True
            ).strip()
            source_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
            if tagged_commit != source_commit:
                raise ValueError("Existing release tag points to a different commit; select that tag or use a new one")
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        for key, value in metadata.items():
            output.write(f"{key}={value}\n")
    print(f"Version {metadata['version']}, build {metadata['build_number']}, publish={metadata['publish']}")


if __name__ == "__main__":
    main()
