# Testing: A faster build mode is a different engine until a sweep says otherwise

**Date**: 2026-10-01
**Lesson**: A ReleaseSafe wpt_runner made the worklist's slowest passing file 5.9x faster, and it passed every file it was tried on by hand. On 2,100 worklist files it crashed 667 times and turned 290 passing files into timeouts.

**Why**: an optimised build keeps Zig's safety checks, and the C sanitizer still traps on C/C++ undefined behaviour. What it does not keep is the behaviour of undefined behaviour that a Debug build happens to get away with. Here a JSValue handle reached v8_Global_Clone (EventTarget.innerInvoke -> engine.retainValue -> ownHandle) not 8-aligned, and the sanitizer's alignment trap fired (SIGTRAP, brk #0x5516, no message). The Debug build compiles the same check (a call to ubsan_rt.typeMismatch, which panics), and it never fires there. So the handle itself differs between the builds, which is undefined behaviour upstream. The legacy-mb encoding decode files also hung to the stall kill, where in Debug they pass in 49 s.

**What Happened**: the speed lane measured NodeList-static-length-getter-tampered-1.html at 130 s in Debug and 22 s in ReleaseSafe. It checked the allocator's reports in both modes and ran four files by hand, then built a candidate on top of ReleaseSafe. The first five chunks of a 3-runner ReleaseSafe sweep had already finished, but they were not read before that sweep was stopped for other work. The parity run that was finally read showed 964 status differences.

**Fix**: ReleaseSafe stays opt-in (`-Dwpt-runner-optimize=ReleaseSafe`) and Debug stays the default. The crash and the hangs went to the integrator as engine work. The allocator pins (`runner_allocator.zig`) and `--allocator-self-check` stay, because they are right in every mode.

**Takeaway**: **A build-mode change is a change to every file's result: read a sweep's statuses against the old mode before building on it. A timing win on the files you looked at says nothing about the other ten thousand.** Read every chunk a sweep finishes, even one you stop. The first chunks are the cheapest place to find out.
