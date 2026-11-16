# Architecture: "is a" and "has bytes of" are two questions of one ancestry table

**Date**: 2026-11-16
**Lesson**: The WebIDL brand check ("does this object implement interface X") and the state read ("where are X's bytes in this object") were one function, `Instance.stateAs(X.State) != null`; taking a level's bytes out of an object then also took the object out of the interface.

**Why**: A generated State nested its base interface's State, and the vtable's ancestry table listed each nested State with its offset. `stateAs` read that table, and the V8 adapter's `conv.implements` asked `stateAs(I.State) != null`. That is correct only while every interface an object implements also has bytes in the object. Lane nm3 took EventTarget's level (the listener list's address and the live word, 16 bytes) out of every node's State: a node is still an EventTarget, with no EventTarget bytes.

**What Happened**: The first design made a node's ancestry end at Node's State. That would have made `node.addEventListener(...)` throw a TypeError at the binding's receiver check, and `new MouseEvent('x', { relatedTarget: textNode })` reject its argument: the brand read the same table. The opposite shortcut - keep the entry and let `stateAs` answer a pointer - would have handed EventTarget's impl the first bytes of the NodeBase (the parent pointer) as its listener list.

**Fix**:
1. The ancestry stays the interface's whole inheritance chain. A State that leaves its base's State out (`absent_base`, runtime.FlattenedState; the impl's InternalState declares `omits_base_state`) is followed by an entry for that State with `Ancestor.absent` as its offset.
2. `Instance.implements(T)` reads the entry's id only: the brand. `Instance.stateAs(T)` answers null for an absent entry; the test is compiled only for a State whose impl declares `may_be_absent`, so no other State's read pays it.
3. The base interface's impl is the one reader of that State. It must have another place for an instance without it (EventTarget's `Listeners` handle: a node's rare block), and its declaration `may_be_absent` is what allows a derived State to leave it out - a compile error otherwise.
4. `conv.implements` calls `Instance.implements`.

**Takeaway**: **Ask "is this object an X" of the ancestry, and "where is X's state" of the offset - never the second to answer the first. Before removing a level's bytes from an object, grep for every `stateAs(X.State) != null` used as a type test.**
