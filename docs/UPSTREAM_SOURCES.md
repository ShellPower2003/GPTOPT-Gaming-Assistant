# Upstream / Source Mapping

This document explains how the earlier repositories map into `GPTOPT-Gaming-Assistant`.

## 1) PowerShell-Utility

Status: absorbed here.

Reason:
- The old repo was too generic and its main script was not a strong standalone project.
- The useful concept was the idea of a menu-driven utility for audits, cleanup, and gaming workflows.

Action taken:
- A corrected and repurposed script now lives at `Scripts/Ultimate-Utility.ps1`.

## 2) nvidiaProfileInspector

Status: keep as separate companion / upstream reference.

Reason:
- It is a substantial standalone codebase with its own history and license.
- GPTOPT should reference it for profile-level NVIDIA work rather than pretending to replace it.

How to use it in GPTOPT:
- explain common profile settings
- document profile workflows
- add example `.nip` presets later if desired

## 3) Gpttest-

Status: treat as learning/reference material only.

Reason:
- It appears to be primarily inherited educational content with its own branding and licensing.
- GPTOPT should not re-bundle third-party course or notebook material unless there is a clear reason and the licensing path is clean.

How it informs GPTOPT:
- better prompt structuring
- better tutorial organization
- improved task decomposition and diagnostics prompts

## Repository direction

`GPTOPT-Gaming-Assistant` should be the operational hub:
- assistant instructions
- prompt starters
- utility scripts
- rollback-aware configs
- benchmark interpretation templates
- profile guidance for gaming optimization
