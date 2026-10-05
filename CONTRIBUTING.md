# Contributing

Use UK English. Follow the uploaded reference in `design/`; introduce no general green accent. Keep secrets out of fixtures and logs. Run `swift test` and `./scripts/build.sh` on macOS before sending a pull request. Add a regression test for changed quota semantics, process lifecycle or refresh behaviour. Explain the user-visible problem and provide a redacted reproduction.

Provider connectors must preserve bucket identity, represent unknown values explicitly, avoid changing accounts, bound requests and child processes, and retain the timestamp of the last successful reading on failure. Advice must state its trigger and never invent savings or entitlements. New private provider endpoints require clearly documented compatibility limits.
