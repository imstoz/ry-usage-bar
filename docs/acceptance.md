# Acceptance checklist

Automated core tests cover multi-bucket Codex precedence, equal-duration bucket identity, missing values, over-quota clamping, invalid responses, model-specific Claude windows, reset expiry, cached timestamps and advice gating. Three simulated connector checks also verify the process handshake and paths with spaces, failed initialisation, and stalled-process timeout. Run them with `./scripts/test-connectors.sh`. These are separate from live integration acceptance.

Before a public release:

- Build and open on macOS 13 and current macOS, in both light and dark appearance.
- Check keyboard focus, ⌘R, VoiceOver reading order, text scaling and popover placement.
- Test first launch, demo label, connecting/removing accounts, persisted settings and login-item approval.
- Test Codex and Claude portal sign-in, browser opening, callback success/failure, cancellation, optional Claude code and timeout. Confirm no account appears until sign-in succeeds.
- Confirm both Codex and Claude cards fit in the first view of the compact demo.
- Use a real Codex ChatGPT login, separate CLI home and desktop executable; verify every returned bucket.
- Use real Claude Keychain and file credentials; test access denial, expired token and sign-in renewal.
- Disconnect the network; confirm the last reading retains its timestamp and advice is hidden.
- Sleep/wake; check refresh resumes and no duplicate requests occur.
- Hold a provider process open without replying; verify timeout and subprocess cleanup.
- Leave the popover closed for ten minutes; confirm polling continues and stale pinned values disappear.
- Remove an account during refresh; confirm it stays removed.
- Compare equal-duration model quotas against the provider response.
- Test the signed, notarised universal DMG on a clean Apple Silicon and Intel Mac.

Do not call the preview production-ready until these checks pass. No live provider acceptance tests have been run in this session.
