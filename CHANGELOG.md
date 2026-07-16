# Changelog

All notable project changes should be documented here.

## Unreleased

### Added

- Repository foundation files.
- Contributor guidance.
- Security policy.
- Architecture and roadmap documentation.
- Read-only controller aim diagnostic for XInput/Flydigi center noise, range, motion updates, input-layer conflicts, and Halo controller settings.
- Controller aim-check launcher and desktop-app Halo-tab controls.

### Changed

- Normalized collapsed scripts and workflow files into real multi-line files.

### Fixed

- Improved raw-file reviewability and CI trustworthiness by enforcing newline normalization.
- Avoided PowerShell 7.5+ generic-list conversion failures after controller sampling.
- Updated the HaloSight smoke test for the current desktop-app `gui/legacy/test` launcher contract.
- Scoped the removed-mode smoke assertion to switch labels so `$ErrorActionPreference = 'Stop'` is not misclassified as a launcher mode.
