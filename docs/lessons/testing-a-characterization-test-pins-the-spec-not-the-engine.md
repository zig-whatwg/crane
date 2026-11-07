# Testing: A characterization test pins the spec, not the engine

**Date**: 2026-11-07
**Lesson**: Before a characterization test pins an observable order or value, read the cached spec step that defines it: an engine's current behaviour can be an older spec that every browser and the newer spec have left.

**Why**: A characterization test is written to pass before and after a refactor, so it is written against what the engine does today. When that behaviour is a spec bug, the test freezes the bug and makes the later fix look like a regression. Orders are the usual case: they are easy to observe and easy to get right for the wrong reason.

**What Happened**: Lane perf2 batch 4 moved a node's registered observer list from an `infra.List` in every NodeBase to an intrusive list in rare data. Its characterization tests pinned that MutationObserver callbacks run in REGISTRATION order (the target's list, then each ancestor's), because Crane did that: "queue a mutation record" appended observers to the pending list in interestedObservers order, and notify walked a clone of that list. The design note said so. The integrator checked specs/whatwg/dom.md:4651: "notify mutation observers" step 2 sorts the pending observers by CREATION INDEX (whatwg/dom#1507, merged 2026-10-09). Blink (DeliverMutations, std::sort by priority_) and WebKit (notifyMutationObservers, sort by m_priority) always did; wpt#63390's MutationObserver-callback-order passes 3/3 in Chrome, Firefox and Safari. The file was newer than Crane's pinned WPT tree, so no A/B could have shown it.

**Fix**: The order went out of the characterization test (per-observer logs instead of one ordered log) and became its own red test plus a fix (459e91965c4: the agent's mutation observer counter, each observer's creation index, the sort in notify step 2). Registration order, which is still a list's order, is pinned by a native test of the list itself.

**Takeaway**: **Pin what the spec says, not what the engine does: read the step that defines an order before a characterization test freezes it, and check whether the spec moved since the engine was written.**
