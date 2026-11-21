# Validation and build

1. Windows: `node --test tests/admin-ipa.test.mjs` and `node --test tests/security.test.mjs`.
2. macOS: install XcodeGen, then run `bash mobile/scripts/build-ipa.sh` with optional `HOAN_ADMIN_URL`, `HOAN_APP_VERSION`, `HOAN_BUILD_NUMBER` environment inputs.
3. GitHub: run **Build HOÀN Admin IPA**, download the artifact into `ipa/`, verify using `python mobile/scripts/verify-ipa.py <file.ipa>`.
4. Re-sign/install on iPhone, open app, log in using the online service key, inspect management screens, log out and confirm revoked access. Device evidence is required.
5. Record run URL, commit, checksum and backend compatibility; static checks do not prove native compilation.
