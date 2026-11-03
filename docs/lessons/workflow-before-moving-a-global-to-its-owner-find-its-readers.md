# Workflow: Before moving a global to its owner, find its readers

**Date**: 2026-11-02
**Lesson**: Seven of the 33 per-thread and per-process variables lane gstate3 was to move to their owners had no reader at all, and two more lists were keyed by one realm while half of their walks asked another.

**Why**: The global-state inventory (tools/global_state_baseline.txt) lists every mutable global with a guessed owner class (A agent, R realm, T tab...). The class says where the state would belong IF it were state. It does not say whether anything still reads it, or whether every walk over it asks the same owner.

**What Happened**:
- Dead, not misplaced: context_manager's accessor-Window stack (`accessor_stack`, `accessor_stack_depth`, class A) was pushed and popped around every prepare to run script and every promise job, and `getCurrentAccessorWindow` had no caller. timer_backend's lazily made default backend (`default_backend_instance`, `default_backend_allocator`, A) and its override (`custom_backend`, H) had no caller outside their own tests; the WPT runner freed a backend nothing had made. context_manager's child-context and child-window callbacks (two H slots) were set and cleared by page_realm and read by nothing. Each was deleted, with the grep that proved it in the commit - and deleting the accessor stack also took a context-manager lookup off every prepare and promise job.
- One owner for walks that ask two: a classic script fetch and a style sheet load are found by their element (its owner cancels them, its end ends them) and by their document ("abort a document", the load event's delay). An element created in one realm and adopted into another realm's document before its load began has two realms. The list went to the element's realm, the one every element-keyed caller (including a modulepreload's late callback, which must not read the element) can always reach; the document walks read the document's realm's list and accept the adopted-element edge, which that realm's end and the preparation-time document checks still cover.
- A list freed when it empties changes what a `for` over it may do: a body that ends the last object frees the slice under the loop. Every walk that can end an object here re-reads the list each step; the read-only and mark-only walks may iterate.

**Fix**:
1. For each variable, grep its readers before choosing an owner. No reader: delete it, and put the grep in the commit.
2. For each walk over a list, write down which owner the walk asks by (realm, document, element, id). If they differ, key the list by the owner every caller can reach, and say in the code which walk accepts an edge.
3. When a list's storage is given back on emptying, check every iteration for a body that can remove.

**Takeaway**: **An inventory class is a guess about where state belongs, not proof that it is state. Find its readers first: delete what nothing reads, and key a list by the owner every walk can reach.**
