# Testing: Time the work that makes the collection, not just any allocation

**Date**: 2026-10-09
**Lesson**: A timing page meant to catch a collector-driven pause must time the kind of work that triggers the collection which frees the garbage under study; plain JavaScript allocation in the timed region makes scavenges, and DOM wrappers that have aged into the old generation are not freed by those.

**Why**: Node wrappers that survive a few scavenges are promoted, and only a full (mark-compact) collection finds them dead. Full collections are triggered by old-generation growth - here, by wrapping many nodes - so they land in whatever work wraps, and the teardown their second pass runs lands there too.

**What Happened**: Lane defertd's first crane/dt-teardown-pause-sync.html replaced a 10,000-node tree each round and timed 20,000 units of `{ j, s }` object allocation between replacements: the largest gap in the timed region was 0.2-1.9 ms on main, while the untimed innerHTML part took 1.6-7.6 s - the teardown was there. Timing a walk that wraps every element of the new tree instead (getElementsByTagName, 100 elements a unit) showed the pause: 130-137 ms on main, against 1 ms with TestUtils.gc() between rounds.

**Fix**: Make the timed region do what real pages do between replacements - touch and wrap the new nodes - and keep the control variant with a forced collection outside the timed region, so the difference is the collector's placement - as lane nodeholds learned for timed windows in general.

**Takeaway**: **A pause probe that times the wrong allocation measures nothing: time the work that triggers the collection you are studying, and check with a control that moves the collection out.**
