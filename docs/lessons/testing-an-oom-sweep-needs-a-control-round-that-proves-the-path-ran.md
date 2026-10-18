# Testing: An out-of-memory sweep needs a control that proves the path ran

**Date**: 2026-10-18
**Lesson**: Lane leaks4's javascript: URL sweep set `src` on an iframe that has a srcdoc attribute - which changes nothing (HTML 4.8.5) - so every round navigated nothing and the sweep passed vacuously.

**Why**: A sweep fails the i-th allocation of an operation and checks an invariant after it. The invariant ("the frame's document has the page's policy") holds just as well when the operation never ran. The sweep ends at the first round that fails no allocation, and nothing asked whether that round - the one with memory to spare - did what the test is named for.

**What Happened**: Lane leaks5 moved the javascript: and data: navigations to a second frame with no srcdoc. Both sweeps then panicked at once, in HTMLIFrameElement.resolveSrc's `catch unreachable`, which the vacuous sweep had never reached.

**Fix**: Run the operation once with memory to spare, before the sweep, and assert its effect: the frame's Window shows a different Document (address and slab generation - a freed document's slot can be reused). A check at the END is not enough on its own, but run it once: lane leaks5's showed that the frame stops navigating at all after a round that fails between the old document's unload and the new one's commit (a wedged navigable, reported as a follow-up), so every later round tested nothing new.

**Takeaway**: **Prove the swept operation does something - run it with memory to spare and assert its effect - and check once whether the rounds leave it able to run again: a sweep whose operation never ran passes every invariant.**
