# KSHR

KSHR is cmux (https://github.com/manaflow-ai/cmux) built and signed by David
Acimovic, with the KSHR name and icon. Everything else is upstream cmux, so
the terminal, the sidebar, the `cmux` CLI, the Claude Code hooks, the config
file (`~/.config/cmux/cmux.json`) and the docs are cmux's. This fork exists so
the app can be signed with a stable Developer ID, kept current with upstream,
and shipped to the people who use it, under cmux's license (see LICENSE).

## What differs from cmux (branch `kshr`)

| Where | Change |
|---|---|
| `cmux.xcodeproj/project.pbxproj` | app bundle identifier `com.kshrterm.app` |
| `AppIcon.icon/`, `Assets.xcassets/AppIcon*` | KSHR icon |
| `kshr.entitlements` | `cmux.entitlements` without the Cloud-tunnel and passkey entitlements that need Manaflow's provisioning profile |
| `scripts/kshr-release.sh` | build, brand (`KSHR.app`, display name KSHR, our Sparkle key and feed), sign, notarize, DMG, appcast, GitHub release on this fork |
| `README-KSHR.md` | this file |

Not in KSHR: the cmux Cloud browser tunnel (a system extension that needs an
Apple-approved profile), passkeys in the embedded browser, the Homebrew cask.

## Releasing

One-time: a `notarytool` keychain profile and the Sparkle key.

```bash
xcrun notarytool store-credentials kshr-notary --apple-id <developer Apple ID> --team-id X9YF2BH97P
# Sparkle EdDSA seed lives in the login keychain: service kshr-sparkle-private.
```

Each release (tags are `kshr-v<upstream version>[-N]`, never upstream's `v*`):

```bash
./scripts/kshr-release.sh kshr-v0.65.0            # full: notarize + DMG + GitHub release
./scripts/kshr-release.sh kshr-v0.65.0 --build-only   # just a signed KSHR.app under build/
```

The app updates itself from
`https://github.com/davidacimovic/kshr/releases/latest/download/appcast.xml`.

## Installing a local build on this Mac

The bundle identifier is cmux's, so KSHR replaces cmux rather than running
beside it, and the old KSHR 0.63.1 (also `KSHR.app`) must be out of the way.

1. `./scripts/kshr-release.sh kshr-vX.Y.Z --build-only` leaves
   `build/Build/Products/Release/KSHR.app` (signed, not notarized; fine for a
   local launch, since nothing downloaded it).
2. Quit cmux and the old KSHR once their tabs are empty, then:
   `mv /Applications/KSHR.app ~/Applications/KSHR-0.63.1-old.app`,
   `brew uninstall --cask cmux` (or move cmux.app aside),
   `ditto build/Build/Products/Release/KSHR.app /Applications/KSHR.app`,
   `open /Applications/KSHR.app`.
3. Click Allow on the Desktop, Documents and Downloads prompts the first time a
   tab touches them: the grants are keyed to the new signature.
4. Re-open sessions with `cc-takeover.sh <session>` or `claudecode --resume`.

A notarized DMG from the full release script installs the same way, and
Sparkle keeps it current from then on.

## Taking an upstream release

```bash
git fetch upstream --tags
git merge v0.66.0          # keep ours for the icon files and the pbxproj bundle id line
./scripts/kshr-release.sh kshr-v0.66.0
```

Conflicts, when they happen, are confined to the five items in the table.

## Toolchain

Xcode 26 with the Metal toolchain, rustup toolchain 1.88.0 with the
`aarch64-apple-darwin` and `x86_64-apple-darwin` targets, Go, bun, zig (only
when no prebuilt GhosttyKit is pinned for the ghostty submodule), create-dmg,
gh. `./scripts/setup.sh` checks all of it.
