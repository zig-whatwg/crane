# Testing: A cgroup-dependent path is checked live in a systemd user scope

**Date**: 2026-11-17
**Lesson**: Code that reads the process's own cgroup (memory limits) can be run for real without sudo: `systemd-run --user --scope -p MemoryMax=...` around an already built test executable.

**Why**: The unit tests of such a rule take file texts; they cannot show that the paths, the files and the poller agree with a real kernel. A container needs a runtime and usually root; a transient user scope needs neither on a systemd machine with cgroup v2 (the user manager is delegated the memory controller).

**What Happened**: Lane mp2 (the Linux memory-pressure poller reading the cgroup's limit) needed a live check on server1. Building inside a 400 MB cgroup is impossible, and `zig build test` runs test executables through the launcher, so the check was two steps:

1. Build outside the scope: one scratch test appended to the MIRROR's copy of tests/platform/protocol_conformance_test.zig (never committed; the file restored right after the build), skipped unless an environment variable names an output file. The executable is in the mirror's cache: `find ~/crane-caches/<mirror>/o -maxdepth 2 -name platform_protocol_linux -newer <stamp>`; the launcher's path is in the build log.
2. Run inside the scope: `XDG_RUNTIME_DIR=/run/user/$(id -u) systemd-run --user --scope --quiet -p MemoryMax=400M -p MemorySwapMax=0 bash -c '<launcher> <executable> --name=live --batch=1 --timeout=120 "--filter=*LIVE*"'`. The scratch test made a Browser's platform state with a sink that wrote each event, filled its own cgroup by page-allocating until memory.current reached 92 % and then 97 % of memory.max (reading the files itself), then freed: warning, critical, normal, each within one poll.

Fill to a percentage of the limit read back from memory.current, never by a fixed size: the executable's own pages and its page cache are charged to the scope too. `MemorySwapMax=0` keeps the figure from draining into swap.

**Fix**: For a path that depends on the process's cgroup: build first, then run the cached executable through the launcher inside a transient user scope; print the scope's `/proc/self/cgroup` line and its memory files beside the result, and run the same executable outside the scope as the control.

**Takeaway**: **A transient systemd user scope is an unprivileged cgroup with a real limit: build outside it, run the cached test executable inside it, and fill to a percentage read from memory.current.**
