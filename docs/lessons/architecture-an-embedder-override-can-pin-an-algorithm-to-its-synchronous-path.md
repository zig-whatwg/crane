# Architecture: An embedder override can pin an algorithm to its synchronous path

**Date**: 2026-10-18
**Lesson**: Navigation parsers fetched parser-blocking scripts synchronously only because the asynchronous branch ran before the WPT runner's embedder loader was asked; asking the loader first let every document parser suspend.

**Why**: 8d04d4f12 made navigation parsers Document-owned and able to wait (for script-blocking stylesheets), but set `can_suspend = script_created` to "preserve the embedder override": the runner's loader answers testharness.js, which must not run twice, and prepare's asynchronous fetch skipped the loader.

**What Happened**: With suspension already built, the page's thread still ran nothing while a parser-blocking script loaded - no timers, no frames, a frame's slow script froze its container - and ~40 worklist files blocked on it (render-blocking, moving-between-documents ordering). The fix was ordering, not machinery: for a parser-blocking script ask the embedder's loader first (a result in hand), and fetch asynchronously when it declines.

**Fix**: script_execution prepare step 33.11: `embedderScriptSource` first for a parser-blocking script, then `startClassicScriptFetch` when the parser can suspend; `can_suspend = true` for every DocumentParser (lane parser1, 17a168e8177). A production embedder has no loader and always takes the asynchronous path.

**Takeaway**: **When a capability exists but one path still avoids it, look for an override consulted in the wrong order before building anything new - and say in the comment which embedder the order exists for.**
