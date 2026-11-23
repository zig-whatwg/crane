# Testing: Test executables must share production's thread-local layout, or Linux thread stacks diverge

**Date**: 2026-11-22
**Lesson**: A test executable whose static TLS block is larger than production's can be unable to start threads production starts. On Linux glibc puts a thread's static TLS inside its stack, so a thread made with a small fixed stack fails there.

**Why**: Every production root sets `std_options.signal_stack_size = null` (lane tls1). Otherwise Zig std's default is a 256 KB `threadlocal var signal_stack`, and each root's block is held to tools/thread_local_size_budget.txt (1,024 bytes). The Crane test runner (tests/test_runner/runner.zig) never set it, so every test executable carried a ~257 KB static TLS block (server1: PT_TLS MemSiz 0x40221). glibc's pthread_create fails with EINVAL when a requested stack cannot hold guard + static TLS + a minimal rest. V8's CPU profiler starts its ProfilerEventsProcessor thread with a fixed 64 KB stack (kProfilerStackSize), and CpuProfiler::StartProcessorIfNotStarted does CHECK(processor_->StartSynchronously()). macOS's dyld allocates TLS apart from the stack, so macOS never shows it.

**What Happened**: tests/devtools/tpf_console_webcompat_test.zig calls console.profile with the Profiler domain on. It passed test-verify 130/130 on chat2 (macOS) and crashed deterministically on server1 (Linux): "Fatal error: Check failed: processor_->StartSynchronously()", first run and alone. The suspects were all wrong: no SIGPROF problem, no second profiler, no profile started without the domain. Production was never affected. The release console's block is 444 bytes, and a page's console.profile through it starts and finishes a profile on Linux.

**Fix**: The test runner's std_options sets `.signal_stack_size = null`, as every production root does (test executable block: 537 bytes after, 262,689 before). build.zig now runs tls1's thread_local_size check on every test executable `addSuiteRun` runs (`launch.test_exes`), against the same budget file, as part of `zig build test`. A test executable can no longer drift from production's layout without failing the build.

**Takeaway**: **A test binary built with a different runtime layout than production tests a different program. Hold test executables to production's budgets (TLS here), and run a crash that only one OS shows on that OS before calling it fixed.**
