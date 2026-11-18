# Performance: A named properties handler runs on every miss - take the spec's cheap step first

**Date**: 2026-11-18
**Lesson**: A handler on the named properties object (WindowProperties) runs for every lookup that walks past `Window.prototype` and finds nothing, so its cost is paid on misses, not hits. Order its work as the spec orders it - "not a supported property name" first - and make that first answer need no walk and no allocation.

**Why**: WebIDL 3.9.7's named property visibility algorithm returns false at step 1 when the name is not supported; the prototype-chain checks (steps 2 and 4-5) only matter for a name that exists. A miss is the common case: `window[i]` past the child navigables, every global name a window does not have, `window.addEventListener` on its way to EventTarget.prototype.

**What Happened**: Lane blk3 gave WindowProperties indexed handlers (array-index names such as `<div id=0>`) that ran the visibility walk (a C++ prototype-chain check) BEFORE asking Window whether the name was supported, and Window's child-navigable lookup built the document-tree child navigable list - a walk of the document for its containers - on every lookup. The focused cost window (chat.local, 2026-11-18, a lane-only row timing 100k `window[7]` with no frame 7) read time 1.297 and instructions 1.247; every other row was within the bar.

**Fix**: The indexed handlers check `Window.isSupportedPropertyName` first and walk visibility only for a name that exists; `childNavigableNamed` returns null when none of the navigable's own children has the target name (a document-tree child navigable is always one of them), so a miss neither walks the document nor allocates.

**Takeaway**: **Before adding a handler to a named properties object or any interceptor on the global's prototype chain, time a MISS (a row with a name that does not exist), not just a hit; and take the spec's cheapest exit first - it is usually step 1.**
