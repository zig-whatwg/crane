# Architecture: Native font status precedes its script promise

**Date**: 2026-10-22
**Lesson**: An automatic CSS font load can finish before script ever requests its `loaded` promise.

**Why**: Rejecting an eagerly created JavaScript promise can produce `unhandledrejection` even when script never observed the resource. Native loading status and a script promise have different creation times. The explicit `new FontFace()` constructor still creates its promise eagerly, as its algorithm requires.

**What Happened**: Adding used-text font selection exposed that `Face.start` always created `loaded`. The native regression started a CSS-connected face without reading `loaded` and found an initialized promise. A failed automatic font would reject that unseen promise.

**Fix**: Keep terminal status and the syntax/network failure reason in the face. Automatic loading creates no script promise. The first `loaded` or `load()` access creates one and settles it from the existing status; later reads preserve its identity. Completion settles only an already-created promise. OwnerPromise's pending and traced ownership stays unchanged. This follows WebKit's native DOMPromiseProxy and its `loadedForBindings`/`loadForBindings` accessors, rather than installing a handler or marking an internal promise handled.

**Takeaway**: **An unobserved resource failure is native state; create the script promise at the API's specified observation point.** Test automatic failure, a late catch, repeated identity, and the explicit constructor separately.
