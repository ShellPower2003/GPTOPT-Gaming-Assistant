# AGENTS.md — GPTOPT Codex Standing Instructions

These instructions apply to all automated coding agents, including Codex, working in this repository.

## Mandatory tool / connector behavior

Always use every available relevant connector/tool before finalizing.

Before making conclusions, editing files, opening a PR, updating a PR, or saying done, check:

1. GitHub repository state.
2. Current branch and latest `main`.
3. Existing PRs/issues when relevant.
4. CI/workflow status when a PR exists.
5. Changed file diff.
6. Local tests available in the repo.
7. External docs/search only when current facts, tool behavior, dependencies, or GitHub/CI behavior may have changed.

At the end of every task, include a **Connector/tool use report** with:

- GitHub: used/not used + what was checked.
- Web/search: used/not used + why.
- Local shell/tests: used/not used + commands run.
- CI: used/not used + run/status checked.
- Any unavailable connector/tool and why.

Do not say “done” until:

- Repo state was inspected.
- Changed files were inspected.
- Available tests were run, or exact reason they were not run was stated.
- CI was checked if a PR exists.
- Tool/connector usage was listed.

## GPTOPT project rules

This repository is a Windows gaming optimization toolkit focused on PowerShell automation, HaloSight, Steam Halo Infinite workflows, NVIDIA/Profile Inspector support, reports, and safe preview-first optimization.

### Safety boundaries

Never add these behaviors unless the user explicitly asks for them in the current task:

- Reboot logic.
- Shutdown/logoff logic.
- Registry edits.
- Halo settings edits.
- Destructive cleanup.
- Process killing.
- Xbox App / Gaming Services repair as the default Halo path.

Default behavior must be:

- Read-only.
- Preview-first.
- Reversible.
- Clearly labeled by risk.
- No live system change unless explicitly requested.

### Halo-specific rules

- Treat Halo Infinite as Steam-based by default.
- Do not assume Xbox App install.
- Do not make Gaming Services repair the default path.
- Preserve existing Halo Config drift/read-only GUI work.
- Do not overwrite or remove Halo Config drift tools.

### PR / coding rules

Before opening or updating a PR:

- Inspect latest `main`.
- Inspect the current branch diff.
- Run PowerShell parser checks.
- Run available smoke tests.
- Run JSON validation if JSON files changed.
- Run `git diff --check`.
- Check CI after pushing.
- Keep PRs draft until CI and review are clean.

### PowerShell compatibility

- Target Windows PowerShell 5.1 unless explicitly changed.
- Avoid external module requirements.
- Use robust try/catch.
- Avoid parser mistakes such as empty pipe elements.
- Do not require admin for read-only checks.
- Clearly state when admin would be required for a future apply action.

## Roadmap priority

Long-term goals:

1. Unified configuration system.
2. Automatic rollback snapshots.
3. Proper PowerShell module structure.
4. Expanded Pester/smoke tests.
5. Hardware and OS compatibility checks.
6. Risk rating for every tweak.
7. CapFrameX/PresentMon benchmark report automation.
8. Script security hardening.
9. Packaged releases.
10. Privacy-friendly diagnostic reports.

Do not implement the entire roadmap in one PR. Build it in safe, reviewable steps.
