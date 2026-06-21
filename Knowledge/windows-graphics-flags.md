---
title: Windows graphics flags
---

# Windows graphics flags

**Purpose**\

Modern versions of Windows expose several advanced graphics settings that can affect gaming latency and stability.  These include **Hardware‑Accelerated GPU Scheduling (HAGS)**, **Multi‑Plane Overlay (MPO)**, **Game Mode**, **power plans**, **windowed optimizations**, and virtualization features.  This file summarises each setting and offers guidelines on when to enable or disable them for competitive shooters.

## Hardware‑Accelerated GPU Scheduling (HAGS)

HAGS moves high‑frequency GPU scheduling tasks from a CPU thread to a dedicated hardware scheduler on the GPU【559766697053951†L64-L84】.  GPU vendors state that this can *reduce latency* and improve smoothness, but benchmarks show that gains are small or even negative for some games【559766697053951†L79-L83】【559766697053951†L117-L123】.  

- **How to enable**: Go to *Settings → System → Display → Graphics → Default graphics settings*.  Toggle **Hardware‑accelerated GPU scheduling** to *On*.
- **Recommendation**: Leave HAGS **Off** by default.  Enable it only if you experience input lag and have a modern GPU (RTX 20‑series or newer), and test thoroughly.  If you see performance drops or stuttering, disable it again.

## Multi‑Plane Overlay (MPO)

MPO allows the GPU to compose multiple image layers independently before sending them to the display, which improves power efficiency and smooths frame delivery【873017464483515†L89-L114】.  However, some monitors and games exhibit flickering or black‑screen issues when MPO is enabled.

- **How to disable**: NVIDIA provides registry files to disable or restore MPO【873017464483515†L89-L114】.  To disable, download the “Disable_MPO.reg” file and merge it; to re‑enable, use “Enable_MPO.reg.”  Restart your PC after applying the change.
- **Recommendation**: Keep MPO **enabled** unless you encounter flickering or stutter.  If issues appear, apply the disable reg file.  Always back up the registry first (see Backup and rollback) before merging registry files.

## Game Mode and power plans

Windows **Game Mode** directs more CPU/GPU resources to games and reduces background processes.  The XDA optimisation guide suggests enabling Game Mode and using a **High performance** or **Ultimate performance** power plan for better CPU responsiveness【386358036261583†L173-L231】.  

- **How to enable**: Go to *Settings → Gaming → Game Mode* and toggle it *On*.  Then search for “Power Plan,” open *Choose a power plan* and select **High performance** or **Ultimate performance** (if available)【386358036261583†L173-L231】.
- **Recommendation**: Enable Game Mode and High/Ultimate performance plan for competitive shooters.  They ensure the CPU runs at maximum clocks and background services are deprioritised.  Some games may run hotter; monitor temperatures.

## Windowed optimizations and Variable Refresh Rate (VRR)

Windows 11 adds a **“Optimisations for windowed games”** toggle under *Graphics → Default graphics settings*.  This option leverages flip‑model presentation in windowed or borderless modes and can improve frame rates and reduce input lag【386358036261583†L197-L204】.  VRR ensures tear‑free gameplay on monitors with FreeSync/G‑Sync.

- **How to enable**: Go to *Settings → System → Display → Graphics → Default graphics settings* and enable **Optimisations for windowed games** and **Variable refresh rate**.  Restart the game.
- **Recommendation**: Enable both if your monitor supports VRR; otherwise leave them off.

## Virtualisation features (Hyper‑V, Virtual Machine Platform)

Virtualisation features are used for running virtual machines.  Enabling them can add overhead and sometimes reduces gaming performance.  The XDA guide recommends disabling **Hyper‑V** and **Virtual Machine Platform** when not in use【386358036261583†L242-L258】.

- **How to disable**: Search for *“Windows features”*, open *Turn Windows features on or off*, and un‑check **Hyper‑V** and **Virtual Machine Platform**【386358036261583†L242-L258】.  Reboot.  Note: disabling Hyper‑V will also disable the Windows Subsystem for Linux (WSL) and other virtualisation services.
- **Recommendation**: Disable if you do not run virtual machines.  Re‑enable them via the same Windows Features dialog if needed.

## Summary

| Setting | Default | When to Enable | When to Disable |
| --- | --- | --- | --- |
| **HAGS** | Off | Test on modern GPUs if you want lower latency【559766697053951†L64-L84】 | If performance drops or stutters【559766697053951†L117-L123】 |
| **MPO** | On | Keep enabled for power efficiency【873017464483515†L89-L114】 | Disable via reg file if flicker/stutter occurs |
| **Game Mode** | Off (sometimes) | On for games to prioritise resources【386358036261583†L173-L231】 | Disable if it causes issues |
| **High/Ultimate power plan** | Balanced | On to keep CPU at max clocks【386358036261583†L173-L231】 | Use Balanced if power/heat is a concern |
| **Windowed optimisations & VRR** | Off | Enable if using borderless/windowed and your monitor supports VRR【386358036261583†L197-L204】 | Disable if you encounter screen tearing or if monitor doesn’t support VRR |
| **Virtualisation features** | Enabled on some systems | Disable for maximum gaming performance【386358036261583†L242-L258】 | Enable if you need virtual machines or WSL |

Always back up the registry and create a restore point before changing registry-based settings (see Backup and rollback).  If an optimisation causes instability or micro‑stutter, revert to the defaults.
