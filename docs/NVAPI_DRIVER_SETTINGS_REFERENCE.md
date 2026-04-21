# NVAPI Driver Settings Reference

This file is the grounded reference layer for GPTOPT NVIDIA Profile Inspector work.

## Why this file exists

NVIDIA Profile Inspector exposes the NVIDIA driver profile database through NVIDIA's driver settings API. That makes the NVAPI driver settings header the most authoritative public source in this workflow for setting names and numeric IDs. Use community sources for interpretation and practical notes, but use NVAPI for the actual ID/name mapping.

## Primary sources

- NVIDIA NVAPI `NvApiDriverSettings.h`
- NVIDIA Profile Inspector overview / community usage references
- practical community notes such as PCGamingWiki, with the understanding that community guidance can age faster than the underlying NVAPI identifiers

## Confirmed useful settings for GPTOPT work

These names and IDs are directly confirmed from NVIDIA's NVAPI driver settings header and can be used to expand future `.nip` exports carefully.

- `REFRESH_RATE_OVERRIDE_ID` = `0x0064B541`
  - Preferred refresh rate
- `PREFERRED_PSTATE_ID` = `0x1057EB71`
  - Power management mode
- `FRL_FPS_ID` = `0x10835002`
  - Frame Rate Limiter
- `PRERENDERLIMIT_ID` = `0x007BA09E`
  - Maximum pre-rendered frames
- `PS_SHADERDISKCACHE_MAX_SIZE_ID` = `0x00AC8497`
  - Shader disk cache maximum size
- `QUALITY_ENHANCEMENTS_ID` = `0x00CE2691`
  - Texture filtering - Quality
- `VSYNCMODE_ID` = `0x00A879CF`
  - Vertical Sync
- `VRRREQUESTSTATE_ID` = `0x1094F1F7`
  - VRR requested state
- `ANSEL_ENABLE_ID` = `0x1075D972`
  - Enable Ansel

## How GPTOPT should use this

1. Treat NVAPI names and IDs as the source of truth for profile-setting identity.
2. Treat exported `.nip` structure from a real user sample as the source of truth for file format.
3. Treat practical game/community guidance as advisory, not authoritative, until tested.
4. Prefer small preset increments over giant unvalidated preset dumps.

## Practical caution

Community guidance around some settings can drift over time. For example, PCGamingWiki community discussion has explicitly challenged older statements about NVIDIA's frame limiter latency and notes that the modern NVCP "Max Frame Rate" limiter is not equivalent to older legacy limiter behavior. Do not encode older blanket claims into GPTOPT without current validation.
