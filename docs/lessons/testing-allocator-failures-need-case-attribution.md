# Testing: Attribute allocator failures to their cases

**Date**: 2026-10-28
**Lesson**: Separate assertion results, allocator diagnostics and interventions before deciding whether a failure belongs to the product or its fixture.

**Why**: A test can satisfy every behavior assertion while retaining an entire model graph. The allocation stack names where that graph was created, which may differ from the missing release. A build-server test runner can buffer those diagnostics and restart a test process after a signal.

**What Happened**: The nested CSS rule model test reported passing assertions in three native helpers but retained their sheet and selector data. A separate all-allocation-failures case proved a three-byte product leak: allocating a layer name succeeded, then appending it to the list failed. While the test runner spent minutes formatting the leak stacks, an approved diagnostic SIGTERM interrupted one case. The build summary counted that signal as a crash; it was not evidence of an engine crash. The completed cases reported 202 leaks, while the raw log also contained 235 markers from the interrupted case. An initial claim that wrapper-construction frames were printed was wrong and was corrected: the printed frames were model allocations; the wrapper lifetime was a code-derived hypothesis.

**Fix**: Preserve the original fixture and complete log. Group the allocator traces under their exact case headlines. Report the intentional signal separately, and retain both structured counts and raw-marker counts without pretending they measure the same set. Repair the directly demonstrated name-allocation rollback independently. Use a separately approved fixture-only comparison, with every assertion and the allocator unchanged, to test the lifetime hypothesis. Here, the three helpers switched to directly constructing and destroying one generated-interface wrapper each; all 16 model cases then passed with zero leaks. The old plain-context parent-chain path is no longer exercised by that model fixture. Four separate real-Window holder cases passed their GC, parent-chain, expando and SameObject checks without an extra getter edge.

**A related trap**: DWARF frames in a process sample do not themselves mean leak reporting. During the later full gate, the existing dropped-NodeList stress test spent time in DebugAllocator.captureStackTrace while allocating and freeing parser nodes. Its caller chain was the running innerHTML loop, with no detectLeaks frame; the complete gate then passed. Distinguish stack capture on ordinary allocation from formatting a reported leak.

**Takeaway**: **A plausible missing release is a hypothesis until the evidence separates it from the fixture; a passing assertion is not a leak-free test.**
