# NVIDIA Profile Strategy

This document is for explaining how GPTOPT should talk about NVIDIA profile tuning.

## Principles

1. Do not treat NVIDIA Profile Inspector settings as magic.
2. Change one class of setting at a time.
3. Keep a rollback path.
4. Validate with frametime data, not just average FPS.
5. Separate competitive / latency-focused tuning from visual-quality tuning.

## Useful response structure

When discussing a profile change, answer in this order:
- what the setting is
- what it can influence
- when it is likely to matter
- likely downside
- how to verify whether it helped
- how to roll it back

## Common buckets

### Latency / sync
- frame cap strategy
- driver-level sync choices
- VRR interaction
- game-level latency settings

### Texture / filtering
- anisotropic filtering
- LOD bias behavior
- texture filtering quality / optimization options

### Shader / threading / pipeline behavior
- shader cache behavior
- threaded optimization implications
- per-game quirks vs global settings

## Rules for GPTOPT

- Prefer game-specific profiles over broad global changes when possible.
- If the game already exposes a setting cleanly, start there before using profile-level overrides.
- Avoid recommending aggressive overrides without saying what they may break.
- If a user is chasing competitive feel, prioritize consistency and frametime stability over raw visual upgrades.

## What to add later

- example `.nip` presets
- game-specific profile notes
- validation checklists for common sync combinations
