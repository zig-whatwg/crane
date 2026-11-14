# Architecture: A realm tree that ends children with their parent ends realms script still holds

**Date**: 2026-11-14
**Lesson**: When the collector took a detached realm, its end ended every child realm with it (endRealm's children loop) - but a child of a collected realm can still be reached by script elsewhere: the host page's first realm, hung under its successor by E1, was ended when the realm between was collected, while a popup still held a function of it; that function then read sessionStorage through a severed Window and threw SecurityError.

**Why**: The V8 adapter keeps a tree of Window realms so that a page's end ends everything under it (frames, a replaced top-level predecessor). A detached realm is kept "while script reaches it, ending once the collector takes it or with its page". The collector taking a realm says only that nothing reaches THAT realm; it says nothing of the realms it holds in the tree, which have their own references. Ending them with it confused "my holder went" with "nothing reaches me".

**What Happened**: Lane rep1 batch 2's A/B found websockets/unload-a-document/001.html newly failing: a popup's first document registered a test cleanup, navigated twice, and the cleanup threw. The popup model change had made popups' replaced realms E1 children of their successors, exposing a bug the host page already had: a native test (page A leaves a function with a popup, the page loads B then C, collect, call A's function) threw SecurityError on main too. A first engine-level red test did not reproduce it - the realm between was not collected there - which showed the fault was the END of a referenced realm, not its parenting.

**Fix**:
1. A realm the collector took passes its children to its parent before it ends (protocol_realms.zig passChildrenToParent from endCollectedRealm); each child then ends with its page, or when the collector takes it in turn. Only a realm with no parent ends its children with it.
2. Pin it both ways: a referenced replaced realm survives the collection of the realm between, and a page navigated 50 times with nothing holding its old realms keeps no chain of them.

**Takeaway**: **End a realm only when the collector takes it or its owner ends it - never because a realm that merely held it in a tree went.**
