# Workflow: A declared probe is not a sent event - find its call site before implementing an event

**Date**: 2026-11-23
**Lesson**: Before implementing a CDP event from Chrome's agent code, grep for the probe's CALL SITES: a probe can be declared, and its agent handler written, with nothing ever calling it - and then Chrome never sends the event.

**Why**: Blink's InspectorDOMAgent has WillPopShadowRoot, which sends DOM.shadowRootPopped, and core_probes.pidl declares the probe; but no code calls probe::WillPopShadowRoot (none in Chromium 145 or 157: a shadow root is never detached since Shadow DOM v0 went). The protocol still lists the event.

**What Happened**: Lane cdpd1's roadmap line listed shadowRootPopped among the events to send. A call-site grep over third_party/blink/renderer found only the declaration and the agent's handler, so Crane sends none, as Chrome, and the code comment cites the absent call site (main's D7).

**Fix**: `grep -rn 'probe::<Name>' third_party/blink/renderer` (and the 157 tag's files) for every event's probe; an event with no call site is "never sent", stated in the code and the roadmap.

**Takeaway**: **The protocol's event list and the agent's handlers say what Chrome could send; only the probe's call sites say what it does send.**
