# Workflow: A browser's WPT run beside Crane's is a reference, never a journal

**Date**: 2026-11-04
**Lesson**: Run the browser with WPT's own runner on an APFS clone of the same tree, mark every record it yields with its engine, and keep it below where journals are read. Time each harness at two sizes, and its CPU two ways, before reading a wall-time comparison.

**Why**: The progress report and the site take the newest record per test file from any `*.jsonl` in `wpt-results/` or one directory down. A browser's results placed there do not sit beside Crane's: they *replace* them. The self-test written red for this lane showed it: a journal under `wpt-results/reference/` overwrote Crane's record of the same file. Timing a browser against Crane also has its own traps. Each harness has a fixed start-up, and a whole process tree's CPU is not what `rusage` reports.

**What Happened**: Lane chromeref1 put Chrome for Testing 157 on the 0.1 worklist (the user, 2026-11-03: "I want the chrome results on the same files represented in our progress report").
- **wptrunner cannot use the pool's shared `wpt serve`.** It always starts its own wptserve, with routes `wpt serve` lacks (`/testharness_runner.html` and its own `testharnessreport.js`). Its default ports are the shared server's, so it would collide. Chrome ran from a `cp -c` clone of the shared tree, with the clone's `config.json` moving every port by +10000 and the clone's own manifest. The clone holds the same bytes, costs no disk, and took 25 s; its manifest update took 16 s and gave the worklist header's 17,663 URLs exactly.
- **Start-up dwarfs a test.** wptrunner took 6.2 s for 50 empty tests and 8.9 s for 200. That is 7.7 s of start-up (loading the manifest, starting servers and browsers) and 39 ms per test per runner. Read from one size, the start-up becomes per-test cost, and multiplied over 17,663 URLs it is wrong by minutes. Crane's runner: about 1.5 s of start-up and 67 ms per test per runner.
- **`rusage` misses Chrome's CPU.** `/usr/bin/time -l` counts only the processes their parents waited for. In the pilot, sampling the run's process tree once a second gave 120.1 s against `rusage`'s 100.5 s for Chrome. Over the full worklist the gap was 4,822 s against 3,499 s. For Crane the two agreed (30.3 s and 32.3 s; a sample misses up to a second of each short process).
- **Name each side's build before comparing.** The first Crane run in the window was the correctness runner: a ReleaseSafe root, but Debug Crane modules with the refcount ledger, the DebugAllocator and the full C sanitizer. Chrome for Testing is an official release. The user cancelled the run for that reason. The comparison now uses `-Dwpt-runner-release`: ReleaseSafe throughout, C at `.trap`, libc malloc. It still links V8 13.1.203 built without ThinLTO or PGO, beside Chrome 157's V8 15.7.112.23, and the page says so.
- **Memory needs the same per-second sampling on both sides.** Each process's phys_footprint comes from `proc_pid_rusage(RUSAGE_INFO_V4)`, summed per tree and split into engine and harness. For Chrome over the full worklist: engine peak 6.41 GB, mean 4.12 GB; harness (wptrunner, wptserve, chromedriver) peak 2.05 GB. RSS sums reached 24 GB, because they count shared pages once in each process.
- **Crane's runner uses the host's shared server, which is not its child.** That server's CPU over the run had to be measured and added for a fair comparison.
- **A dropped ssh ends a window script at its next `echo`.** The script runs without a pty, so sshd's death sends no SIGHUP. But stdout is a pipe whose reader is gone, so the next echo raises SIGPIPE. The window's script survived the drop at 12:56 UTC, but only until its Chrome step ended.

**Fix**:
1. Store a reference run only as `wpt-results/reference/<engine>-<version>/reference.json`: a `.json` name no journal glob reads, two directories down. Write it with `zig build wpt-site -- import-reference`, which joins the wptreport to the worklist through the manifest the run used and refuses a report of another product.
2. Every record a reference run yields carries `"engine"`. Both readers of journals (tools/wpt_progress.py and generate.zig) refuse any record or stream line whose engine is not Crane's, with a message, and never read `wpt-results/reference/`.
3. Compare the files both engines ran. Name the rest, never fold it in.
4. Time each harness's empty tests at two sizes. Split each run's wall clock at that rate over the URLs it ran.
5. Take a run's CPU as the larger of `rusage` and a once-a-second sample of its process tree, plus its share of any server it did not start.
6. A window script ignores SIGPIPE (`trap '' PIPE`) and keeps every result in files, so a dropped caller costs only its log.

**Takeaway**: **Another engine's results are a reference: give them their own server, their own marked records and their own directory, and measure each harness before comparing wall clocks.**
