# Architecture: A tree walk must reach an element's own destructor

**Date**: 2026-10-05
**Lesson**: A passing direct-deinit test does not prove that DOM tree teardown releases a new element's private state.

**Why**: A tree walker that dispatches ordinary elements to Element.deinit skips resources owned by more specific interfaces. Marking the base node's cleanup complete also prevents later wrapper cleanup from recovering the skipped state.

**What Happened**: Media loading's first seven Crane files passed all twelve subtests, including three JavaScript GC cases, but the runner reported ten leaked allocations. CRANE_LEAK_TRACES=1 attributed them to source, track and media private state, URLs and stable-state records. Node.deinitNodeByType dispatched only scripts and iframes specially. Direct owner-deinit unit tests had not exercised that tree path; a new parent-with-media-children test reproduced five leaked allocations.

**Fix**: Under a narrow integrator grant, add exact vtable-identity dispatch cases through interfaces.HTMLAudioElement, HTMLVideoElement, HTMLSourceElement and HTMLTrackElement. Keep a std.testing.allocator test that frees only the parent, and compare the same script worklist's allocator log after the fix. A generic most-derived teardown redesign belongs to the lifetime owner, not an unrelated feature lane.

**Takeaway**: **Test both an object's destructor and the real tree walk that is supposed to call it. JavaScript collection alone does not prove native cleanup.**
