# Debugging: Count which branch ran before tuning its constant

**Date**: 2026-11-17
**Lesson**: Before a rule's constant is blamed for a number - and before a decision is asked for on it - count how often the branch with that constant ran in the measurement. An explanation that fits the number is not evidence that the branch was taken.

**Why**: The idle memory release had three hold-offs: 20 times the last release's duration, at least 5 seconds, and 30 seconds after a release that returned under 1 MiB. The streams page's first three rows stayed near 510 MB of settled resident memory on server1, and the lane that built the release explained it: "the process's first release, at the page's first idle stretch, returns under 1 MiB, and the next is held off for 30 seconds". That sentence went into docs/performance.md and into a question for the user, who decided to drop the 30-second case.

**What Happened**: Lane ev2 dropped the case and measured the page again (server1, 7 launches a side, main's console against the new rule): `streams.reader` 502.3 -> 509.1 MB, `streams.enqueue-read` 519.5 -> 520.7, `streams.pipe-through-decoder` 520.7 -> 521.8, `streams.blob-stream` 374.2 -> 372.1. Nothing moved. The base's own marks said why: main's console released again at `streams.transform-chain`'s mark or the one after it (that row sat on a low level, about 376 MB, in 4 of 7 launches), about 5 seconds after the page's first release - which the 30-second case would have forbidden. So the page's first release returned at least 1 MiB, the 30-second branch never ran on that page, and the first rows simply end inside the 5-second floor. The decision stands on its own merits (a release that found little should not block the next for half a minute), but the number it was asked to move was never the 30-second case's.

**Fix**:
1. When a number is explained by "branch X of the rule", count branch X in the run that produced the number - a test-only counter, a log line in a pool mirror - before writing the explanation down. Here: how many releases ended in each launch, and what each returned.
2. Read the base for a contradiction: if the blamed branch had run, what could NOT have happened? (Here: no release within 30 seconds - yet the base released within about 5.)
3. State an inference as an inference in the doc, with what it rests on; replace it when a count exists.
4. Re-measure after the change, and report "no change" as a result.

**Takeaway**: **A constant is to blame only if its branch ran: count the branch in the measured run before explaining a number with it, and check the base for what that branch would have made impossible.**
