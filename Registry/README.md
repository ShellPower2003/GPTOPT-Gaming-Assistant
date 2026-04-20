# Registry Bundles

These files are intentionally limited and should be reviewed before import.

Included now:
- `MPO-Disable.reg`
- `MPO-Restore.reg`

Why only MPO here right now:
- MPO toggling is a common graphics troubleshooting step with a clean restore path.
- Other Windows graphics values can vary more by OS version and intended baseline, so they are better documented first before shipping as blind bundles.

Recommended use:
1. Export or note the current state first.
2. Import one file only.
3. Reboot only if the targeted behavior actually requires it.
4. Validate the result with a repeatable test route.
