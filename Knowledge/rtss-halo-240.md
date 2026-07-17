# RTSS Halo 240 FPS Cap

**Purpose**

Limiting the frame rate in Halo Infinite can improve frame pacing, reduce CPU/GPU power draw and fan noise, and prevent game physics from breaking at extremely high frame rates.  Frame‑rate capping provides smoother frame times, which is especially important when using a variable‑refresh‑rate monitor【598273801439488†L370-L384】.  External limiters like **RivaTuner Statistics Server (RTSS)** can be changed while the game is running and work with both Steam and Microsoft Store games【598273801439488†L395-L404】.

**Why cap at 240 FPS?**

For monitors with a 240 Hz refresh rate, limiting Halo Infinite to 240 FPS (or just below, e.g. 237 FPS) keeps your frame rate within the display’s VRR window.  It reduces the chance of the GPU rendering frames faster than the display can present them, which would cause tearing or forced VSync.  Halo Infinite’s built‑in limiter sometimes produces uneven frame pacing; using RTSS ensures a consistent cap and reduces micro‑stutter.  If you have a 144 Hz monitor, cap at 141 FPS; adjust the cap to ~3 FPS below your monitor’s maximum refresh rate.

**How to configure RTSS**【598273801439488†L545-L552】

1. **Install RTSS:** Download and install RivaTuner Statistics Server (RTSS).  It is bundled with MSI Afterburner but can be installed separately.
2. **Add Halo Infinite:** Launch RTSS and either select the global profile or add a new profile for the Halo Infinite executable.
3. **Set frame‑rate limit:** In the profile settings, set **Framerate limit** to your desired cap (e.g. `240`).  Setting it to `0` disables the limiter.  RTSS supports hotkeys to toggle the limiter on the fly【598273801439488†L560-L562】.
4. **Detection level:** Leave the *Application detection level* at its default (Low or Medium).  High detection levels can interfere with anti‑cheat systems.
5. **Launch the game:** Ensure RTSS is running in the background.  Start Halo Infinite and verify that the in‑game FPS stays near the cap.

**Why it matters**

Limiting the frame rate can reduce unnecessary rendering workload.  RTSS provides fine‑grained control that is independent of the game and driver settings and works even when the game’s internal limiter is inconsistent.  Stable frame pacing makes aiming and movement feel more responsive and reduces power consumption and heat【598273801439488†L370-L374】.

**Rollback plan**

To remove the cap, open RTSS and set **Framerate limit** to `0` or close RTSS entirely.  Frame rates will then be governed by Halo Infinite’s internal limiter or your GPU driver settings.

**Advanced details**

RTSS operates by inserting itself into the DirectX/Vulkan pipeline and delaying frame presentation until the specified interval has passed.  Because it runs in user space, there is a small overhead, and in some games it may add 1–2 ms of input latency.  For games with well‑implemented internal limiters you can instead use the in‑game cap, but Halo Infinite’s limiter is less consistent, so RTSS is recommended for competitive consistency.
