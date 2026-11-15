# Testing: A reused summary script prints yesterday's labels and zeros for what this run did not measure - read the arms from the run's own check lines, and print "not measured", never 0

**Date**: 2026-11-15
**Lesson**: A summary script written for one comparison carries that comparison's facts as fixed text and default values. Run on other binaries it still prints them: an arm labelled as a binary that was not in the run, "0 full collections" for a build that prints no collection lines, "told 0.0 MB" for a build that prints no such trace. Each reads as a measurement.

**Why**: Lane dm2 took lane dm1's page summary (`pages_sum.py`) for its own measurements. Three things in it were true only of dm1's run. (1) A table of arm names: `'maintrace': 'main + trace (dm1 binary, mode 0)'`. In dm2's run the `maintrace` arm was dm2's own build of main ceb3c5098a0. (2) Collection counts were computed as "how many collection lines the run printed", so a build compiled without V8's trace reported `full collections [0, 0]; minor [0, 0]`. (3) Per-collection columns (`told before`, `counter`, `dead`, `TOLD AT THE LIMIT COMPUTATION`, `pass us`) were filled from "DM1 ..." lines that only dm1's patched binary printed, with `.get(key, 0)`: for any other build they printed `0.0`, `0 trees` and `nan`.

**What Happened**: The first table lane dm2 read had the stale label in its header. It was caught while reading the table against the launcher's arms, before any message quoted it; the saved output was corrected by hand with a note saying so. The zero-filled columns were caught one run later, on the parser page, where a line read `told before 0.0, counter 0.0, dead 0.0 ... TOLD AT THE LIMIT COMPUTATION 0.0` beside a V8 global of 64.1 MB - impossible if it were a measurement. The plain arms' "0 full collections" had been on screen since the first run; the lane's claim "0 full collections on both sides" was right only because it came from the separate trace arms.

**Fix**:
1. What an arm IS comes from the run: the launcher's ARMS and each frozen directory's BUILD_INFO, which the measurement script prints in its `check: arm ...` lines. A name table in a summary may shorten a label; it must not describe a build.
2. A count derived from "lines seen" needs a third state: no lines of that kind at all means "not traced", printed in words.
3. A column filled from an optional source is printed only when the source is present. `.get(key, 0)` in a report is a measurement of zero as far as the reader can tell.
4. Before quoting a table, check one number in it against something independent (here: an external figure of 0.0 MB beside a 64 MB global).
5. Name saved outputs by what they compared (`attributes-x10-main-vs-tip<sha>-item104.out`), not by the script that made them: the same launcher overwrote `meas2-c-attributes.out` for a different tip an hour later.

**Takeaway**: **A summary is part of the measurement. When a script outlives its first run, every label it prints from memory and every default it prints for missing input is a claim nobody made: derive labels from the run, and make "absent" print as absent.**
