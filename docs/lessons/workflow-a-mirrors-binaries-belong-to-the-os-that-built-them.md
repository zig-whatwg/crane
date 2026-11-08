# Workflow: A mirror's binaries belong to the OS that built them - the pool places by OS before capacity

**Date**: 2026-11-08
**Lesson**: When the compute pool mixes operating systems, a mirror's jobs and runs stay on its home's OS, a job that needs one OS says so, and a move across OSes never copies the binaries.

**Why**: Until server1 joined (x86-64 Linux), every pool host was arm64 macOS, so a mirror's zig-out/ and <mirror>-bins/ ran wherever the pool sent it, and pool_follow copied them to the new host with `rsync --update` (newer wins). With two OSes, three things break silently: a WPT run sent to the host with the most free tokens runs a Mach-O runner on Linux (or a stale Linux one); a move back copies a newer ELF over the Mach-O build; and a macOS-only measurement (leaks --atExit, MallocScribble, an apple_m1 perf console) placed on Linux either fails or measures something incomparable.

**What Happened**: Lane linux1 batch 2 added server1 to tmp/remote/pool-hosts.txt. Placement was by free slots x weight and free runner tokens alone, and server1 (weight 3, 32 tokens) would have taken the next run of any mirror.

**Fix** (tmp/remote, lane linux1 b2):
1. pool-hosts.txt lines are `<host> <weight> <os> [roles]`; `generation` and `perf` are roles (the hosts of `--pair generation` and `--pair perf`), so moving the generation sweeps is a one-word edit.
2. A job's OS: macOS when the command names leaks --atExit, MallocScribble, check-ios, apple_m1 or perf_bench; else `--os macos|linux|any` (crane-remote.sh, crane-pool.sh wpt); else, for a WPT run, its --pair host's OS; else macOS. The first version defaulted to the mirror's home's OS, and a NEW mirror went anywhere: perf3's apple_m1 build, run from a script, landed on server1 within the hour and had to be killed - so a job runs on the new OS only when it asks (the integrator, 2026-11-08). Hosts of another OS are never eligible.
3. A WPT run whose OS differs from its mirror's binaries, or a pair on another OS, is refused with what to build - never placed.
4. Only a build with `--os` moves a mirror across; pool_follow then copies tmp/ and results, not zig-out/ or <mirror>-bins/.

**Takeaway**: **In a pool of mixed OSes, place a job by OS before capacity, and let the new OS take only the jobs that ask for it: a mirror's binaries belong to the OS that built them, so its runs follow them, and a cross-OS move copies results but never binaries.**
