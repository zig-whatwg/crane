# Debugging: A starvation timeout on a shared host may be paging, not a wait in the code

**Date**: 2026-11-23
**Lesson**: Before blaming a test's slowdown under load on a wait in Crane, measure what CPU starvation alone costs it, and read the host's memory pressure. A slowdown far beyond the CPU share, seen only beside other lanes' builds, is likely the host paging the test's memory.

**Why**: Busy loops take a CPU share: a test that competes with one spinner per CPU should run about 2x slower, whichever OS schedules it. A wait that assumes background threads progress (V8's workers, a lock, a spin) would amplify that, and so would macOS QoS, which pushes lower-QoS threads onto the E cores. Both are testable in an afternoon. The host's own state is not part of the test, and it is easy to forget.

**What Happened**: mem1_kept_edge_teardown_test's 2,500-join test (25 s of script CPU quiet) did not finish in 900 s on chat2 under one busy loop per CPU, while other lanes' gates were building there (load 20-46). That is 36x, more than a CPU share explains, so lane flk4 looked for the wait (item 6, 2026-11-23):
- server1 (Linux), the test and one busy loop per CPU pinned to the same 8 CPUs: 29.6 s pinned and quiet, 61.3 s starved (2.1x). An ancestor tracer (.flk4/stalltrace.py, from lane build3's hangtrace.py) read the process using 50% of a CPU, nothing asleep.
- chat2 (macOS), in a drained window, 8 normal-QoS plus 8 background-QoS busy loops: 25.2 s quiet, 48.4 s starved (1.9x). `sample` showed the main thread and all 7 V8 DefaultWorker threads on CPU.

So neither a starved-background wait nor macOS QoS: CPU starvation costs its share and no more. What the 900 s run had that these did not was the other lanes' root compiles (about 6 GB each) on a 24 GB host. `sysctl vm.swapusage` read 4.9 GB of 6 GB of swap in use. Paging the test's memory, not a Crane wait, is what a 36x slowdown beside builds most likely is.

**Fix**: Nothing in Crane. For the next such report:
1. Run the test quiet, then starved by CPU alone (Linux: taskset onto N CPUs beside N spinners; macOS: a drained window with normal- and background-QoS spinners). A slowdown near the CPU share means no wait in the code.
2. Read the host: `sysctl vm.swapusage` and `vm_stat` (macOS), `free -m` and `vmstat 1` (Linux), at the time of the slow run if possible.
3. Only a slowdown well past the CPU share with the host NOT paging is worth stacks (an ancestor tracer on Linux, `sample` on macOS).

**Takeaway**: **Measure the CPU share first and read swap second: a test 36x slower beside other lanes' builds, but only 2x slower beside busy loops, is the host paging, not the code waiting.**
