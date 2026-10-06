# KSHR as a maintained fork of cmux — plan (2026-10-06)

Goal: KSHR = current cmux (v0.65.0, Oct 5 2026) with KSHR branding, built and
signed with David's Developer ID (team X9YF2BH97P), notarized, released from
github.com/davidacimovic/kshr so Sparkle updates work, and mergeable with every
upstream release. Decided with David on Oct 6 2026 (session 23b88de2).

## Facts that shape it

- KSHR 0.63.1 (yosefkohan26/kshr) is a one-commit rename of cmux 0.63.1; the
  local checkout ~/Desktop/Dev/kshr has three small commits on
  `fix/terminal-renderer-stalls` (May–Jun) that upstream has since covered.
  It stays untouched. The fork lives in ~/Desktop/Dev/kshr-next
  (origin = davidacimovic/kshr, upstream = manaflow-ai/cmux).
- Upstream release flow: `scripts/build-sign-upload.sh <tag>` = GhosttyKit
  (zig) → `xcodebuild -scheme cmux -configuration Release CODE_SIGNING_ALLOWED=NO`
  → Sparkle key injection → `scripts/sign-cmux-bundle.sh` (inside-out, hardened
  runtime) → notarize app + DMG (`create-dmg`) → `scripts/sparkle_generate_appcast.sh`
  → `gh release create <tag> cmux-macos.dmg appcast.xml`.
- Upstream signs with an embedded Developer ID provisioning profile that grants
  restricted entitlements (network extension + system extension for the Cloud
  tunnel, web-browser passkeys, keychain-access-groups, application-groups).
  `sign-cmux-bundle.sh` supports no profile: `reconcile-entitlements-with-profile.py
  --no-profile`, and it deletes Contents/Library/SystemExtensions when the
  entitlements do not request the tunnel. KSHR does not use cmux Cloud, so KSHR
  ships without the tunnel and without the restricted keys.
- GhosttyKit: `scripts/ensure-ghosttykit.sh` downloads the prebuilt
  xcframework from manaflow-ai/ghostty releases keyed by the submodule sha with
  pinned checksums; no zig build needed unless the prebuilt is missing
  (zig 0.16.0 is installed as a fallback).
- Build phases need: Xcode 26.6 + Metal toolchain (present), rustup toolchain
  1.88.0 with aarch64+x86_64 targets (Native/DiffSidecar/rust-toolchain.toml;
  installing), Go (1.26.5 present, Release builds require it), bun 1.3.7
  (present), create-dmg (installed).
- Signing identity: `Developer ID Application: David Acimovic (X9YF2BH97P)`,
  hash 57B8DAD2045B4073DEF92144166DDBE8C2DCE503.
- Sparkle: EdDSA seed generated Oct 6, stored in the login keychain as generic
  password service `kshr-sparkle-private` (account $USER); public key
  `uiu/kvTCl212paY8vTdE4C3eEZd/QKrYl1jZoChPH8U=`.
- Notarization: needs `xcrun notarytool store-credentials kshr-notary
  --apple-id <developer Apple ID> --team-id X9YF2BH97P` once, typed by David
  (app-specific password). Until then the release script stops before
  notarization and leaves a signed, unnotarized KSHR.app for local use.

## Branding commit (kept tiny so upstream merges stay clean)

1. `cmux.xcodeproj/project.pbxproj`: app target release config
   `PRODUCT_BUNDLE_IDENTIFIER = com.kshrterm.app` (one line). Product name stays
   `cmux` (executable + helper paths unchanged); the bundle folder and the
   display name are renamed at release time.
2. Icons: replace `AppIcon.icon/` and `Assets.xcassets/AppIcon.appiconset`,
   `AppIconDark.imageset`, `AppIconLight.imageset` with KSHR's (binary, from
   yosefkohan26/kshr).
3. `kshr.entitlements`: `cmux.entitlements` minus `keychain-access-groups` and
   `com.apple.developer.web-browser.public-key-credential`.
4. `scripts/kshr-release.sh <tag>`: the upstream script with KSHR values:
   prebuilt GhosttyKit, our identity hash, `kshr.entitlements`, single-pass
   signing (`CMUX_SIGN_MODE=all`), Info.plist CFBundleName/DisplayName = KSHR,
   bundle renamed to KSHR.app, SUFeedURL = davidacimovic/kshr latest appcast,
   SUPublicEDKey ours, notarization via `--keychain-profile kshr-notary`,
   DMG `KSHR-macos.dmg`, appcast with our download URL, `gh release` on our
   fork (GH_REPO), no Homebrew cask. Secrets: Sparkle private key read from the
   keychain at run time, never a file.
5. `README-KSHR.md`: what differs from cmux and the release procedure.

Tags: `kshr-v<upstream version>[-N]` so upstream `v*` tags never collide.

## Steps

1. Clone (running) → `git remote add upstream`, branch `kshr` from v0.65.0.
2. Toolchain: rustup 1.88.0 + targets; `scripts/ensure-ghosttykit.sh`.
3. Branding commit (above).
4. Local build: `scripts/kshr-release.sh --build-only` → KSHR.app, signed,
   launched once, CLI ping, Desktop read from a tab, Files & Folders row named
   KSHR, `codesign -dvv` shows our team and `spctl` accepted after notarization.
5. Push branch + tag; first release `kshr-v0.65.0`; install from the DMG over
   /Applications/cmux.app; verify Sparkle sees the feed (`SUFeedURL` reachable).
6. cc-spawn / cc-takeover: add the KSHR CLI path for the new app
   (`/Applications/KSHR.app/Contents/Resources/bin/cmux`) ahead of cmux.
7. Document the upstream-merge routine: `git fetch upstream && git merge
   v0.66.0`, resolve branding conflicts (icons: ours), bump nothing, run the
   release script with the next tag.
