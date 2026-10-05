# Releasing

The repository is prepared locally. No GitHub repository or public release has been created. Choose the repository under Ryan’s account, enable private vulnerability reporting, and push the reviewed source before distributing downloads. Do not invent a repository URL in installation instructions.

1. Complete the acceptance checklist with real provider accounts. Resolve compatibility failures and document supported CLI versions.
2. Update version and build number in Info.plist, the initialisation client version, the settings version and README. Add release notes in CHANGELOG.md.
3. Run `swift test` and the local app build. CI runs on macOS and must pass on the chosen repository.
4. Configure a Developer ID Application certificate in Keychain and a notarisation profile using `xcrun notarytool store-credentials`. Never commit credentials, private signing keys or exported certificates.
5. Set `SIGNING_IDENTITY` and `NOTARY_PROFILE` in your shell and run `./scripts/release.sh`. It builds both architectures, combines the executable, signs, notarises and staples the app and DMG, and creates a checksum. It does not upload or publish.
6. Verify signatures with `codesign --verify --strict` and assessment with `spctl --assess --type execute`. Test the downloaded DMG on a clean Mac, including Intel.
7. Create a draft GitHub release containing the DMG, checksum and truthful release notes. Review it before making it public. Replace the development-preview install section with the actual download link only after the release is public.

A future auto-updater needs a verified signed feed and trusted signing keys, rollback tests and a documented update policy. No updater is included in 0.1.0. The signing/notarisation script is provided but cannot be exercised without Ryan’s Apple Developer credentials.
