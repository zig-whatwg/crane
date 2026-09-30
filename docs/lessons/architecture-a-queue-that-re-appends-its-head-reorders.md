# Architecture: A queue that re-appends the head it cannot serve reorders it

**Date**: 2026-09-30
**Lesson**: The in-order script list popped its head and, when that script was not ready, appended it again at the back - so the script behind it ran first on the next drain.

**Why**: The list's whole point is order: "the list of scripts that will execute in order as soon as possible" runs its head, and only its head, once ready. Putting an unready head back at the tail swaps it with every script behind it.

**What Happened**: Harmless for as long as every script was fetched synchronously at preparation: all results were in hand together, and no head was ever unready when its turn came. Once script-inserted scripts were fetched in parallel (lane/scripts 6ed720fa1), a slow first script and a fast data: second one ran second-first, which moving-between-documents/ordering/in-order.html and crane/script-inserted-fetch.html check.

**Fix**: When the head is not ready, take the rest off and put the head back first, then the rest in their order (`runOneReadyInOrderScript`).

**Takeaway**: **A drain that cannot serve its head must leave the head where it was; code that only ever saw every item ready at once has never exercised that path.**
