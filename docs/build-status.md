# Build status · 4 October 2026

- Native Apple Silicon release build: passed, Swift 6.2.4.
- Local development app signature: verified with codesign.
- Nine quota/freshness/advice regression cases: passed through the standalone runner using the same source as XCTest tests.
- Three simulated Codex connector scenarios: passed (handshake/home/path handling, stalled process deadline, refused initialisation).
- Application metadata and shell script syntax: validated.
- Native SwiftUI light/dark demo: rendered and visually inspected. These PNGs are illustrative readings, not connected-account data.
- Live Codex/Claude account acceptance: not run.
- macOS 13, Intel, VoiceOver, login-item and clean-machine acceptance: pending.
- Developer ID signing, notarisation and distribution release: pending; requires Ryan’s Apple credentials and acceptance checks.
- GitHub publication and automatic updates: not configured.

The provided local app is a development preview. The source, setup documentation, CI and release scripts are prepared for further acceptance and release work. Do not describe it as a finished public production release yet.


## 0.1.1 update

Header removed; refresh moved to the bottom; 360-point compact panel. Native light/dark demos render both Codex and Claude’s two quota windows in the first view without scrolling. Five additional simulated sign-in checks passed: structured Codex browser flow and matching completion, HTTPS provider-host validation, deadline cleanup, pre-launch cancellation, and Claude optional-code handoff. Portal code is implemented, but genuine provider browser login is not yet verified. A later investigation found the native Claude helper downloaded by Claude Desktop; it was missing from executable discovery in 0.1.1.

## 0.1.2 investigation

Found and successfully ran `auth login --help` on the actual Claude Desktop native helper (2.1.286). Executable discovery now scans its versioned native folder, with regression checks for numeric version ordering and missing installations. Browser sign-in still requires the user to complete the real provider authentication; this is not claimed as a live login acceptance pass.
