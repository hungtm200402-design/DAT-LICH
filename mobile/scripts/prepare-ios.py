#!/usr/bin/env python3
"""Validate public build inputs and compile native icon/plist assets."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import struct
import subprocess
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / "mobile" / "ios"
ICON = ROOT / "public" / "assets" / "hoan-app-icon-v1.png"


def admin_url(value):
    if not isinstance(value, str) or re.search(r"\s", value):
        raise ValueError("Admin URL must be an absolute HTTPS URL without whitespace")
    parts = urlsplit(value)
    if parts.scheme != "https" or not parts.hostname or parts.username is not None or parts.password is not None:
        raise ValueError("Admin URL must use HTTPS and contain no credentials")
    if parts.port is not None and not 1 <= parts.port <= 65535:
        raise ValueError("Invalid admin URL port")
    if any(key.lower() not in {"mobile", "native"} for key, _ in parse_qsl(parts.query, keep_blank_values=True)):
        raise ValueError("Admin URL must not contain unrelated query parameters")
    return urlunsplit((parts.scheme, parts.netloc, parts.path or "/", urlencode({"mobile": "1", "native": "ios"}), "/admin"))


def build_config(defaults, environ):
    config = {
        "admin_url": admin_url(environ.get("HOAN_ADMIN_URL") or defaults["admin_url"]),
        "bundle_id": defaults["bundle_id"],
        "version": environ.get("HOAN_APP_VERSION") or defaults["version"],
        "build_number": environ.get("HOAN_BUILD_NUMBER") or defaults["build_number"],
    }
    if config["bundle_id"] != "vn.hoanmakeup.admin":
        raise ValueError("Unexpected management app identifier")
    if not re.fullmatch(r"[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}", config["version"]):
        raise ValueError("Version must be three numeric components")
    if not re.fullmatch(r"[1-9][0-9]{0,8}", str(config["build_number"])):
        raise ValueError("Build number must be a positive integer of at most nine digits")
    config["build_number"] = str(config["build_number"])
    config["filename"] = f"HOAN-Admin-{config['version']}-{config['build_number']}-unsigned.ipa"
    config["signing"] = "unsigned-requires-sideload-signing"
    config["source_commit"] = environ.get("GITHUB_SHA") or subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()
    return config


def check_icon(path):
    header = Path(path).read_bytes()[:33]
    if len(header) < 33 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Icon source must be PNG")
    width, height = struct.unpack(">II", header[16:24])
    if width != height or width < 1024 or header[25] != 2:
        raise ValueError("Icon source must be square opaque RGB PNG of at least 1024 pixels")


def prepare(output, config):
    check_icon(ICON)
    output.mkdir(parents=True, exist_ok=True)
    template = plistlib.loads((IOS / "HoanAdmin" / "Info.plist").read_bytes())
    template.update(HOANAdminURL=config["admin_url"], CFBundleShortVersionString=config["version"], CFBundleVersion=config["build_number"])
    (output / "Info.plist").write_bytes(plistlib.dumps(template))
    (output / "build-metadata.json").write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    assets = output / "Assets.xcassets"
    icons = assets / "AppIcon.appiconset"
    icons.mkdir(parents=True, exist_ok=True)
    images = []
    generated = set()
    for idiom, sizes in [
        ("iphone", [(20, 2), (20, 3), (29, 2), (29, 3), (40, 2), (40, 3), (60, 2), (60, 3)]),
        ("ipad", [(20, 1), (20, 2), (29, 1), (29, 2), (40, 1), (40, 2), (76, 1), (76, 2), (83.5, 2)]),
        ("ios-marketing", [(1024, 1)]),
    ]:
        for size, scale in sizes:
            pixels = int(size * scale)
            filename = f"icon-{pixels}.png"
            if pixels not in generated:
                subprocess.run(["sips", "-z", str(pixels), str(pixels), str(ICON), "--out", str(icons / filename)], check=True, stdout=subprocess.DEVNULL)
                generated.add(pixels)
            images.append({"idiom": idiom, "size": f"{size}x{size}", "scale": f"{scale}x", "filename": filename})
    info = {"author": "xcode", "version": 1}
    (assets / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n", encoding="utf-8")
    (icons / "Contents.json").write_text(json.dumps({"images": images, "info": info}, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate inputs without generating assets")
    args = parser.parse_args()
    defaults = json.loads((IOS / "build-config.json").read_text(encoding="utf-8"))
    config = build_config(defaults, os.environ)
    check_icon(ICON)
    if not args.check:
        prepare(IOS / ".generated", config)
    print(json.dumps(config, ensure_ascii=False))


if __name__ == "__main__":
    main()
