# Debugging: An idlharness type failure can be an impl stub

**Date**: 2026-10-20
**Lesson**: A member that idlharness reads as undefined may already have correct binding metadata and only need its owning impl completed.

**Why**: The diagnostic describes the script-visible result, not the layer that produced it. Changing exposure or returning a convenient constant can hide a missing algorithm or ownership dependency.

**What Happened**: The HTML idlharness reported incorrect types for `map.areas`, `marquee.loop`, and `window.external`, and could not construct its TextTrackCueList fixture because `addTextTrack()` was a stub. The map and External interfaces already had generated SameObject caching and tracing. HTMLCollection already had a live namespace/local-name filter and a retained root. The media owner already provided track construction, list membership and retained queued TrackEvents.

**Fix**:

1. Read each failing subtest's message and follow its generated member to the owning impl.
2. Reproduce the smallest failing script operation before editing the impl.
3. Use existing interfaces and owner hooks for the complete algorithm. For map areas, request the live HTML-namespace `area` descendant collection; let the generated cache preserve identity.
4. Test mutation behavior, namespace filtering, stable identity and collection after script references are dropped, rather than only satisfying the IDL type check.
5. Keep binding, rendering and missing ownership/capability work with its owners; enumerate those failures separately.

**Takeaway**: **Trace an idlharness failure through the generated member before deciding whether it is an exposure bug, an impl stub, or a missing prerequisite.**
