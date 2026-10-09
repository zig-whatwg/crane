# Debugging: A worker thread's crash is journalled against a later file

**Date**: 2026-10-09
**Lesson**: When a worker's thread segfaults, the runner's handler spends more than ten seconds printing the stack while the window thread goes on running tests. The abort lands, and the journal records CRASH, against whatever file is running by then - not the file whose worker crashed.

**Why**: Zig's segfault handler unwinds the faulting thread before it aborts. Through V8's frames the unwinder never finds the bottom: it prints `_Builtins_CallApiCallbackGeneric` until "Stopping trace after 10001 frames", symbolizing each frame. Only the faulting thread stops. The supervisor names the file the child was running when the process died.

**What Happened**: navflip's sweep recorded `WebCryptoAPI/algorithm-discards-context.https.window.js` as CRASH (SIGABRT after "Segmentation fault"), and the lane wcrash brief read it as a teardown crash in that file. In the logs of two reproducing runs, the `Segmentation fault at address 0x...2a0` line sat in the middle of `IndexedDB/transaction-inflight-worker-terminate.window.js`, 13 test URLs earlier: the stack was IDBTransaction's on the worker's thread (a task freed by a closing worker's queue). The window thread finished those 13 URLs and started the 10-second WebCrypto file before the print ended and the process aborted. The crash also reproduced only under load: 0 of 12 single-process runs of the 35-file prefix alone, 2 of 24 as four concurrent single-process streams.

**Fix**: To find which file a crash belongs to, grep the run's log (`grep -a -n 'Segmentation fault\|panic:'`) and read the progress lines around it. The file running when the fault line was printed is the crash's; the journal's CRASH file is only where the abort landed. If a sweep-only crash does not reproduce in single-process runs of its prefix, run the prefix as several concurrent streams before bisecting: the sweep ran under load.

**Takeaway**: **The journal names the file running when the process died, which is not always the file that crashed. Find the fault line in the log first; a worker thread's fault can be printed many files before the abort.**
