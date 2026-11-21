# Feature Specification: HOÀN Admin iPhone app

**Feature Branch**: current checkout; isolate the build commit before publishing
**Created**: 2026-11-21
**Status**: Specified
**Input**: Build an IPA for the existing management app, using the updated mobile administration screens, and save the resulting file in `ipa/`.

## User Scenarios & Testing

### User Story 1 — Open the management app (P1)

The owner installs HOÀN Admin on an iPhone and opens the existing management dashboard, appointments, deposits, working schedule and customer screens.

**Why this priority**: The requested deliverable is an installable management app.
**Independent Test**: Launch on an iPhone/simulator against the configured HTTPS service and confirm entry is the management route.

**Acceptance Scenarios**:

1. Given a valid configured service, opening the app goes directly to administration with the existing mobile layout.
2. Given no session, the existing admin login appears; successful login grants the same permissions as the website.
3. Given an unavailable service, an actionable retry screen appears.

### User Story 2 — Download an IPA from Windows (P1)

The owner triggers a remote build and obtains a versioned IPA in the repository's `ipa/` directory.

**Why this priority**: The owner has a Windows machine and wants the actual build.
**Independent Test**: A clean remote build returns a nonempty IPA containing the application executable, metadata and icon, plus a checksum.

**Acceptance Scenarios**:

1. A successful build produces a downloadable IPA without requiring signing credentials in the repository.
2. Failed compilation or bundle validation stops the job and produces no success artifact.
3. The package can be re-signed by the chosen sideload tool for installation.

### Edge Cases

- Expired login, offline state, external links, new-window requests and JavaScript confirmation dialogs.
- HTTPS certificate failures are handled as connection failures.
- Missing remote build authentication is reported explicitly; source preparation is not presented as a completed IPA build.

## Requirements

### Functional Requirements

- **FR-001**: Start directly in administration and reuse the existing mobile management screens.
- **FR-002**: Reuse existing authentication, server validation, payment rules and D1 data; never embed an admin password or duplicate business data in the app.
- **FR-003**: Show the newly created H icon and the name HOÀN Admin.
- **FR-004**: Allow HTTPS service configuration at build time; default to the existing verified deployment when available.
- **FR-005**: Keep external websites out of the authenticated management view and support expected dialogs.
- **FR-006**: Produce a versioned IPA artifact with source/build metadata and a SHA-256 checksum, and download it into `ipa/` when remote access is available.
- **FR-007**: Preserve all unrelated working-tree changes.

### Key Entities

- Build configuration: public HTTPS management URL, app identifier, display version and build number.
- Artifact: IPA name, source commit, signing state and checksum.
- Session: existing server-managed admin session, retained by the platform website store and revoked by existing logout.

## Success Criteria

- **SC-001**: A successful clean build produces exactly one valid IPA for the management app.
- **SC-002**: Opening the app always starts at the management entry point.
- **SC-003**: No admin password, signing secret or business database is shipped in the package.
- **SC-004**: The owner can download the output from Windows and locate it under `ipa/`.

## Assumptions

- iOS 15 or later; online management service is required.
- A package prepared for sideload signing satisfies the initial IPA request; App Store distribution and APK implementation are separate work.
- The existing management UI may run inside the native app's embedded browser; no rewrite of business screens is requested.
- Remote CI needs a GitHub connection with access to this repository.
