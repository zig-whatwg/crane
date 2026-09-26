# Architecture: A USVString getter's result is freed by the binding

**Date**: 2026-09-26
**Lesson**: A getter returning `[]const u8` (USVString) hands the binding a slice with no ownership tag, and the binding frees every non-empty one it gets.

**Why**: `DOMString` carries `.interned` / `.owned`; a bare slice cannot say "borrowed", so the binding treats it as owned.

**What Happened**: `HTMLImageElement.get_src` returned a view of the attribute's own storage, so every `img.src` read freed memory the element still owned. Found while replacing it with generated reflection (lane/reflection).

**Fix**: Return a copy allocated from `ctx.allocator`, never a view.

**Takeaway**: **A USVString getter returns memory the binding will free - always a copy, never a view.**
