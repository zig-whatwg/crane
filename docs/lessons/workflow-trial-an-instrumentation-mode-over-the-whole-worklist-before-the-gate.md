# Workflow: Trial an instrumentation mode over the whole worklist before the gate sweep uses it

**Date**: 2026-10-19
**Lesson**: An opt-in runner mode measured on a sample is not proven on the worklist; turning it on in the gate sweep without a full trial published a false generation.

**Why**: A gate sweep's journal becomes the public generation and every lane's A/B baseline. Anything that changes how the runner runs - instrumentation, allocator modes, timeouts - changes the numbers, and a sample can miss both crashes and costs that only some files trigger.

**What Happened**: Lane leaks6 added per-file leak attribution (CRANE_LEAK_FILES=1), measured at +18% on 1,200 files and verified on leaking chunks. The integrator added it to ~/crane-gate-main.sh's sweep for main f85001892d and published the result without comparing it to the previous generation first. Generation 170 read 1,591,877 passing (-78,070) and 367 blocking (+18): 5 files aborted only with attribution on (CSP embedded-enforcement iframes, iframe-failed-commit), and 14 allocation-heavy encoding/fetch/crypto files timed out, because a per-allocation hash map costs far more than 18% where almost all the work is allocation.

**Fix**:
1. Reverted the gate script (atomic .new + mv) and re-swept the same main without it.
2. Reproduced both effects on the frozen runner with the mode off and on, same list, to prove the code itself was not regressed.
3. Queued the crash and the cost (feature-queue LEAK ATTRIBUTION IS NOT SWEEP-SAFE): a full-worklist trial against an unattributed sweep, equal results, is the bar before re-enabling.

**Takeaway**: **A runner mode enters the gate sweep only after a full-worklist trial matches an unmodified sweep file for file - and a generation is compared with the previous one (blocking, passing, regressed) before gh-pages is pushed.**
