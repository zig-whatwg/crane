# Architecture: Share fragment parser state initialization

**Date**: 2026-10-07
**Lesson**: Fragment parsing must call the same insertion-mode reset algorithm that later tree-construction steps use.

**Why**: The reset algorithm substitutes the context element only at the last stack entry. Head and cell contexts therefore behave differently from those same elements on an ordinary open-element stack.

**What Happened**: Crane had three mode-selection implementations. The DOM bridge started head and cell fragments in the wrong mode and treated frameset fragments as body content; the engine-free helper also mishandled html context. Tests of each lookup merely repeated its implementation.

**Fix**: Expose the tree builder's reset operation to both fragment entry points. Preserve the context pointer, template insertion-mode stack, ancestor form pointer and context document's scripting state. Test the resulting trees through both entry points under std.testing.allocator, with script fixtures for the DOM path.

**Takeaway**: **Test a fragment's resulting tree, and reuse the parser's state transitions instead of maintaining a parallel lookup.**
