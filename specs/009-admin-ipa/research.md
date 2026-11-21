# Research: HOÀN Admin IPA

- Decision: UIKit/WKWebView loads the existing HTTPS management UI at `/?mobile=1&native=ios#/admin`, reusing `public/mobile-admin.js` and keeping frontend/API cookies on the same origin. No third-party native dependency.
- Decision: persistent default WKWebsiteDataStore, exact HTTPS origin navigation and native JavaScript-dialog delegates. External user links open through the system. No privileged JavaScript bridge or TLS bypass.
- Decision: XcodeGen, a macOS Actions runner, clean xcodebuild output, validated unsigned IPA and checksum.
- Decision: compile icon renditions with macOS sips from the existing opaque H PNG; preserve the design source.
- The existing repository URL `https://hoan-makeup-artist.hoan-makeup.workers.dev/` responds HTTP 200, but `/api/admin-session` returns 404. Backend-version compatibility must be recorded separately from compilation, and the build URL is configurable.
- No usable GitHub credential was found; connection was suggested. Remote compilation is only complete after an authenticated run succeeds.

Sources: [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview), [persistent store](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/default()), [XcodeGen](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md), [macos-15](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md), [Husk](https://github.com/Leviidev/Husk/blob/main/scripts/package_ipa.sh).
