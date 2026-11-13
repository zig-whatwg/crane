# Workflow: A build step that "terminated with signal KILL" is the kernel's memory first

**Date**: 2026-11-13
**Lesson**: A compile or a generated tool that dies with SIGKILL in a pool build was almost always killed by the host's out-of-memory killer: read the kernel log before reading the tree, and look at free memory - not only at free build slots - before starting a root compile.

**Why**: Nothing in Crane's build sends SIGKILL, and a crash in the code would be a SEGV, an abort or a trap. SIGKILL comes from outside: the kernel's OOM killer, or a watcher ending a job. A root compile of an artifact that embeds the tree holds 7 to 9 GB resident near its end, so the number of root compiles a host can run at once is its memory divided by nine, whatever the slot count says. The killer picks by size, so it takes a compile, and it may take a bystander with it.

**What Happened**: Lane v8up b8's Linux console build on server1 ended "error: process terminated with signal KILL ... Build Summary: 113/118 steps succeeded (1 failed)", beside a failed snapshot generator line that looked like a defect of the merged tree. The same tree had just built twice on macOS. `journalctl -k` on the host had it in one line: "Out of memory: Killed process 2623799 (zig) total-vm:13348516kB, anon-rss:9056940kB" - and a second kill, of dbus-daemon, in the same second. Four build slots and a generation's gate were each in a root compile on a 61 GB host. The integrator cut the host's slots from five to four; the rebuild, started with 30 GB free, passed.

**Fix**:
1. On "signal KILL": `journalctl -k --since "<N> minutes ago" | grep -i "out of memory"` on the host (through the pool tool), then `free -g` and the largest processes by resident size. Report the kernel's line, every process it killed (another lane's job may be among them) and what was running.
2. Do not edit the tree, and do not count the failure as a gate failing for a reason you do not understand.
3. Before a root compile on a shared host, read `free -g`: wait when less than about 15 GB is available, slots or no slots.
4. Tell the integrator: the slot count is its to change.

**Takeaway**: **SIGKILL is never the code. Read the kernel log, name what else died, and size a host's concurrent root compiles by its memory - nine gigabytes each - rather than by its slots.**
