# Implementation Plan: HOÀN Admin IPA

**Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Create the iPhone management app and remote IPA build. Native source lives in `mobile/ios/`, project configuration in `project.yml`, build tools in `mobile/scripts/`, and CI in `.github/workflows/build-admin-ipa.yml`. Output: unsigned IPA for sideload re-signing under `ipa/`.

## Technical Context

- Swift 5, UIKit/WebKit, iOS 15; system frameworks only.
- XcodeGen; Python standard library for configuration/icon manifest generation and IPA verification; macOS sips for icon compilation.
- Existing mobile admin UI, HTTPS frontend/API same origin, persistent website store.
- Public build inputs: HTTPS URL, identifier `vn.hoanmakeup.admin`, version `1.0.0`, positive build number.
- Tests: URL validation, IPA verifier positive/negative cases, existing security suite; native compilation in CI and device validation when available.

## Constitution Check

Pass: D1, admin operations and payment rules remain server-side. No schema changes or embedded admin key. Preserve unrelated edits. Remote build success and physical-device verification require separate evidence.

## Structure

```text
mobile/ios/project.yml
mobile/ios/HoanAdmin/{AppDelegate,AdminViewController}.swift
mobile/ios/HoanAdmin/{Info.plist,PrivacyInfo.xcprivacy}
mobile/scripts/{prepare-ios.py,build-ipa.sh,verify-ipa.py}
.github/workflows/build-admin-ipa.yml
ipa/{README.md,HOAN-Admin-<version>-<build>-unsigned.ipa}
tests/admin-ipa.test.mjs
```

## Design

Validate the public HTTPS base URL, forbid user-info, and force mobile/native query flags and the admin fragment. Show loading/retry UI, implement browser dialogs, allow only the exact origin in the management view. Keep credentials solely in the existing login/session mechanism.

Build from fresh derived data. Validate plist, identifier, ARM64 Mach-O executable and icons, then zip only `Payload/HoanAdmin.app`. Verify the archive before checksumming and upload. Actions has read-only contents permissions and needs no signing secrets.

## Execution and Publication

Prepare source and local checks first. If GitHub access becomes available, use an isolated build commit/branch without staging unrelated edits; dispatch CI, inspect results and download the IPA/checksum into `ipa/`. If authentication is absent, retain runnable source and report that no IPA has yet compiled.
