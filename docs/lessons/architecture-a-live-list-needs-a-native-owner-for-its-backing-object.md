# Architecture: A live list needs a native owner for its backing object

**Date**: 2026-10-12
**Lesson**: Before putting a temporary collection behind a live list, prove that the list holds the collection in native calls as well as script calls.

**Why**: `dom.node_holds.MemberHold` counts references to nodes. For a non-node member it records the pointer and generation, and adds an engine edge when an engine exists. That edge cannot supply native ownership in a context without an engine.

**What Happened**: The form named getter needed a live RadioNodeList of image candidates. Reusing the controls path with a new temporary HTMLCollection looked sufficient, but no native owner would free that intermediate collection. Freeing it in the getter instead would leave the returned list empty. The existing controls path has an owner: the form keeps its elements collection.

**Fix**: Under codex-lpo Q6, the image filter uses the existing NodeList root hold on the form node directly. It walks current image candidates on each read and reuses the existing name storage and teardown. Native tests use `std.testing.allocator`; the script regression retains only the list across `TestUtils.gc()`.

**Takeaway**: **An engine edge and a generation check do not replace a native owner for a non-node backing object.**
