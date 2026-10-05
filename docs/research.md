# Reference review · 4 October 2026

## Functionality and distribution

[Project page](https://johnkueh.com/projects/usage-bar) and [repository](https://github.com/johnkueh/usage-bar) reviewed. The reference is a macOS 13+ native menu app, distributed as a universal, Developer ID signed and notarised DMG. Its compact bar follows Claude’s active account. The menu covers Claude, Codex, Grok and Kimi. Claude supports explicit account switching; the other providers are usage-only. Accounts are configured through existing provider logins or isolated homes. The README explains installation, authentication ownership, stale readings, five-minute refreshes, wake refreshes, source builds and local privacy.

Its release process combines universal compilation, Apple signing/notarisation and signed Sparkle updates delivered through GitHub release assets and an appcast. The repository has separate source, test, asset and script directories and an MIT licence. This is a useful distribution pattern to work towards, but ry cannot claim Apple notarisation or automatic updates until those pipelines are configured and tested.

## Observed source weaknesses

The reviewed [Usage.swift](https://github.com/johnkueh/usage-bar/blob/main/Sources/Usage.swift) is a cached public snapshot; these observations apply to that snapshot and are not proof of current user-facing failures.

- Claude missing utilisation is converted to zero. Unknown and unused quota must be different states.
- Codex collects legacy windows plus one preferred multi-bucket response, then deduplicates by duration. This can hide separate buckets with equal duration and omit additional model limits. ry uses the complete mapped response when available and preserves bucket/slot identifiers.
- Cached readings initialise as fresh without an age check. ry starts restored cache readings as unverified and retains their original timestamps.
- Kimi’s parser turns a non-positive limit into zero usage and recognises only a particular additional window shape. A future connector needs explicit unavailable states and general window handling.
- Grok relies on parsing terminal copy and a reset date without a year. This is fragile under CLI changes, localisation and year boundaries. Do not advertise it until a robust connector is verified.

The public issue page returned no readable issue reports in the cached response. No specific bug experienced by Ryan has been reproduced yet.

## Original ry direction

Ryan’s ZIP contains an HTML design reference and CSS/JSON token exports. Its authority is neutral white/near-black foundations, quiet editorial typography, system fonts, small optical spacing, thin borders, modest radii and selective blue/indigo/purple. Lowercase `ry` is the identity. No general green accent. The app adapts those ingredients to a compact native popover, rather than recreating the reference’s menu layout.

Remaining quota is the large figure; used quota stays explicit. Every window carries a reset and source-reading timestamp. Advice appears only when actionable, with its rule explained. A single sentence suggesting lighter settings is useful differentiation without a recommendation engine, speculative savings estimates or automatic account switching.

## Provider evidence

[Official Codex App Server documentation](https://learn.chatgpt.com/docs/app-server) describes newline-delimited JSON, the initialisation handshake, `account/rateLimits/read`, `rateLimitsByLimitId` and nullable window metadata. The installed Codex CLI’s generated protocol schema was also inspected. Claude’s endpoint and response shape were verified against the reference’s provider integration; this is explicitly a compatibility integration rather than a stable public API guarantee.
