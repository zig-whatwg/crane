# Spec Compliance: Another engine's rule includes its number type and its scanner

**Date**: 2026-11-17
**Lesson**: Reproducing a browser's rule "exactly as it computes it" means its arithmetic's types and its input scanner, not only its formula: both change answers at the thresholds and on odd input.

**Why**: A rule read as a formula ("usage over limit, as a percentage, the larger of the two") has more than one implementation, and the implementations differ where it matters - at the boundary values a test pins and a user meets.

**What Happened**: Lane mp2 reproduced WebKit's cgroup reading for Linux memory pressure (Source/WebKit/UIProcess/linux/MemoryPressureMonitor.cpp, BSD-2). Three places where the natural Zig was not WebKit's rule:

- The machine's percentage is integer arithmetic, but the cgroup's is `100 * ((float) usage / (float) total)` cut to an int: 32-bit floats. 899,999,999 bytes of 1,000,000,000 is 89 % in whole numbers and 90 % - the warning - in WebKit, because the usage rounds to 900,000,000 as a float.
- A cgroup file's value is strtol's, not a digit run: leading white space and a sign pass, anything after the digits ("max", a trailing blank) is "not set", and so is a number past LONG_MAX. Zig's `parseInt` would also take `1_000`.
- /proc/self/cgroup is scanned with fscanf, whose `%40[^:]` reads a controller list to the next colon - across a line's end - and fails past 40 bytes. A line-by-line parser gives another cgroup on text the kernel does not write.

Where the upstream result is undefined (a limit of 0: a float division by zero converted to int) there is nothing to reproduce: choose the safe answer and say so in the comment.

**Fix**: Read the upstream function for its types and its input calls before writing the formula. Write the test at the value where the types disagree (the float case above), and one input where the scanner disagrees with a tidy parser. State each difference you keep, with why.

**Takeaway**: **A rule taken from another engine is its formula, its number types and its scanner: pin a test where each one changes the answer, and name every place you differ.**
