---
title: Flydigi controller stack
---

# Flydigi controller stack

**Purpose**\

The “Flydigi controller stack” describes the combination of the Flydigi controller hardware (and its dongle) with the Flydigi Space Station software.  
The software acts as a configuration hub for the controller — it updates firmware, remaps buttons, adjusts trigger sensitivity and provides macros.  
Keeping both the controller and the software active ensures that these features work correctly.

## Steps

1. **Download the correct Flydigi Space Station** from Flydigi’s support site.  A guide notes that you should pick the version that matches your controller (e.g., Vader 2, Apex, etc.) and install it before connecting the controller【787845839248392†L117-L149】.  
2. **Connect the controller via USB or the Flydigi dongle** for the first setup.  The same guide recommends connecting over USB or the wireless dongle when first using the software so that the device can update firmware and calibrate properly【787845839248392†L145-L156】.  
3. **Update firmware and configure buttons** using Flydigi Space.  Firmware updates improve stability and may enable new features.  Once updated, adjust stick sensitivity, dead‑zones, trigger travel and remap buttons to your preferred layout.  Save the profile to the controller.
4. **Leave Flydigi Space running** in the background while playing.  The software keeps macros, paddles and haptics active.  Closing it can revert the controller to basic XInput mode.
5. **Prefer the Flydigi dongle for wireless play.**  The dongle uses a high‑rate 2.4 GHz link (125 Hz or 500 Hz, depending on model) that reduces latency compared with Bluetooth.  For competitive shooters the dongle provides more consistent input timing.

## Reasons

- **Initial setup requires the Flydigi software.**  Downloading the correct Space Station version and connecting over USB/dongle allows the device to receive firmware updates and calibrate properly【787845839248392†L117-L149】【787845839248392†L145-L156】.
- **Macros and remappings live in software.**  Without Flydigi Space running, paddles and macros may stop working.  Keeping the application open in the background ensures that the mapped functions remain active.
- **Wireless stability.**  The dongle uses a dedicated wireless protocol with a higher polling rate than Bluetooth.  This reduces input latency and provides a steadier connection.

## Rollback / disable

- To **revert to default behaviour**, close Flydigi Space Station.  The controller will operate as a standard XInput device without macros or custom profiles.  
- To **undo firmware updates**, connect the controller to Flydigi Space and choose the previous firmware version if available.  If you encounter stability issues, you can reset the controller to factory defaults using the reset button (refer to the device manual).  
- To **remove wireless drivers**, unplug the dongle and uninstall the Flydigi drivers from Device Manager.  You can then switch to a wired connection.
