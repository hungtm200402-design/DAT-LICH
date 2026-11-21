# Build contract

Inputs: `HOAN_ADMIN_URL` (HTTPS, no credentials), `HOAN_APP_VERSION` (numeric dotted version), `HOAN_BUILD_NUMBER` (positive integer). Defaults are public; CI uses its run number for build number.

Command: `bash mobile/scripts/build-ipa.sh` on macOS with Xcode, XcodeGen, Python 3 and sips.

Output: versioned unsigned IPA, `.sha256` and JSON build manifest under `ipa/`. Configuration, compilation or validation failure exits nonzero before upload.

Native entry: `/?mobile=1&native=ios#/admin` at the configured origin. No embedded credential. Existing server `/api/admin-session` is unchanged.
