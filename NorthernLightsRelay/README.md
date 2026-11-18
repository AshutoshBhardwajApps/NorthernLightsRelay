# Northern Lights Relay

A new SwiftUI + SpriteKit iOS game project bootstrapped with the reusable app patterns from `iOSAppTemplate`.

## Current prototype

Drag left or right to steer through the ice gates. The run speeds up as gates are cleared. Personal best, puck unlocks, daily gate goal, and day streak are saved locally. A soft ambient loop, rising gate chime, and milestone chime are included; music and effects can be toggled independently on the home screen.

## Project notes

- The game uses a bundled moon and tinted puck sprite, plus bundled ambient music and chimes.
- Settings persistence follows the template's `SettingsStore` pattern.
- AdMob is intentionally not wired yet. Before adding it for a release, follow `ADS_INTEGRATION.md` and supply this app's own AdMob app and unit IDs.
- Repository: https://github.com/AshutoshBhardwajApps/NorthernLightsRelay
