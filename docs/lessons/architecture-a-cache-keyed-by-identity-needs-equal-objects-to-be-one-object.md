# Architecture: A cache keyed by identity needs equal objects to be one object - measure which check misses before fixing the one the counter names

**Date**: 2026-11-11
**Lesson**: A matched-properties cache that compares a parent's data by address hits only when equal data IS one object; before converging the objects the miss counter blames, re-run the same lookups with that check by value in a shadow cache - the next check, the bucket policy or the key may be what actually misses.

**Why**: Lane style1 batch 2's census said 958,906 of 963,214 lookups on the AG Grid page missed on the parent's custom-property record pointer (1,808 record objects held 5 values). The obvious fix - converge the records - would have bought 76 hits: the counter recorded only the FIRST failing check, and behind it every bucket was full (four entries from four early parents, never replaced) and parents differed by address in two inherited longhands whose values the cascade allocates per element through var() (font-family lists and colors: Value.eql equal, `identical` not).

**What Happened**: Batch 3 measured before building. A census console (never committed) ran each lookup a second time with the record compared by value (+76 hits), then six shadow caches over the same lookups with other keys and policies: Blink's (matched sets + a hash of the parent's inherited data, value compare) 995,567 hits; a pointer key on the parent's record and inherited groups 388,667 on the objects as they were. With the candidate in the real cache behind census-only flags - the key carrying the parent's record and inherited group addresses (WebKit's computeHash hashes &inheritedCustomProperties) and a miss adopting an entry's equal records and groups (Value.eql for payloads that hold a reference) - the real cache hit 995,918 of 996,427: Blink's count at pointer-compare cost. Whole page: -3.54% instructions vs base (was +0.46%), jQuery -3.3%, memory per styled grid element 1,989 -> 1,402 B.

**Fix**:
1. Record every check a lookup fails, not only the first; or re-run the lookup with the suspect check relaxed and count what it fails next.
2. Simulate alternative keys and bucket policies as shadow caches fed the same lookups and styles (holding clones only) before choosing one; read the browsers' key and eviction (Blink: one bucket per hash, entries appended, LRU at GC; WebKit: 4 per hash) against them.
3. A pointer key is cheap and exact only when equal objects converge by construction: a hit hands out the entry's objects, a miss adopts an entry's equal ones. Converge by value equality of any group or record - never by knowing where a value came from (no var() special case).
4. Then measure the miss path per part (switch each off by env in a scratch console): adoption, lookup, recording, insert.

**Takeaway**: **A miss counter that names one check names the first one: before you converge objects to pass it, prove with a shadow cache that the lookups would then hit.**
