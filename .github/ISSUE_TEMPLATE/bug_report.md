---
name: Bug report
about: Something doesn't work as expected
title: ''
labels: bug
assignees: ''
---

## What happened

<!-- One or two sentences describing what went wrong. -->

## What you expected to happen

<!-- One sentence on the expected behaviour. -->

## How to reproduce

1.
2.
3.

## Environment

- Latte version: <!-- e.g. v1.9 (App Store / built from source) -->
- macOS version: <!-- Apple menu → About This Mac -->
- Hardware: <!-- Apple silicon / Intel; MacBook / Mac mini / iMac / Mac Studio -->
- Triggers active: <!-- Calendar / App / Wi-Fi / ExternalDisplay / Schedule -->

## Logs (optional but very helpful)

Open Console.app and filter on `subsystem == "com.parkbyeongjun.latte"`, or
run from a terminal:

```
log stream --predicate 'subsystem == "com.parkbyeongjun.latte"' --info --debug --style compact
```

Reproduce the issue, then paste the relevant lines below.

```
<!-- paste log lines here -->
```

## Screenshot (optional)

<!-- Drag-and-drop into the comment box. Especially useful for UI glitches. -->
