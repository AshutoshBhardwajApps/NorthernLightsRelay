# Asset brief: Fox Fires

This replaces the earlier lantern-and-arches brief. Do not make `Lantern`, `ArchBlock` or `ArchPost`.

**Story:** in Finnish folklore the aurora is *revontulet*, "fox fires": a fox's tail sweeps sparks into the sky. Each night one fox runs from dusk to dawn, then passes its fire to the next. The player is tonight's fox.

**Look:** original, calm and painterly, with soft shapes, few details and no harsh outlines. The view is up into the night sky: the fox is seen **from above, running up the screen with its nose at the top**. Nothing may flash or flicker.

Pull the latest `main` first. Please don't change Swift code: the game uses each image automatically once it exists under the exact name below, and draws a placeholder until then. Every image is a PNG in its own image set in `NorthernLightsRelay/Assets.xcassets`, in the 3x slot, with a transparent background unless noted.

| Image set | Pixels | What it is |
|---|---|---|
| `Fox1` to `Fox6` | 153 × 204 each | Run cycle, six frames, nose at the top |
| `FoxPortrait` | 480 × 696 | The same fox with its full bushy tail, for menus and the story |
| `CloudBank` | 1380 × 162 | Left-hand cloud bank; the game mirrors it for the right |
| `FallenStar` | 96 × 96 | Four-point soft star, white |
| `Moon` (replace) | 552 × 552 | Softer, flatter painted moon |
| `AppIcon` | 1024 × 1024, opaque | Fox running up under an aurora, no text |

## Fox
- White to very pale blue-grey; the game tints it per fox (cyan, green, violet, amber).
- It shows at only 51 × 68 points, so use a bright, simple silhouette: pointed snout, wide-set ears, slim body. It must not read as a cat.
- **No tail and no glow on `Fox1` to `Fox6`.** The game draws both, with the tail starting at the bottom centre.
- Keep the body centred and the same size in every frame. Only the legs and a slight body bob move. Frame 6 loops into frame 1.

## Cloud bank
- Dark slate-blue storm cloud with a thin moonlit rim along the top, clearly visible against near-black navy.
- The **right end is the edge of the gap**: rounded, solid, reaching the right edge of the image. The left end runs off screen.
- Keep the solid core centred vertically, about 78 px tall. Soft puffs may reach the top and bottom.
- Do not design it to stretch; it is drawn at its own size.

## Audio (optional)
Replace in `NorthernLightsRelay/Resources`, keeping these names:
- `gate_chime.wav`: a soft, airy chime for clouds parting, 0.6 s or less, mono, 44.1 kHz. Its pitch is raised through a run.
- `milestone_chime.wav`: a warm shimmering swell, 1.5 to 2.5 s.
