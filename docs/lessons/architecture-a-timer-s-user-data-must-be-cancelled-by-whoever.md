# Architecture: A timer's user_data must be cancelled by whoever frees it

**Date**: 2026-09-22
**Lesson**: `workerMessageDispatchCallback` was armed as a 0ms timer carrying a
bare `*DedicatedWorker`, and nothing ever cancelled it, so it fired into freed
memory in whichever test the same process ran next.

**Why**: The timer manager lives as long as the process's browser; a Worker
lives as long as its page, or until GC. A dispatch armed as the page ended
outlived the worker by a whole test file.

**What Happened**: One CRASH in every sharded run of `html/webappapis/timers/`,
in a file with no worker in it - `negative-setinterval.any.js`, behind
`cleartimeout-clearinterval.any.js`. Run alone, 5 of 5 were OK. The journal
said only `SIGABRT` and the runner kept no stderr. The stack was in
`~/Library/Logs/DiagnosticReports/wpt_runner*.ips`: `KERN_INVALID_ADDRESS at
0xaaaaaaaaaaaaaaaa` in `processQueuedMessages`, under
`workerMessageDispatchCallback`, under `NativeTimerManager.poll`, inside the
NEXT file's `waitForCompletion`. 17 of the day's 179 crash reports carried
this signature. Where the freed block had been reissued instead of poisoned,
the callback would have written into whatever object lived there - which is
what the sweep-only "garbage IFrameIntegration" and NULL `browsing_context`
crashes look like.

**Fix**: the timer carries the `WorkerV8Context`, which records the armed id,
and `WorkerV8Context.deinit` cancels it; Worker teardown runs that before
`DedicatedWorker.deinit`. The callback clears the record the moment it
fires, so a record still present is a timer that has not fired, and
`NativeTimerManager.poll` re-checks every due id before firing.

```bash
ls -t ~/Library/Logs/DiagnosticReports/ | head          # newest first
python3 -c 'import json,sys; h,b=open(sys.argv[1]).read().split("\n",1); j=json.loads(b);
print(j["exception"]); t=j["threads"][j.get("faultingThread",0)];
print("\n".join(f.get("symbol","?") for f in t["frames"][:20]))' <file.ips>
```

**Takeaway**: **A crash that moves between files in a sharded run and never
reproduces alone is a callback from the previous file.** macOS keeps the stack
the runner discarded; read the newest `.ips` before theorising.
