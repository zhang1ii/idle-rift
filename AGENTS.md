# Idle Rift agent instructions

## Product sources of truth

- Read `PRODUCT.md` before changing game scope.
- Read `DESIGN.md` before changing visual direction or interaction patterns.
- Read `docs/GDD.md` before changing combat, loot, or progression rules.

## Sprite production

- Use `$generate2dsprite` for generated characters, enemies, equipment icons, projectiles, impacts, and combat FX.
- Read `docs/ASSET_PIPELINE.md` before generating or integrating sprite assets.
- Keep raw generations, extracted frames, preview GIFs, and rejected variants under `work/sprite-forge/`.
- Only approved runtime assets and their metadata belong under `assets/sprites/`.
- Do not replace an approved sprite with a newly generated variant without visual comparison at the real 640 × 360 gameplay camera.
- Character body actions and detached FX must be generated and integrated separately.
- Preserve bottom-center feet anchors and nearest-neighbor filtering.

## Verification

- Run `godot --headless --path . --script res://tests/test_combat.gd` after combat or equipment changes.
- Run the game and inspect a real 1280 × 720 capture after visible UI or sprite changes.
