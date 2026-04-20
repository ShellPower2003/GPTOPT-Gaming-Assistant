# Windows Graphics Baseline

Use this as a baseline reference before making graphics-related Windows changes.

## Baseline questions

- What is the exact Windows build?
- Is HAGS at the intended state?
- Is MPO at the intended state?
- Is VRR enabled where expected?
- Are overlays and capture tools controlled and known?
- Is the power plan intentional?
- Is the test being run with a fixed route and repeatable scenario?

## Safe operating order

1. Confirm the game settings and frame-cap method.
2. Confirm display / VRR / sync behavior.
3. Confirm driver/profile choices.
4. Only then consider Windows graphics registry changes.

## Registry-related cautions

- A registry value being present does not automatically mean it is best.
- Default / not set can be the correct state.
- One change at a time is easier to verify than stacked tweaks.

## Validation checklist

- average FPS
- 1% low
- GPU utilization
- visible or felt frametime spikes
- input feel consistency
- reproducibility across multiple runs
