# Workflow: A build-graph change cannot be timed at the pool shim's -j1

**Date**: 2026-11-04
**Lesson**: A change that lets two steps of a build run side by side saves nothing at -j1, and in a pool job the -j is not yours: the hosts' zig shim replaces it with the host's fair share of root compiles (free memory / 6 GB, minus 3 for each heavy ReleaseSafe runner build, divided by the builds holding slots), which on a shared chat2 is 1.

**Why**: lane console3 moved the console's dependency on the snapshot generator from its compile to its install, so the generator's 3-minute compile could run beside the console's 13-minute one. Timed on chat2 with another build in the second slot, the "before" took 999 s and the "after" 1059 s: both were serial, because the shim granted -j1 to each build, and at -j1 every order of the same steps costs the same.

**Fix**: read the step durations from `--summary all` and report the critical path (before: generator 3 m + run 1 s + console 13 m in a chain; after: the longest of the two branches), and time the wall clock only where the shim grants -j2 or more: print what the shim will grant (the builds holding `~/crane-slots/*/holder`, the free + inactive memory) in the same job, as `.console3/pair.sh` does, and time both sides back to back in that job.

**Takeaway**: **Before timing a change to a build's step graph, know the -j the build really ran with. At -j1 a parallelism change measures zero; report the critical path from the step times instead.**
