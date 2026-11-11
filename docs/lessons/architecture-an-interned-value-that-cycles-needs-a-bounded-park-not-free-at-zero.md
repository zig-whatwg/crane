# Architecture: An interned value that cycles needs a bounded park, not a free at zero

**Date**: 2026-11-10
**Lesson**: A weak intern table that frees each record at its last release turns a value that cycles - `el.id = i & 1 ? 'x' : 'y'`, a classList toggle, setAttribute over a few values - into a malloc, a free, two hashes and a map insert and removal on every change. Park zero-count records in a small bounded ring, so the next intern revives one, and free only what falls out of the ring.

**Why**: Interning trades a copy per holder for a shared record. The trade only pays while the record outlives a holder's change, and a cycling value never does: each change drops the old value's last reference a moment before the next change needs it again. Gecko keeps an nsDynamicAtom whose count reaches zero in its table until 10,000 are unused (xpcom/ds/nsAtom.h kAtomGCThreshold). Blink and WebKit free an AtomString at once and pay the churn.

**What Happened**: Lane nd2 batch 2 made attribute values counted per-Browser records. The cost pair measured the write rows at +18-26% (setter-loop 1.257, set-get-attribute 1.197, classList toggle 1.181) against main's dupe and free. The integrator ruled for a ring with three bounds (21:41 UTC): 256 records, 16 KiB, never a record over 256 B. A full ring evicts one record synchronously, with no sweep; the table's end frees the rest. The ring never holds a counted record: a revival takes it out. The rows came back to 1.02-1.04, and a direct 25M-iteration setter loop ran 1.3% faster than main. Tests pin the bounds: a million distinct values end at the table's size plus the ring, a revival keeps its id and count, the byte bound and the per-record cap hold, and stats expose the ring.

**Fix**:
1. On the last release, park the record (a slot id in a fixed ring) unless it is over the per-record cap.
2. When the ring is full by count or bytes, free the OLDEST record, synchronously, on the owning thread.
3. An intern that finds a zero-count record removes it from the ring before counting it.
4. Readers of "how many records" use a live count; memory figures report the parked bytes beside it.

**Takeaway**: **Free-at-zero is right for lifetime and wrong for churn: give the weak table a small, byte-bounded ring of zero-count records, and a cycling value costs a hash and a probe instead of an allocation pair.**
