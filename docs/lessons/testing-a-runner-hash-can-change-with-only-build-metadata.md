# Testing: A Runner Hash Can Change With Only Build Metadata

**Date**: 2026-10-17
**Lesson**: A different executable hash requires investigation; it does not by itself identify a change to executed code.

**Why**: A Mach-O executable also records build identity, debug-map object paths and timestamps, and code-signature hashes. Recompiling unchanged production code can change those bytes.

**What Happened**: The scripting lane corrected one line inside a `builtin.is_test` namespace. The optimized runner and snapshot rebuilt successfully. The snapshot was byte-identical, but the runner's whole-file SHA256 changed. The gate required the lane to ask before reusing its measurements. A read-only comparison found identical addresses, offsets, sizes and hashes for all 20 code/data sections. Just 145 bytes differed: the UUID, one N_OSO debug-map record's object timestamp and cache path, and signature hashes. The integrator accepted that evidence and retained the original measured runner.

**Fix**: Preserve both artifacts and their complete hashes. Record the exact source-tree delta. Compare section layout and contents, load commands and every remaining changed byte range; account for zero-fill sections too. Keep the comparison table with the gate report. Ask the gate owner to rule on reuse when its identity condition fails. Never strip, re-sign or relabel the measured artifact to manufacture a matching hash.

**Takeaway**: **Prove what differs before reusing measurements.** “The source change was test-only” is a reason to investigate, not evidence that two executables behave identically.
