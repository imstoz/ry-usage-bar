# Architecture

Swift Package Manager, SwiftUI MenuBarExtra and Foundation. macOS 13 minimum. No third-party runtime dependencies. Design colours map directly to the uploaded light/dark tokens through appearance-aware native colours.

Each named account has an immutable UUID and a provider-owned home. Its saved reading is keyed by UUID, not by display name. Failed requests preserve the previous snapshot and publish a separate error. Deleted-account requests cannot restore deleted data. Profiles persist atomically; storage failures are visible. Cached snapshots are unverified until a successful fetch. A reading also becomes stale after ten minutes or once any reset passes.

Codex starts a bounded app-server process on a background task, waits for initialise success, sends initialized and reads rate limits. It uses direct Process arguments, never a shell. Stderr is discarded to avoid exposing provider credentials. Unsolicited server requests are rejected. Output is capped at 2 MB and a watchdog bounds process life. Mapped quota buckets take precedence over legacy data; ids include bucket and slot.

Claude reads its existing credential in a background task, then makes an ephemeral HTTPS request to a fixed endpoint. No cookies or redirects. Tokens never reach persistence or UI. Expired credentials require renewal by Claude Code. Missing and negative usage values become unknown; over-limit values preserve the used figure and clamp remaining quota to zero.

The app refresh coordinator coalesces concurrent requests per account and throttles retries. Accounts refresh independently. Advice is deterministic local logic and has no network dependency. It suppresses recommendations on stale readings and failed requests. Settings never select a provider model or modify its account.

Before release, exercise lifecycle, provider authentication and Keychain flows on actual supported Macs; core fixture tests cannot prove live integrations work. The current preview does not have Grok/Kimi, Claude switching, notifications, background OAuth renewal or automatic updates.


Browser sign-in is user-initiated. A separate native progress window stays open when the menu panel loses focus. Codex initialises the app server, starts `account/login/start` with ChatGPT auth, opens an allowlisted HTTPS portal URL and waits for a successful completion with the matching login ID. Claude invokes its `auth login` command, offers the printed allowlisted portal URL as a browser-opening fallback, forwards an optional code through stdin and waits for successful exit. Login output is never logged or shown verbatim. Sessions are cancellable, bounded to ten minutes and capped at 2 MB of output. No inference is performed. Codex uses an isolated home; Claude explicitly uses its default login because custom Keychain naming is not yet supported.
