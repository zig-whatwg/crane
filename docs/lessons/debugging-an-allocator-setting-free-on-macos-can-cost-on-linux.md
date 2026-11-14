# Debugging: An allocator setting that is free on macOS can cost on Linux

**Date**: 2026-11-13
**Lesson**: A setting that changes when memory goes back to the operating system must be timed on every operating system a host runs before a default is proposed; and a measurement taken beside your own build on the same host is not a measurement.

**Why**: Returning a page and taking a fresh one cost a system call and a page fault, and what those cost is the kernel's, not the engine's. The published performance suite runs on one machine and one system. A result of "no row over the bar" there says nothing about the system the WPT generations and most servers run on.

**What Happened**: Lane v8up b8 measured V8 15.7's page pool turned off (`--no-memory-pool`): on macOS, timed, 48 workloads seven times, no workload over 3% on time or instructions and 9% of steady memory back - it looked like a free default. The same console's Linux build, seven runs on a quiet host: json.stringify 4.25 ms in all seven runs with the pool and 4.75 to 5.00 ms without it (+12%), timers.queue-microtask +5.5%, for 10% of resident memory. A one-second pool timeout was free on both. The first Linux run had been taken beside the lane's own gate build (load 16, 9, 3.5, 5, 32 across its five rounds): its means read +3.5% for both settings and two workloads looked 5% slower that were not, once the host was quiet. The user had already ruled "an option, default as Chrome ships"; the Linux reading is why that stayed the answer.

**Fix**:
1. Before proposing a default for anything that moves memory to or from the operating system, time it on each system Crane's hosts run: the published suite's machine, and Linux.
2. Where the tool for one system cannot run on another (perf_bench is macOS-only), drive the same pages with the per-mark driver and say which columns are missing (no instruction counts where the kernel forbids them).
3. Take the reading on a quiet host: put it at the end of a closed window, check that no other job runs, print the load at its start and end. A reading beside a build is thrown away, not averaged.
4. Report every workload over the bar with all its runs, per system, and put the per-system table where the option is documented, so a host chooses with it.

**Takeaway**: **Memory-return settings are priced by the kernel. One system's "free" is not evidence for another's: time the setting on each, on a quiet host, before any default is argued - and document the answer per system.**
