# Security Policy

## Scope

GPTOPT and HaloSight are Windows gaming optimization and evidence-capture tools.

The project does not intentionally support:

- Game injection
- Game memory reading or writing
- Input manipulation
- Anti-cheat bypasses
- Credential collection
- Forced browser closure
- Forced reboot, shutdown, or logoff

## Reporting a Security Issue

Open a private security advisory or contact the repository owner before publishing details.

Include:

- Affected file or script
- Steps to reproduce
- Expected behavior
- Actual behavior
- Suggested mitigation if known

## Security-Sensitive Changes

Changes touching registry, services, drivers, Defender, boot configuration, VBS, or kernel/security settings must include:

- Clear risk label
- Administrator requirement
- Audit mode when practical
- Rollback path
- No silent reboot
- Documentation update
