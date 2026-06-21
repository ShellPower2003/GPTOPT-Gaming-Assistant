---
title: Background load
---

# Background load

**Purpose**\

“Background load” refers to the cumulative impact of programs and services running while you play a game.  Heavy background activity can eat CPU cycles, memory and disk I/O, leading to higher frame‑time variance and latency.  This file outlines methods to reduce background load without sacrificing essential tools like Flydigi and Sonar.

## Keep essential software running

- **Flydigi Space Station**: Leave the controller software running to maintain firmware, button mapping and haptic feedback (see Flydigi controller stack).
- **SteelSeries Sonar**: Keep Sonar active to manage separate game/chat audio channels【226591225636271†L106-L113】.
- **Antivirus and security software**: Do **not** disable Windows Defender or your antivirus – they protect your system.  Instead, schedule scans outside gaming sessions.

## Reduce unnecessary startup and background tasks

1. **Enable Game Mode**.  Windows Game Mode prioritises games and reduces background processes【386358036261583†L173-L231】.  Turn it on under *Settings → Gaming → Game Mode*.
2. **Use a High performance or Ultimate performance power plan**.  Select these in *Power Options* to prevent the CPU from down‑clocking during gameplay【386358036261583†L173-L231】.
3. **Manage startup apps with Sysinternals Autoruns**.  The XDA guide recommends using *Autoruns* to see all programs and scheduled tasks that start with Windows and disabling those you do not need【386358036261583†L173-L231】.  Focus on heavy apps like cloud‑sync clients, update services and RGB software; leave system drivers enabled.
4. **Uninstall bloatware and disable unused services**.  Scripts like “Win11Debloat” can remove pre‑installed apps and scheduled tasks that consume resources【386358036261583†L270-L287】.  Use them cautiously and create a restore point before running.
5. **Disable virtualisation features**.  If you don’t need virtual machines, turn off Hyper‑V and Virtual Machine Platform【386358036261583†L242-L258】.  Virtualisation can reserve resources and sometimes interferes with anti‑cheat systems.

## When to ignore background load

- **Browsers or chat clients**: Some games require reading guides or watching streams; a single browser tab (e.g., Chrome or Firefox) usually doesn’t cause significant load.  The baseline calls for ignoring Firefox when assessing background load.
- **Critical drivers and overlay software**: Do not close GPU control panels, audio drivers or Overwolf‑like overlays if they’re necessary for anti‑cheat or capturing highlights.

## Rollback / restore

- Re‑enable startup items in Autoruns by re‑checking them or reinstalling the software.  
- Switch back to the **Balanced** power plan to save energy.  
- Turn off Game Mode or re‑enable disabled services if you notice instability.  
- Re‑enable Hyper‑V and Virtual Machine Platform if you need virtual machines【386358036261583†L242-L258】.

Reducing background load is a balancing act: you want to free CPU and memory for your game while keeping necessary tools (controller/voice software, security, overlays) active.  Use a process viewer to monitor CPU usage; disable only items you recognise and have a restore point ready.
