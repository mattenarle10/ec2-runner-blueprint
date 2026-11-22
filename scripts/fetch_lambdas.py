#!/usr/bin/env python3
"""Download and verify the upstream release before installing any Lambda files."""

import hashlib
import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory


def main():
    root = Path(__file__).resolve().parents[1]
    release = json.loads((root / "release.json").read_text())
    destination = root / ".artifacts"
    destination.mkdir(exist_ok=True)

    with TemporaryDirectory(dir=destination) as directory:
        staging = Path(directory)
        files = release["sha256"]
        download = ["gh", "release", "download", release["tag"], "--repo", release["repo"], "--dir", directory]
        for name in (*files, release["bundle"]):
            download += ["--pattern", name]
        subprocess.run(download, check=True)
        bundle = (staging / release["bundle"]).rename(staging / "attestation.json")

        for name, digest in files.items():
            path = staging / name
            if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                raise SystemExit(f"Release checksum mismatch for {name}")
            subprocess.run([
                "gh", "attestation", "verify", str(path), "--repo", release["repo"],
                "--bundle", str(bundle), "--source-digest", release["source_sha"],
            ], check=True)

        for name in files:
            (staging / name).replace(destination / name)


if __name__ == "__main__":
    main()
