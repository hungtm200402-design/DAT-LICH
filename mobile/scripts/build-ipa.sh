#!/bin/bash
# Compile the management iOS app and package an unsigned IPA for sideloading.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"
if [ "$(uname -s)" != Darwin ]; then
  echo "IPA compilation requires macOS/Xcode. Run the GitHub Actions workflow from Windows." >&2
  exit 1
fi
for tool in python3 xcodebuild xcodegen sips ditto zip unzip shasum lipo; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
python3 mobile/scripts/prepare-ios.py
xcodegen generate --spec mobile/ios/project.yml
build_root="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/hoan-admin-build.XXXXXX")"
xcodebuild \
  -project mobile/ios/HoanAdmin.xcodeproj \
  -scheme HoanAdmin -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$build_root/DerivedData" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build
app_bundle="$build_root/DerivedData/Build/Products/Release-iphoneos/HoanAdmin.app"
test -d "$app_bundle"
/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_bundle/Info.plist"
lipo -verify_arch arm64 "$app_bundle/HoanAdmin"
mkdir -p "$build_root/package/Payload" "$PROJECT_ROOT/ipa"
ditto "$app_bundle" "$build_root/package/Payload/HoanAdmin.app"
filename="$(python3 -c 'import json; print(json.load(open("mobile/ios/.generated/build-metadata.json"))["filename"])')"
staged_ipa="$build_root/$filename"
(cd "$build_root/package" && zip -qry "$staged_ipa" Payload)
unzip -t "$staged_ipa"
python3 mobile/scripts/verify-ipa.py "$staged_ipa"
# Publish only after every check succeeds; the staging directory is always fresh.
mv "$staged_ipa" "$PROJECT_ROOT/ipa/$filename"
cp mobile/ios/.generated/build-metadata.json "$PROJECT_ROOT/ipa/${filename%.ipa}.json"
(cd "$PROJECT_ROOT/ipa" && shasum -a 256 "$filename" > "$filename.sha256")
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'ipa=ipa/%s\nchecksum=ipa/%s.sha256\nmetadata=ipa/%s.json\n' \
    "$filename" "$filename" "${filename%.ipa}" >> "$GITHUB_OUTPUT"
fi
echo "IPA ready: ipa/$filename (unsigned; re-sign before installation)"
