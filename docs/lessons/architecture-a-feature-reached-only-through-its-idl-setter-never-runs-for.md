# Architecture: A feature reached only through its IDL setter never runs for markup

**Date**: 2026-09-26
**Lesson**: A parser-inserted `<iframe src>` never navigated. `src` was read from a cache only `iframe.src =` filled, and the load hook ran from `Node.call_appendChild` alone - while dom.mutation's post-connection registry, which every insertion (the parser's included) runs, sat unused.

**Why**: hand-written paths hung behaviour on the IDL member script uses; markup sets content attributes and inserts through the tree.

**What Happened**: roughly 200 files across html/ waited on markup frames that stayed about:blank. Making them load (the navigation lane, increment 1) moved blocking 261 -> 200 in the navigation areas and 155 -> 101 in 811 other frame files - and exposed code nothing had reached: 25 legacy-mb decode files crashed on cross-realm reads (see "An object wrapped in two realms must outlive both wrappers").

**Fix**: element behaviour on insertion goes in the post-connection (or insertion) registry and reads content attributes; IDL setters only reflect.

**Takeaway**: **If a behaviour lives behind an IDL setter, test it with markup before trusting it. The first time markup works, expect new failures from code nothing reached before - diff per file.**
