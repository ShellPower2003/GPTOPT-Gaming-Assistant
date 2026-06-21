# Halo Infinite Baseline Settings

**Purpose**

Halo Infinite offers many video settings. This baseline targets competitive play at 4K, focusing on smooth frame rates and clear visuals.

**Resolution and scale**

Set the game’s resolution to match your display (for example **3840×2160** for 4K). The *Internal Resolution Scale* controls the 3D render resolution; keeping it at **100 %** renders at the full display resolution for crisp images【207572641775391†L129-L145】. Lowering this scale upscales internally and can improve performance but reduces clarity.

**Frame-rate limits**

Halo Infinite allows minimum and maximum frame-rate settings. Set the **Maximum Frame Rate** equal to your monitor’s refresh rate: 240 FPS for a 240 Hz monitor or 144 FPS for a 144 Hz monitor. The **Minimum Frame Rate** option triggers dynamic resolution scaling when the frame rate drops; use this to maintain a consistent 60 FPS if your hardware struggles【947360535211836†L478-L493】. Disable V‑Sync for the lowest input latency and let your monitor’s variable refresh handle tearing【207572641775391†L147-L150】. For precise capping, use RTSS (see `rtss-halo-240.md`).

**Graphics quality**

Start with the *High* or *Medium* preset and adjust:

- **Reflections** and **Shadow Quality:** Lower these for the biggest performance gain【947360535211836†L556-L558】.
- **Volumetric fog**, **wind**, and **flocking:** Reducing these simulation effects improves performance on large maps【947360535211836†L524-L527】.
- **High‑resolution texture pack:** This optional pack may hurt performance on older GPUs. Users report large gains from disabling it, though some tests found no benefit【947360535211836†L566-L580】. Disable it via the DLC settings in Steam or the Xbox app【947360535211836†L582-L595】.

**HUD and FOV**

Set **Field of View (FOV)** to personal preference; values around **95–105** are common. Higher FOV increases peripheral vision but may reduce performance and cause distortion.

**Why it matters**

Keeping resolution scale at 100 % and capping the frame rate to your monitor’s refresh rate avoids unnecessary work for the GPU. Reducing heavy effects improves frame-time consistency, making it easier to track targets. Establishing a baseline makes it easier to measure the impact of future tweaks.

**Rollback plan**

All Halo Infinite settings can be reverted in the video menu. To fully reset, delete or rename the `Settings` folder in `%LOCALAPPDATA%\\HaloInfinite`.

**Advanced details**

Halo Infinite’s dynamic resolution is separate from reconstruction techniques like DLSS; scaling down resolution reduces sharpness. On 240 Hz monitors you may want to cap slightly below refresh (e.g. 237 FPS) to stay within the VRR window. Performance varies across different maps【947360535211836†L496-L525】; adjust settings if you play mainly outdoor missions.
