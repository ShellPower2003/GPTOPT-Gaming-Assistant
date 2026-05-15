# GPTOPT Safety Model

GPTOPT is designed around reversible, measurable Windows gaming optimization.

## Core Principles

1. Prefer reversible changes.
2. Avoid undocumented permanent system changes.
3. Save previous system state before applying tuning profiles.
4. Require Administrator permissions only when necessary.
5. Clearly label security-sensitive changes.
6. Benchmark before and after applying changes.
7. Provide reset paths for every applied profile.

## Risk Levels

### Low Risk

- Documentation updates
- NVIDIA profile imports
- Read-only audits
- Benchmark instructions

### Medium Risk

- Service startup changes
- Registry tuning
- Power plan changes

### High Risk

- VBS/security changes
- Kernel/security feature changes
- Driver-level changes

## Required Behavior

Scripts should support audit or dry-run behavior where practical.

Scripts that modify services or registry keys should document what they change and how to undo it.

Security-sensitive scripts should require explicit confirmation unless a force flag is passed.

GPTOPT should not use game injection, game-memory reads, input manipulation, forced browser closure, forced reboot, or blind process killing.
