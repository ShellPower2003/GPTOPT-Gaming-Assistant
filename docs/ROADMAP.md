# GPTOPT Roadmap

## Current Position

GPTOPT has a working HaloSight GUI foundation and improved safety logic, but the repository foundation must be normalized before broad feature work.

## Phase 1: Foundation Cleanup

- Normalize collapsed files into real multi-line files.
- Add `.editorconfig`.
- Add `.gitattributes`.
- Add security, contributing, changelog, architecture, and roadmap documentation.
- Keep runtime behavior unchanged.

## Phase 2: Safety Tests

- Add Pester tests.
- Add parser and formatting checks.
- Add forbidden-pattern safety tests.
- Enforce CI reliability.

## Phase 3: Internal Command Layer

- Add audit commands.
- Add environment checks.
- Add Markdown and JSON report generation.
- Add rollback helpers.

## Phase 4: Profile Manifests

- Define profiles as data.
- Add risk labels.
- Add admin and reboot requirements.
- Add rollback command metadata.

## Phase 5: Control Center Foundation

- Dashboard.
- Audit tab.
- Profiles tab.
- Rollback tab.
- Reports tab.
- HaloSight tab.
- Settings tab.

## Non-Goals Until Later

- No one-click full optimizer.
- No broad debloat.
- No silent `.nip` imports.
- No direct NVAPI writes.
- No Defender disabling.
- No automatic app removal.
- No forced reboot or logoff.
