# NIP Preset Files

These `.nip` files are now in actual NVIDIA Profile Inspector export-style XML structure.

Validation basis:
- structure was matched against a real exported `.nip` sample provided by the user (`BASE.nip`)
- the current GPTOPT presets only use setting names and IDs that were confirmed in that sample

Current scope:
- these presets are importable-format XML `.nip` files
- setting coverage is intentionally limited to the IDs confirmed from the sample
- broader preset coverage can be added cleanly now that the export structure is known

Included presets:
- `GPTOPT-Competitive-Latency-Baseline.nip`
- `GPTOPT-Visual-Quality-Baseline.nip`
- `GPTOPT-Balanced-Baseline.nip`
- `GPTOPT-Halo-Infinite-Competitive.nip`
- `GPTOPT-Global-Safe-Baseline.nip`
