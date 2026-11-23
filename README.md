# Northern Lights Relay

A new SwiftUI + SpriteKit iOS game bootstrapped with reusable patterns from `iOSAppTemplate`.

## Current prototype

Fox Fires: drag left or right to steer a spirit fox through gaps in the storm clouds. Its tail paints the aurora, and the run speeds up as clouds are parted. Personal best, puck unlocks, daily gate goal, and day streak are saved locally. A soft ambient loop, rising gate chime, and milestone chime are included; music and effects can be toggled independently on the home screen.

## Website and repository setup

Root-level `index.html`, `privacy_policy.html`, and `app-ads.txt` follow the static GitHub Pages layout used by CoopHockey. GitHub Pages publishes from the `main` branch root.

## Run on iPhone

Clone this repository, open `NorthernLightsRelay/NorthernLightsRelay.xcodeproj`, select the `NorthernLightsRelay` scheme and your connected iPhone, then press **Run**. If Xcode requests signing, choose your Apple development team in the target's **Signing & Capabilities** settings. The project targets iOS 17 or later.

## Project notes

- The game uses a bundled moon and tinted puck sprite, plus bundled ambient music and chimes.
- Settings persistence follows the template's `SettingsStore` pattern.
- AdMob is not wired yet. Before adding it for a release, follow `ADS_INTEGRATION.md` and supply this app's own AdMob app and ad unit IDs.
- Repository: https://github.com/AshutoshBhardwajApps/NorthernLightsRelay (GitHub Pages enabled on `main`).
