# CapFrameX and PresentMon Guide

## Goal

Use the same route, same scene, same cap method, and same background conditions before comparing runs.

## Minimum capture discipline

- keep map / route constant
- keep refresh rate and sync method constant
- keep resolution scale constant
- keep overlays and background tasks controlled
- label each run clearly

## What to compare first

1. average FPS
2. 1% low
3. GPU utilization
4. frametime spike behavior
5. whether the result is repeatable

## Common bad comparison mistakes

- changing cap method and blaming a different setting
- changing sync method and calling it a render-scale result
- comparing a warm cache run to a cold cache run
- comparing different maps or routes

## Good conclusion style

- state what changed
- state what stayed constant
- state the most likely explanation
- state the next clean test
