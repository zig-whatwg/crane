# Architecture: "Is this still its Window's document?" stops working once navigations make new Windows

**Date**: 2026-09-26
**Lesson**: With a new Window per navigation, the old Window keeps pointing at its old document, so "the Window's document is me" no longer tells a replaced document it has been replaced.

**Why**: HTML asks whether a document is fully active; the engine had been answering through the Window, which was right only while one Window lived for the whole browsing context.

**What Happened**: A replaced document went on to finish loading: it fired load, and a second load at its iframe.

**Fix**: Ask the document itself - an unloaded document is not salvageable, and its pending load tasks do not run (lane/navigation 6f524ddfc).

**Takeaway**: **Ask the document whether it is fully active, not its Window.**
