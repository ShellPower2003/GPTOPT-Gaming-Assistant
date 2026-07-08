# GPTOPT Gaming Assistant product roadmap

**Product promise:** GPTOPT does not blindly tweak Windows. It audits, explains, measures, and only applies reversible changes.

**Primary tagline:** Find the hitch. Fix the conflict. Prove the improvement.

GPTOPT is a game-agnostic Windows gaming performance application. Halo remains a supported profile, not the product boundary.

## Principles

- Audit-only is the default.
- Diagnostics are independently versioned modules.
- Findings are structured, source-attributed results.
- Changes require a preview, backup, explicit consent, and undo path.
- Performance claims require repeatable before/after evidence.

## Delivery phases

1. **Foundation:** module contract, result schema, read-only runner, report stubs, safety policy.
2. **Evidence:** Windows, overlay, input, NVIDIA/RTSS, CapFrameX, and PresentMon modules with fixtures.
3. **Safe actions:** transactional apply/undo journals, dry runs, recovery tests, and signed action manifests.
4. **Consumer app:** Windows UI, session profiler, report viewer, installer, updater, and accessibility.
5. **Advanced workflows:** session comparison, history, WPR/WPA guidance, controller profiles, and profile packs.

## Product tiers (design boundary only)

**Free:** basic audit, overlay conflict detection, capture import, and simple reports.

**Pro-ready:** automated comparisons, trace guidance, trends, input profiles, tuning exports, and profile packs.

Licensing and payment code are deliberately out of scope. Feature boundaries must be capability-based so entitlement checks can be added outside diagnostic modules later.

## Success measures

- Every shipped diagnostic emits schema-valid results.
- Every mutating action has a tested undo operation.
- Reports distinguish observation, inference, and recommendation.
- Claims include source, confidence, and reproducible measurement context.
