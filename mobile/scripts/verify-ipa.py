#!/usr/bin/env python3
"""Reject malformed or wrong-target management IPA files before publication."""
import argparse
import json
from pathlib import PurePosixPath
import plistlib
import struct
from urllib.parse import urlsplit, parse_qs
import zipfile


def verify_ipa(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP member")
        for name in names:
            if name.startswith("/") or ".." in PurePosixPath(name).parts or "\\" in name or not name.startswith("Payload/"):
                raise ValueError("Unexpected archive path")
        plists = [name for name in names if len(PurePosixPath(name).parts) == 3 and name.startswith("Payload/") and name.endswith(".app/Info.plist")]
        if len(plists) != 1:
            raise ValueError("IPA must contain exactly one root app plist")
        if archive.testzip() is not None:
            raise ValueError("Corrupt ZIP member")
        base = plists[0].removesuffix("Info.plist")
        info = plistlib.loads(archive.read(plists[0]))
        required = ["CFBundleIdentifier", "CFBundleExecutable", "CFBundleName", "CFBundleDisplayName", "CFBundlePackageType", "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion", "HOANAdminURL"]
        if any(not info.get(key) for key in required):
            raise ValueError("Missing required bundle metadata")
        if info["CFBundleIdentifier"] != "vn.hoanmakeup.admin" or info["CFBundlePackageType"] != "APPL":
            raise ValueError("Unexpected application identifier/type")
        executable = info["CFBundleExecutable"]
        if "/" in executable or "\\" in executable or executable in {".", ".."}:
            raise ValueError("Invalid executable name")
        member = archive.getinfo(base + executable)
        binary = archive.read(member)
        if len(binary) < 32 or binary[:4] != b"\xcf\xfa\xed\xfe" or struct.unpack_from("<I", binary, 4)[0] != 0x0100000C or struct.unpack_from("<I", binary, 12)[0] != 2:
            raise ValueError("Executable is not a thin ARM64 Mach-O application")
        count, command_bytes = struct.unpack_from("<II", binary, 16)
        end = 32 + command_bytes
        if end > len(binary) or count > command_bytes // 8:
            raise ValueError("Invalid Mach-O load command table")
        offset, iphone_platform = 32, False
        for _ in range(count):
            if offset + 8 > end:
                raise ValueError("Truncated Mach-O load command")
            command, size = struct.unpack_from("<II", binary, offset)
            if size < 8 or offset + size > end:
                raise ValueError("Invalid Mach-O load command size")
            if command == 0x32:  # LC_BUILD_VERSION; PLATFORM_IOS is 2, simulator is 7.
                if size < 24 or struct.unpack_from("<I", binary, offset + 8)[0] != 2:
                    raise ValueError("Executable was not built for iPhone devices")
                iphone_platform = True
            offset += size
        if not iphone_platform or offset != end:
            raise ValueError("iPhone build platform metadata missing")
        if not ((member.external_attr >> 16) & 0o111):
            raise ValueError("Executable permission missing")
        if not archive.read(base + "Assets.car") or not info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon"):
            raise ValueError("Compiled app icon missing")
        url = urlsplit(info["HOANAdminURL"])
        if url.scheme != "https" or not url.hostname or url.username is not None or url.password is not None or url.fragment != "/admin" or parse_qs(url.query).get("mobile") != ["1"] or parse_qs(url.query).get("native") != ["ios"]:
            raise ValueError("Management launch URL invalid")
        if any(name.endswith("embedded.mobileprovision") or "/_CodeSignature/" in name for name in names):
            raise ValueError("Expected unsigned package for sideload re-signing")
        if any(PurePosixPath(name).name.startswith(".dev.vars") or PurePosixPath(name).suffix.lower() in {".sqlite", ".p12", ".mobileprovision", ".key"} for name in names):
            raise ValueError("Private local file found in package")
        return {"bundle_id": info["CFBundleIdentifier"], "version": info["CFBundleShortVersionString"], "build_number": info["CFBundleVersion"], "admin_url": info["HOANAdminURL"], "signing": "unsigned-requires-sideload-signing", "members": len(names)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa")
    args = parser.parse_args()
    print(json.dumps(verify_ipa(args.ipa), ensure_ascii=False))


if __name__ == "__main__":
    main()
