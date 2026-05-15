# HaloSight Settings

HaloSight loads `config\halosight.default.json` first, then overlays `config\halosight.user.json`.

If `halosight.user.json` is missing, HaloSight creates it from defaults.

## Editable settings

- Session root
- Evidence folders
- Max evidence files
- Max file size MB
- Copy videos on/off
- Compress videos on/off
- Auto-copy upload zip path on/off
- Auto-open upload folder on/off
- Watched processes
- Watched services

Use the GUI Settings panel for normal editing. Advanced users can edit `halosight.user.json` directly and then run the smoke test.
