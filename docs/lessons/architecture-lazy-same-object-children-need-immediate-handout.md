# Architecture: Lazy same-object children need immediate handout

**Date**: 2026-10-05
**Lesson**: Avoid eagerly allocating a private same-object child when the collector only learns about it on first exposure.

**Why**: KeptChild's sever-only release protects children that script still holds. An eagerly allocated child that never gets a wrapper has no collector to release its native allocations. Guessing ownership from wrapper presence during collection introduces a different lifetime hazard.

**What Happened**: HTMLTrackElement initially created its TextTrack in init, but a detached element whose track getter was never read left that child unwrapped. The sever-path unit test reported its native allocation as leaked. The integrator required lazy creation with immediate handout, rather than destructor branches based on wrapper state.

**Fix**: Use one creator on first need. Seed the new TextTrack from the element's current attributes, immediately draw both approved traced edges, and use the same helper for direct getters and TrackEvent/list insertion. Before exposure, disabled mode, not-loaded readiness and element-owned attributes make delayed allocation unobservable. Keep teardown sever-only. Test unread creation/destruction, event-first exposure, child-only retention, parent-only retention, and collection of neither-held cycles.

**Takeaway**: **Every child allocated for the wrapper collector must actually reach that collector; prefer postponing allocation over guessing whether teardown may free it.**
