# Debugging: A call that can free its argument ends every read of it

**Date**: 2026-10-18
**Lesson**: When a helper may release the object it is given (a "complete" that frees a load when nothing is left to wait for), take every value the caller reads afterwards - its id, its allocator, fields a `defer` touches - before the call.

**Why**: `style_sheet_loading.complete(load)` queues the load's event task, but releases the load at once when the element's realm has no event loop or no engine left. Four callers (`startStyle`, `startBlockedStyle`, `startLinkFetch`, the non-script modulepreload path) then returned `load.id`, and `startStyle`'s `defer` freed a string with `load.document.ctx.allocator` - reads of freed memory on that path.

**What Happened**: The browser always has an event loop, so the path never ran in WPT. Lane style2's first native test that inserted a `<style>` into a document of a realm with no event loop (tests/v8/style_engine_test.zig) crashed with a segmentation fault at 0x10 in the `defer`, and the 10,000-frame trace through `_Builtins_CallApiCallbackGeneric` looked like a stack overflow until the top frame was read.

**Fix**: In each caller, `const id = load.id; const document_allocator = load.document.ctx.allocator;` before `complete(load)`, and only those afterwards (commit "fix(html): read a style sheet load's id before complete() can free it").

**Takeaway**: **A call that can free its argument ends the caller's use of it - including the `defer`s written above the call**; read the trace's top frame before believing a deep one.
