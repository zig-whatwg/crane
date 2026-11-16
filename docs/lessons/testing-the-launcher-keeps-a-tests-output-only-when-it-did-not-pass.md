# Testing: The launcher keeps a test's output only when it did not pass

**Date**: 2026-11-16
**Lesson**: A figure a passing test prints is in no log: `tools/test_launcher` writes a test's output to `tmp/test-launch/<suite>.jsonl.log` only for a test that failed, crashed or was flaky.

**Why**: The launcher runs each test in a child process and records one JSON line per test; it copies the child's stderr to the `.log` beside it only for a non-pass, so that a green run's log stays small.

**What Happened**: Lane wrap2 added byte pins whose bounds were first guesses, to be corrected "from the first run's figures". The first green run printed nothing: the pins passed inside the guessed bounds, and the numbers the merge report needed were not on disk. One pin's label was wrong (it called a traced reference a weak handle) and passed anyway, because its bound was loose; only the printed figure (16.0 B, not 32.0) showed it.

**Fix**: To read the figures of passing tests, apply a never-committed patch in the mirror that makes those tests end in an error after their prints (`if (true) return error.ShowFigures;`), run the file once, read the `.jsonl.log`, and reverse the patch in the same job. Then tighten each bound to the figure, so the pin fails when the figure moves.

**Takeaway**: **A pin that passes inside a guessed bound has told you nothing yet. Make the test show its number once, read it, and set the bound from it.**
