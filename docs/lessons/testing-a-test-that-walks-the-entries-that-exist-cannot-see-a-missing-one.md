# Testing: A test that walks the entries that exist cannot see the one that is missing

**Date**: 2026-11-13
**Lesson**: A test of the form "for every entry in the table, the entry is well formed" passes when the table stops growing. A table that must gain an entry per event needs a test that names the latest event.

**Why**: The loop's bound is the table's own length, so the test asserts nothing about entries nobody wrote. The rule it was written for ("every round has its note") is a rule about the rounds, and the rounds are not in the test.

**What Happened**: `tools/perf_bench/report.zig` holds one line per published perf round in `round_notes`, and docs/performance.md says "a test holds every round to one". The test, "every round has its note, in order", walked `round_notes` and checked each line's index and length. Rounds 3, 4, 5 and 6 were published with no line - four rounds, six days - and the test passed every time, because the table still ended at round 2. Perf round 7 found it only because adding round 7's line alone would have failed the index check.

**Fix**:
1. The test now also asks for a line for every published round by number (`for (3..8) |round| try testing.expect(roundNote(@intCast(round)) != null)`); proven red before the lines were written (102 pass, 1 fail), green after (103/103).
2. Publishing a round extends that range in the same commit as its line: the failing test first.
3. For any table with one entry per event (a round, a generation, a lane's ruling): assert the count or the newest key from the event's own source, never only the shape of what is there.

**Takeaway**: **A loop over a table proves the entries' shape, not their presence: where every event owes an entry, the test names the newest event.**
