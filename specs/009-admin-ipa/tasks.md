# Tasks: HOÀN Admin IPA

## Phase 1 — Setup

- [x] T001 Add native build ignore rules in `.gitignore` and public build defaults in `mobile/ios/build-config.json`.

## Phase 2 — Foundation

- [x] T002 Implement validated configuration and icon compilation in `mobile/scripts/prepare-ios.py`.
- [x] T003 Implement IPA structural verification and positive/negative coverage in `mobile/scripts/verify-ipa.py` and `tests/admin-ipa.test.mjs`.

## Phase 3 — US1: Management app

Independent validation: launch at the management route, authenticate through the service and exercise offline retry.

- [x] T004 [US1] Add iOS app lifecycle, management WebView, safe navigation and dialogs in `mobile/ios/HoanAdmin/`.
- [x] T005 [US1] Add XcodeGen project, metadata and privacy manifest in `mobile/ios/`.

## Phase 4 — US2: IPA output

Independent validation: clean macOS build, validated archive, checksum and download into `ipa/`.

- [x] T006 [US2] Implement clean build, bundle validation and packaging in `mobile/scripts/build-ipa.sh`.
- [x] T007 [US2] Add manual/branch-triggered CI in `.github/workflows/build-admin-ipa.yml`.
- [ ] T008 [US2] Run authenticated remote compilation, download and verify IPA under `ipa/`, recording evidence in `specs/009-admin-ipa/verification.md`.

## Phase 5 — Documentation and checks

- [x] T009 Update `docs/BUILD_IPA_APK.md`, `mobile/README.md` and `ipa/README.md` with actual commands and signing state.
- [ ] T010 Run relevant local checks and record actual build/device limitations in `specs/009-admin-ipa/verification.md`.

## Dependencies and execution

T001 → T002/T003 → T004/T005 → T006 → T007 → T008. Documentation/checks follow implementation. Config tests and native layout research are independent; shared file edits remain sequential. Build and source preparation are separate completion criteria.
