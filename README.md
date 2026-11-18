# Northern Lights Relay

A new SwiftUI + SpriteKit iOS game bootstrapped with reusable patterns from `iOSAppTemplate`.

## Current prototype

Drag left or right to steer through the ice gates. The run speeds up as gates are cleared. A personal best is saved locally.

## Website and repository setup

Root-level `index.html`, `privacy_policy.html`, and `app-ads.txt` follow the static GitHub Pages layout used by CoopHockey. Once a GitHub repository exists, publish Pages from the `main` branch root.

## Project notes

- The first playable slice uses generated SpriteKit shapes and requires no bundled art or audio.
- Settings persistence follows the template's `SettingsStore` pattern.
- AdMob is not wired yet. Before adding it for a release, follow `ADS_INTEGRATION.md` and supply this app's own AdMob app and ad unit IDs.
- GitHub authentication is currently unavailable, so no remote repository or published site is connected.
