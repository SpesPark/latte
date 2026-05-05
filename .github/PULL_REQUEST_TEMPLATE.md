<!-- PR title format: <type>: <description>  (feat / fix / refactor / docs / test / chore / perf / ci) -->

## Summary

<!-- 1-3 bullet points: what changed and why. -->

## Test plan

- [ ] `xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64'` — all tests PASS
- [ ] `~/dev/smoke-harness/run.sh --project .` — 22/22 scenarios PASS (only required for UI / popover / Settings changes)
- [ ] Manual smoke covered any UI changes that the harness can't drive (popover key chord, Settings recorder field, etc.)

## Risk / blast radius

<!-- Surfaces touched, likely regression vectors. Use "low / medium / high" + one line. -->

## Screenshots / recordings (UI changes)

<!-- Drag-and-drop. Required for any visual change. -->

## Notes for reviewer

<!-- Anything non-obvious: deferred follow-ups, open questions, alternative
designs considered, performance trade-offs. -->
