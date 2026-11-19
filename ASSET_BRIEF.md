# Asset brief — Phase 1 (lantern & aurora)

The game's story is now: **you carry the last lantern light across the frozen north. Each ice arch you pass sends light into the sky and wakes the aurora again.** The look stays calm, flat and easy on the eyes — soft gradients, no harsh outlines, no busy detail.

Please deliver the files below with these exact names. Code already handles colour tinting, glow and animation, so art should be **neutral/white-ish where noted** so it can be tinted per spirit.

## 1. Lantern orb — replaces `Puck`
- File: `Assets.xcassets/Lantern.imageset/Lantern.png` (single scale, 3x)
- Size: **192 × 192 px**, transparent background, orb centred, filling ~80% of the canvas.
- Look: a soft **glowing light orb / small lantern flame**, bright centre fading to the edge. **Light and near-white** (the current puck is too dark on the dark ice). The game tints it per spirit (cyan, green, violet, amber) and adds its own halo, so no outer glow needed.
- Shown on screen at ~33 pt diameter, so keep it simple — reads as "a light", not detailed.

## 2. Ice arch segment — replaces the flat gate bars
- File: `Assets.xcassets/ArchBlock.imageset/ArchBlock.png` (3x)
- Size: **120 × 54 px** (40 × 18 pt), transparent background.
- Look: a horizontal **bar of frosted ice / carved ice stone**, rounded ends, subtle top highlight. Pale ice blue, mostly flat.
- It is stretched horizontally with 9-slice scaling: **keep the left and right 30 px (the rounded ends) distinct, and the middle 60 px plain and repeatable** (no details that look wrong when stretched).

## 3. Arch end posts (optional, nice to have)
- File: `Assets.xcassets/ArchPost.imageset/ArchPost.png` (3x)
- Size: **36 × 72 px**, transparent. A small upright ice pillar / standing stone that sits at each side of the opening. Pale, neutral, tintable.

## 4. App icon
- File: `Assets.xcassets/AppIcon.appiconset/` — **1024 × 1024 px**, no transparency.
- Look: dark night-blue sky, a single glowing lantern orb low in the frame, soft green/violet aurora band above. Minimal, no text.

## 5. Audio (optional polish)
- `Resources/arch_pass.wav` — a soft, warm chime (≤ 0.6 s), slightly brighter than the current `gate_chime.wav`. Mono, 44.1 kHz.
- `Resources/aurora_swell.wav` — a gentle shimmering swell (1.5–2.5 s) for when an aurora band fully lights. Quiet, no sharp attack.

## Not needed
- Gate lanterns, trail, halo, aurora bands, sky colours, stars — all drawn in code.
- Text/fonts.

Once the files are in the repo, Claude wires them in (switching `Puck` → `Lantern`, blocks → `ArchBlock`).
