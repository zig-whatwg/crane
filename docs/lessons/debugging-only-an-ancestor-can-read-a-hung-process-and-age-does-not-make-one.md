# Debugging: On a host with no debugger only an ancestor can read a hung process - and age alone does not make a process hung

**Date**: 2026-11-13
**Lesson**: Where ptrace is limited to descendants and nothing is installed to attach with, the process that STARTED the hung one can still read its threads' system calls and stacks from /proc; decide "hung" by CPU time, never by age, and never signal a test process to make it talk.

**Why**: The pool's Linux host has no gdb, eu-stack, pstack or lldb; `perf` is closed to users (`kernel.perf_event_paranoid = 4`); and Yama's `ptrace_scope = 1` lets a process attach only to its own descendants. /proc applies the same rule to what a debugger would read: `/proc/<pid>/task/<tid>/syscall` (the blocked system call, the stack pointer and the program counter) and `/proc/<pid>/mem` answer "Operation not permitted" to a sibling and answer an ancestor. And a test suite's slowest tests look exactly like hung ones to a clock: the launcher starts the longest tests first, so they are all a hundred seconds old together.

**What Happened**: A ThreadSanitizer run hung about one engine test process in 900, with no output. Lane build3's first attempt was a sampler beside the run: every 5 s, any test process older than 100 s was logged from /proc, and the first three got a SIGSEGV so that Zig's handler would print a stack. Three things were wrong with it, and it cost a correction to the integrator:
1. It was a sibling: every `syscall` and `stack` read was refused, so it logged thread names and kernel wait channels and nothing more.
2. "Older than 100 s" matched the suite's slow tests. Four processes were signalled; two were tests at work (one had used 89 s of CPU) and became crashes in the measurement they stood beside.
3. The signals gave nothing: the sanitizer defers a signal sent to a thread blocked inside it, and a signal aimed at the runtime's own background thread trips a runtime CHECK instead of printing a stack.
What it did show was worth one line - the really hung processes had every thread in `futex_do_wait` and 0.02 s of CPU - and that line is the test that tells hung from slow.

The second attempt read, and touched nothing: a script that starts the test step ITSELF (`hangtrace.py <log> <age> zig build test ...`), so every test process is its descendant. For a process still alive after 150 s it samples CPU time over 2 s (asleep, or using CPU), and for each thread records the blocked system call and scans the thread's stack, from the stack pointer `syscall` reports to the end of its mapping, for words that point into executable memory, symbolized with `llvm-symbolizer` (one byte back from each return address, so the line is the call's). A scan is not an unwind - stale return addresses appear below the live frames - but the first dozen frames under a blocked call are the live ones, and it needs no register but the stack pointer. One run of tests/dom met two hung processes and gave both lock orders of the deadlock ([what it was](testing-a-suppressed-sanitizer-report-still-symbolizes-and-can-deadlock-on-the-loader-lock.md)).

**Fix**:
1. To read a process on such a host, be its ancestor: wrap the command that starts it. A helper started beside it, or by a different shell, is a sibling and is refused.
2. Hung means asleep: no CPU over a sampling interval, every thread blocked. A process that is using its CPU is a slow test, whatever its age.
3. Read, do not signal. The integrator's rule since: nothing of a lane sends a signal to any process on a pool host. A signal changes the measurement it sits in, and under a sanitizer it does not even produce the stack.
4. Before a first run, check what the host has (`command -v gdb eu-stack pstack lldb`, `cat /proc/sys/kernel/yama/ptrace_scope /proc/sys/kernel/perf_event_paranoid`) and say so; do not ask for root to change it.

**Takeaway**: **With ptrace limited to descendants, the launcher of a process is the one observer that needs no privilege: start the run from the script that will read /proc. Classify by CPU, not by age, and keep the observer read-only - a diagnostic that signals is an experiment on the thing it measures.**
