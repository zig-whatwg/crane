# Debugging: A cause named from a mechanism is a hypothesis until the measurement that showed the symptom is repeated on the fix

**Date**: 2026-11-16
**Lesson**: A mechanism that could explain a measured symptom, a code change that removes the mechanism and a green test of the change do not prove the symptom is gone. Repeat the measurement that showed it before the commit message or the report says "fixed" - and say "hypothesis" until then.

**Why**: Lane ab1 saw 0.08 s of system time against main's 0.01 s on a BigInt row. Reading the allocator's ring showed a real difference from PartitionAlloc (a chunk left the ring when it was used again and took a new place when it emptied), and a model test showed the old code giving a chunk back in every operation. That was enough to feel proved. It was a second, smaller effect of the same data structure.

**What Happened**: The commit message and a report to the integrator named the ring's turning as the cause and the commit as the fix, before the look was repeated. The repeat read 0.07 s. The report had to be corrected twenty minutes later, and two gate jobs had been started on a commit that was not final. The second explanation (more size classes emptied in turn than the ring has places) was tested first: it predicted that 12 sizes would show no system time and 40 sizes would, and that the BigInt product would not and its decimal string would. All four held; the change that followed removed the system time in the same look.

**Fix**:
1. Write the cause as a prediction that can fail ("with 12 sizes the system time is main's; with 40 it is not") and run it - a two-minute untimed look was enough.
2. Split the workload into its parts (the product, the string) to see which one carries the symptom.
3. Repeat the original measurement on the fix; only then write "fixed", with both numbers, in the commit and the report.
4. Until then the words are "hypothesis" and "not yet measured", and expensive gates wait for the repeat.

**Takeaway**: **A plausible mechanism plus a green test of the change is not the measurement: predict, measure, and only then name the cause - a wrong "fixed" costs a correction and every gate started on it.**
