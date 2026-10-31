# Testing: A load A/B that always runs the base first is biased

**Date**: 2026-10-31
**Lesson**: Under load, alternate which side of an A/B goes first in each round (or interleave single runs, as `wpt_runner --repeat --repeat-with` does). Rounds that always run the base and then the tip measure the tip in a different stretch of the host's load, and a load-sensitive race reads as a regression.

**Why**: A shared pool host's load drifts within minutes (builds start and finish, other lanes' runs come and go). With base-then-tip rounds, every tip run is a few minutes later than its base run, so any trend in the load lands on one side only.

**What Happened**: Lane flaky4 measured content-security-policy/generic/generic-0_8_1.sub.html's "Wildcard host matching works" under eight runner processes, three and four base-first rounds beside a build: base 10/72 and 13/128 failing, tip 22/72 and 24/128 - apparently twice as bad on the tip, a significant difference on its face. Six rounds that alternated the order: base 38/144, tip 40/144. Isolated, interleaved: 1/50 and 2/50. The race is real (a pre-existing CSP ordering bug, worse under load) and has nothing to do with the tip's change.

**Fix**: tmp/f4/loadab.sh (lane scratch) runs odd rounds base-first and even rounds tip-first; for single-runner rates use `wpt_runner --repeat=N --repeat-with=<base>`, which alternates every repetition. Call a difference only on the alternating numbers.

**Takeaway**: **Under drifting load, the order of an A/B is a variable: alternate it, or the trend of the load becomes the result.**
