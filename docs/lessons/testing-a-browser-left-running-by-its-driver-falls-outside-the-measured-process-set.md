# Testing: A browser left running by its driver falls outside the measured process set

**Date**: 2026-11-06
**Lesson**: safaridriver (Safari 27.2) leaves the automation Safari (`Safari ... --automation`) running after Delete Session, so every later launch reuses one browser. Its app, WebKit.Networking and WebKit.GPU processes started before those launches, and a set that counts named processes only from the launch on left them out.

**Why**: Safari's processes are launchd's, not safaridriver's children, so tools/perf_bench names them, and counts only those started at or after the launch, because a WebKit process already running may belong to another app. That rule is right only if each launch starts its own browser. A driver that keeps the browser between sessions breaks the premise, and nothing fails: the set is just smaller.

**What Happened**: in perf round 0's first window (2026-11-06), Safari's rows held 3 processes, with a median steady footprint of 75 MB. Chrome's held 10-11 processes and 463 MB. The headline said Crane used 329% of Safari's memory. Listing the processes on chat.local after the window showed the automation Safari still running, started at 23:42:17 UTC by a smoke run in the gap before the window. Every Safari launch in the window had used it. The in-page times were sound: each launch had its own WebContent process. The memory, and the process-set CPU, were not.

**Fix**: a launch is refused while its engine's app runs (`Launch.app_names`, `runner.appRunning`). At its end, the runner ends the app processes started since the launch, by exact pid (`endProcesses`: SIGTERM, then SIGKILL after 5 s). The rerun's smoke held 7-8 processes. Safari was re-measured in a second window, alternating with Crane ReleaseSafe as a drift control (`perf_bench report --control`), and its new rows replace the first window's only if the control is within noise.

**Takeaway**: **Before trusting an engine's memory, check its process count against its architecture, and check that each launch really started its own browser: a driver that keeps the browser alive turns "fresh process per launch" into a silent undercount.**
