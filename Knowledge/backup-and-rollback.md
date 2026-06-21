---
title: Backup and rollback
---

# Backup and rollback

**Purpose**\

Editing the Windows registry, installing drivers or tweaking system services can improve gaming performance but also carries risk.  A misconfigured registry entry or bad driver can cause crashes or prevent Windows from booting.  This file explains how to create restore points and registry backups so you can safely undo changes.  It also summarises how to roll back each optimisation described in this knowledge base.

## Create a system restore point

Before making major changes (installing drivers, applying registry tweaks), create a **System Restore** point.  

1. Open the **Start** menu and type **“Create a restore point.”**  Click the match.  
2. In the *System Properties* window, select the system drive (usually C:) and click **Configure** to make sure protection is turned on.  Then click **Create…**.  
3. Enter a description (e.g., “before gaming tweaks”) and click **Create**.  Windows will save a restore point that you can roll back to【386358036261583†L141-L156】.

To restore, search for **“Recovery”**, select **Open System Restore**, and choose the restore point you created.  Follow the prompts to revert system files and settings.

## Export and import the registry

When applying registry tweaks (e.g., timer resolution fix or disabling MPO), export the registry before changing anything:

1. Press **Win + R**, type **regedit**, and press **Enter**.  
2. In the Registry Editor, select **Computer** at the top of the tree.  
3. Go to **File → Export…**, choose a location, select **All** under *Export range*, and save the `.reg` file【140979872007750†L141-L156】.  
4. After making changes, you can restore the registry by double‑clicking the backup `.reg` file or using **File → Import** in regedit【140979872007750†L160-L168】.

## Rolling back specific tweaks

- **Timer resolution fix**: If you added the `GlobalTimerResolutionRequests` DWORD to restore global timer behaviour, remove it or set it to `0` and reboot【646706303966671†L174-L181】.
- **MPO disable**: To restore MPO, merge the provided “Enable_MPO.reg” file【873017464483515†L89-L114】.
- **HAGS and Game Mode**: Revisit *Graphics settings* and toggle HAGS off or Game Mode off.
- **Power plan**: Change back to **Balanced** or **Power Saver** in *Power Options*.
- **Virtualisation features**: Re‑enable **Hyper‑V** and **Virtual Machine Platform** in *Windows Features*【386358036261583†L242-L258】.
- **Flydigi/Sonar**: Close the software or uninstall it via Apps & Features.
- **RTSS frame limiter**: Open RTSS and set the framerate limit to **0** or exit the application【598273801439488†L545-L552】.

## Notes

- When editing the registry or running `.reg` files, **right‑click and run as administrator**.  Always verify the contents of a `.reg` file before applying it.
- Restoring the registry or system might undo other changes (e.g., driver updates).  Document your tweaks so you can reapply them selectively.
- Use **System Restore** for large rollbacks and **registry import** for targeted fixes.
