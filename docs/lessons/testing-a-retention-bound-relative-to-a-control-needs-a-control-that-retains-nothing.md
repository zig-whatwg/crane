# Testing: A retention bound relative to a control holds only when the control retains nothing

**Date**: 2026-10-09
**Lesson**: A test that measures what a run leaves behind usually compares it with the same run without the feature ("with lists retains no more than without"). Print the control's own numbers before trusting the bound. When the control itself retains, the relative bound passes a feature that keeps everything the control keeps.

**Why**: Crane frees a node only through its tree's root wrapper (wrapper_cache.treeOwns). A tree that never had a wrapper, such as one innerHTML parsed and then removed, is freed by no collection before its realm ends. So a "without" run over innerHTML churn keeps every tree it removed.

**What Happened**: Lane nodeholds' test "1,000 dropped querySelectorAll lists ... retain nothing past two collections" printed `instances 45000 -> 0, arena 84160000 -> 0 B`. The control, with no lists, kept all 45,000 removed nodes (1,000 rounds of 45). The lists' run kept none, because each list's rescue wrapped its tree and the collection of the dropped lists then freed them. The bound `with.instances <= without.instances + 64` would have passed lists that kept all 45,000. gc_bench's innerHTML churn body grows by about 35 KB a cycle on base and on tip alike, for the same reason.

**Fix**: Bound what "retain nothing" means absolutely (`with.instances <= 64`, `with.arena <= 64 KiB`), and keep the relative bounds only where the control is known to be flat (wrappers here). Print both runs' numbers in the test's output.

**Takeaway**: **Read the control's numbers before you read the comparison: a control that leaks makes "no worse than without" mean nothing.**
