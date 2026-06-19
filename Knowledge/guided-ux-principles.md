# GPTOPT Guided UX Principles

GPTOPT should behave like a product, not a script dump.

## Default user assumption
Assume the user does not know registry names, process names, profile files, or tuning jargon. The UI must translate technical checks into plain decisions.

## Main screen rule
The first screen must answer one question: **Am I ready to play?**

Use only these top-level states:

- **Ready to Play**: no required fixes.
- **Ready, Review Optional**: safe to play, but there are non-critical items.
- **Needs Attention**: fix red items before a serious session.
- **Unsafe / Stop**: risky state that needs user review before changes.

## Every card must explain
Each audit/fix card must show:

1. What this is.
2. Whether it is good, review, or fix.
3. Why it matters for gaming.
4. What GPTOPT will do when the button is clicked.
5. Whether it can be undone.
6. Advanced details hidden behind an expand button.

## Beginner mode
Beginner mode is the default.

It must not show raw values first. Use plain text such as:

- Timer is active.
- Halo is capped correctly.
- Controller software is running.
- Sonar audio routing looks okay.
- Windows capture is disabled.

## Advanced mode
Advanced mode may show registry values, process IDs, config paths, RTSS profile keys, timer resolution values, and Halo JSON fields.

## Action grouping
After every audit, actions must be grouped into:

- **Safe now**: can apply with backup and no reboot.
- **Review first**: user should understand a tradeoff.
- **Requires reboot**: do not apply silently.
- **Not recommended**: explain why GPTOPT will not do it.

## Safety rules
- Never hide a risky change behind a vague button.
- Every write must have a backup or rollback note.
- Never kill Flydigi, Sonar, RTSS, Afterburner, or Halo during a live game unless the user explicitly chooses that action.
- Do not treat Firefox as a gaming problem in background-load views for this user.

## User baseline
Known preferred baseline:

- Halo Infinite via Steam.
- 3840x2160 at 240 Hz.
- Halo render scale 100.
- Halo VSync off.
- Halo min/target FPS 960/960.
- RTSS Halo cap 240.
- Keep Flydigi SpaceStation running.
- Keep SteelSeries Sonar available.
- Timer holder active at 0.5 ms or 1 ms.
