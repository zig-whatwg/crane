# Architecture: Reuse slots inside a collectible traced value

**Date**: 2026-10-08
**Lesson**: A bounded private-key namespace and a collectible value graph are separate requirements; temporary owners need reusable members inside a value reached by one fixed key.

**Why**: V8 Private::ForApi retains registered names until isolate destruction. Deleting a Navigation tracker’s private property releases the info value but cannot reclaim a new tracker-info name registered for each call.

**What Happened**: A 128-call reentrant navigation control retained 128 tracker-info key strings after collection. Each canceled tracker had its own monotonic key, even though it needed info only until its event was delivered and its promises settled.

**Fix**: Keep info values in an ordinary array reached through one fixed Navigation trace member. Give simultaneously live trackers distinct numeric slots, reuse released slots, clear finished values, and drop the entire edge when the last tracker finishes. Collector teardown removes the whole edge without reading JavaScript properties. Test outer and nested event identity during full collection and verify that completed values, including cycles back to Navigation, collect.

**Validation**: After the same 128 reentrant calls and forced collection, the old build retains 128 tracker-info key strings / 5,432 bytes; the fixed build retains zero dynamic tracker-info names and one fixed name / 48 bytes. Identity and collection assertions pass on both builds.

**Takeaway**: **An owner’s temporary children need collectible values and reusable indices, not new entries in an isolate-lifetime key registry.**
