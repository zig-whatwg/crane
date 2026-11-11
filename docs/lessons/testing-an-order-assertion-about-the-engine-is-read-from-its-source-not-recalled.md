# Testing: An order assertion about the engine is read from its source, not recalled

**Date**: 2026-11-11
**Lesson**: Before a test pins the order in which an engine does something, read that order in the engine's source at the pinned version; a remembered order produces an assertion that is wrong about the engine, not about the code under test.

**Why**: A test that asserts an order encodes a belief about whoever produces the order. When that is V8, the belief is checkable in one grep, and an unchecked one fails GREEN for a reason that looks like a product bug.

**What Happened**: Lane v8up b6 moved wrapper finalizers out of V8's second pass onto a per-agent queue and wrote a test that three finalizers "run in the order they were collected" - first-pass order - on the assumption, from memory, that V8's second pass visits records in the order its first pass listed them. RED failed for the right reason; GREEN failed with `expected 00 01 02, found 02 01 00`. V8 15.7 lists a record for the second pass as the first pass visits it (src/handles/global-handles.cc:850, `push_back`) and the second pass takes them from the BACK (:765-767, `back()` / `pop_back()`): the reverse. The queue was right - it kept the order the finalizers had always run in - and the test and one doc sentence were wrong. "Fixing" the queue to match the test would have reordered every finalizer in the engine relative to main.

**Fix**: The assertion now states what the queue owes - the order V8's second pass handed the records over - and cites the two source lines that say what that order is. The doc sentence says the same.

**Takeaway**: **When GREEN fails on an order, decide which side holds the wrong belief before touching the code: read the producer's source. An order that existed before your change is the one to keep.**
