# Performance: An accessor that replaces a data property pays the binding's getter path on every read

**Date**: 2026-11-20
**Lesson**: When a spec fix turns a data property into a WebIDL accessor (Window's `self` and `frames`, HTML's [Replaceable] attributes), every read of it now goes through the binding's attribute getter. Measure that getter path itself, with a focused row for the hot read, before calling the change done. The generic path's fixed costs (the DOM-algorithm bracket, the error realm, any Global it makes) were invisible while the old shape was a free data property.

**Why**: A data property read is an inline-cache load, about 1 ns. An API getter call is a transition into C++ and the binding. In Crane the Window getter also made three heap-allocated Globals per read (the current context, its global, `this`), all to return the global proxy. `self === window` went from one getter call to two, at 2.0x, and the WPT gains hid it, because nothing in the suite read `self` in a loop.

**What Happened**: Lane maj5 made `self` and `frames` accessors (+8 window-properties, idlharness, replaceable-setter and implicit-this subtests). Its cost window then showed window.self-read, frames-read and self-member at 2.0x time and instructions. The fix was a handle-free case for the commonest receiver, `this` being the getter's own realm's global. It runs before the bracket and the error realm and does its check on Locals (v8_FunctionCallbackInfo_ReturnThisIfCurrentGlobal). The COOP access report check stays exactly where it was: the registry's Window, only while the Browser monitors access. That made `window` reads 0.52x main and `self === window` 1.03x. What remains is the accessor call itself, which the user accepted as spec-required (2026-11-20).

**Fix**: For a shape change on a hot global (window, self, document, location...), add a focused perf row that reads it in a loop. Compare it against main, and read the getter path for per-read handles and brackets it does not need. Pin the receiver cases (own global, another realm's proxy, missing, plain object, a detached frame) against the old code before writing the fast path.

**Takeaway**: **A WPT gain that turns a data property into an accessor moves the property onto the getter path: measure that path with a focused row, and make its common receiver handle-free.**
