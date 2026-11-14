# Workflow: Two branches can take the same slot index and merge without a conflict - keep shared indices in one sequential list

**Date**: 2026-11-13
**Lesson**: A numbered resource that several places share (a context's embedder-data slots, an isolate data slot, a tag in a range) is safe only if every number is handed out in ONE place. When each user defines its own constant beside its code, two branches can both take "the next free one", git merges them without a conflict, and each then reads the other's object.

**Why**: V8 gives a context an array of embedder-data slots. Crane used 1 (the context's id) and 2 (the cross-origin functions), each a constant beside its user with a comment listing "all" the indices. Lane wrap1 batch 2 added 3 and 4 for the legacy platform object proxies' handlers; lane v8up batch 8, in the same days, added 3 for %AsyncIteratorPrototype%. Both comments said 3 was free, and both were right on their own branch. The merge was textually clean. In the merged tree every realm stored the async iterator prototype in slot 3 first, and the proxy code read it back as its handler: an ordinary object with no traps and Object.prototype for a prototype. The proxies lost WebIDL's key order, and a page's `Object.prototype.get` became their [[Get]] trap.

**What Happened**: wrap1's A/B, bug-finding sweep, cost window and leak check had all passed on its tip before the merge of main. The rule "merge current main before you report" was followed with the test step on the merged tree, and five unit tests failed there at once (four of wrap1's, and indexed_property_semantics_test's key order). The messages said what was wrong ("Object.prototype.get called as a trap: 3", "collection keys with own properties: 0,1,expando,Symbol(s),first,second"); a grep for the two index constants found them equal.

**Fix**:
1. Put every index of a shared numbered resource in one `enum` whose later enumerators take the next value, with one line per user, and delete the constants beside the users. A new user adds a line and cannot reuse a number; two branches that both add a line conflict in git, which is what you want.
2. After merging main, run the test step on the MERGED tree before reporting, even when the merge was clean and main's changes look unrelated. Gates on the pre-merge tip do not cover it.

**Takeaway**: **A clean merge proves the texts did not overlap, not that the numbers did not. Hand out shared indices from one list, and test the merged tree.**
