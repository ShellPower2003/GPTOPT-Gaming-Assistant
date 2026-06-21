---
title: SteelSeries Sonar
---

# SteelSeries Sonar

**Purpose**\

SteelSeries Sonar (part of the SteelSeries GG suite) is a software mixer that creates **virtual audio devices** for game audio and voice chat.  It gives you separate volume sliders, EQ presets and filters for game, chat, microphone and auxiliary sources.  Keeping Sonar active allows you to balance game and chat audio and apply equalization without changing settings per application.

## Steps

1. **Install SteelSeries GG** and open the Sonar tab.  Sign in if prompted.  Enable Sonar in the settings.
2. **Set default playback devices**.  In Windows Sound settings, set the default output to **“SteelSeries Sonar – Game”** and the default communications device to **“SteelSeries Sonar – Chat.”**  Sonar’s virtual devices will then receive audio from games and chat applications and forward it to your headset.
3. **Configure channels.**  Within Sonar, assign your physical headset or speakers as the output.  Adjust individual volume sliders for *Game*, *Chat*, *Media* and *Aux* channels.  You can apply equalizer presets or create custom EQ curves.
4. **Leave Sonar running** while you play.  A community discussion notes that Sonar uses virtual audio outputs so you can individually control game and chat levels【226591225636271†L106-L113】.  If Sonar is closed or disabled, those virtual devices disappear and the audio reverts to a single mixed output.

## Reasons

- **Separate mixes for game and chat.**  Using Sonar’s game and chat channels lets you balance teammates’ voices against in‑game sound.  Virtual outputs exist only while Sonar is running【226591225636271†L106-L113】.
- **Built‑in EQ and noise reduction.**  Sonar includes equalizer presets, noise gate and spatial audio options that can enhance clarity in shooters.  These features only apply when using the Sonar virtual devices.
- **Low overhead.**  Sonar’s virtual devices run in software and do not introduce noticeable latency when configured properly.  Keeping it running has minimal impact on system performance.

## Rollback / disable

- To **disable Sonar**, open SteelSeries GG, go to the Sonar tab and toggle it off.  Switch your default playback and communications devices back to your headset or speakers.  Your audio will then bypass the Sonar mixer.
- If Sonar causes issues, you can uninstall SteelSeries GG from Windows Add/Remove Programs.  This removes the virtual devices and returns audio routing to Windows defaults.
