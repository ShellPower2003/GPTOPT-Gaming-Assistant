# Timer Holder: Maintaining consistent timer resolution

**Purpose**

On Windows, a hardware timer fires interrupts at a fixed interval and wakes the kernel scheduler to decide which thread runs next.  This interval is around **15.6 ms**, inherited from Windows 98-era hardware【646706303966671†L72-L76】.  For a game rendering at 144 FPS, frames need to be delivered every ~7 ms.  If the scheduler only wakes up every 15.6 ms, frame delivery becomes lumpy and **micro‑stutter** becomes noticeable【646706303966671†L77-L81】.

Modern games call `timeBeginPeriod()` to request a higher timer resolution.  A call like `timeBeginPeriod(1)` tells the kernel that the application needs a **1 ms** timer resolution.  This bumps the interrupt rate to **1000 Hz** and results in smoother frame delivery【646706303966671†L83-L87】.  Some games even request **0.5 ms** to further reduce input latency【646706303966671†L83-L87】.

Windows 11 changed how timer resolution requests are handled.  Prior to Windows 11, a single application could request a 1 ms resolution and the system would honour it **globally**.  Windows 11 now treats `timeBeginPeriod()` as **per‑process**, so if your game requests 1 ms the global timer still stays at 15.6 ms【646706303966671†L96-L105】.  Microsoft made this change to reduce power consumption: a misbehaving background app could increase system power draw by **10–25 %** indefinitely, so the default behaviour now preserves battery life on laptops【646706303966671†L127-L135】.  Unfortunately this trade‑off hurts desktops and gaming PCs by allowing micro‑stutter【646706303966671†L137-L146】.

**Recommended fix – Timer Holder / global timer restoration**

Microsoft quietly left a registry back‑door to restore the old global timer behaviour.  Setting the following registry value enables system‑wide honouring of `timeBeginPeriod()`【646706303966671†L174-L181】:

```
Key:    HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel
Value:  GlobalTimerResolutionRequests (DWORD)
Data:   1
```

You can apply this via an elevated command prompt:

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f
```

After running the command, **reboot**.  When your game calls `timeBeginPeriod()`, Windows will honour it globally and raise the hardware timer for the duration of the session【646706303966671†L184-L195】.  When you close the game the timer returns to 15.6 ms【646706303966671†L191-L195】.  This eliminates micro‑stutter without needing third‑party tools【646706303966671†L197-L198】.

If you prefer not to modify the registry, you can instead use a *timer holder* utility.  These tools keep the timer resolution at 1 ms or 0.5 ms while they are running.  Once closed, Windows reverts to its default interval.  Holding a higher timer resolution may increase power usage, so disable it when gaming isn’t your priority.

**Why it matters**

Smooth frame delivery depends on the operating system’s tick rate.  Games running with low timer resolution can exhibit inconsistent frame pacing and input latency.  Restoring global timer behaviour or running a timer holder ensures your game’s requests are honoured, delivering a consistently smooth experience.

**Rollback plan**

To undo the registry tweak, either delete the `GlobalTimerResolutionRequests` value or set it to `0` using the same `reg add` command with `/d 0`.  Reboot to apply the change.  Alternatively, simply close your timer holder utility to return to the default 15.6 ms timer.

**Advanced details**

The Windows timer fix does not modify game files or drivers.  It merely instructs the kernel to honour high‑resolution timer requests globally again.  Power efficiency is the reason Microsoft disabled this behaviour【646706303966671†L127-L135】; therefore, laptops and energy‑conscious users may want to leave the default behaviour in place and rely on per‑process timer requests.
