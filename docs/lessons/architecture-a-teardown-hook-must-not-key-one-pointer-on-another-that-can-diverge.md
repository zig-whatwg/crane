# Architecture: A teardown hook must not key one pointer on another that can diverge

**Date**: 2026-10-28
**Lesson**: A browsing context names its active window and its active document with two separate pointers. The Window's teardown cleared the document pointer only where the window pointer still matched. After a realm swap the two diverge, so a frame kept naming a freed Document, and the next navigation's abort wrapped it.

**Why**: In HTML, and in Blink, a navigable's active document IS its active window's document (Blink's Frame::GetDocument reads DomWindow()->document()), so there is nothing to forget separately. Crane stores both on BrowsingContext. A frame commit sets the new Window as the active window when it makes the realm (HTMLIFrameElement replaceRealm -> FrameWindow.create -> setActiveWindow), but sets the new document only later, in commitInRealm. Between those two points, and for good when the commit fails, the context names W2 and D1. Navigables.forgetWindow(W1, D1), run as W1's teardown frees D1, did `if (ctx.active_window != window) continue;` before clearing the document, so D1 stayed named.

**What Happened**: tests/html/iframe_policy_container_oom_test.zig crashed intermittently on main: a Bus error hashing an interface name in template_registry, under Document.abortDocument's retainValue, from HTMLIFrameElement.runBeforeUnload.
- The suspected cause was "a wrap into a realm that does not exist". The measurement showed a wrap of a Document whose slab slot no longer held a Document: the hashed name came from a freed vtable.
- It was intermittent because the free waited for a collection. A sweep that forces a collection after each failing round (tests/html/nav2_failed_navigation_active_document_test.zig) made it deterministic: failing allocation 126, every run.
- Clearing the pointer exposed a second gap: a frame left with no realm never navigated again through src (runCommit's unload needs the realm). Main had the same gap behind the dangling pointer.

**Fix**:
1. forgetWindow clears `active_document == document` on every context, whatever its active window (lane nav2 dd84a8174b1).
2. runCommit re-makes the child navigable of a navigable left with no realm, as get_contentWindow already did (7c7e9473fcb).
3. A test that watches a frame's document reads it through the browsing context, never through contentWindow, which re-creates the navigable.

**Takeaway**: **When an object keeps two pointers that the spec treats as one fact, every hook that clears one must clear each on its own condition: list the windows of time in which they diverge, and test the hook inside one. To make a "freed under it" bug deterministic, force the collection the free waits for.**
