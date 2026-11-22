# Debugging: A flake that hits two runners at the same instant is a host stall - measure the race's margin, base against tip

**Date**: 2026-11-22
**Lesson**: To decide whether a change made a test's race likelier, run base and tip side by side under the same load for a rate, and probe the race's own margin with a server-side request log; two processes failing the same way at the same moment points at the host, not the change.

**Why**: A sweep's single flake cannot say whether the tip got worse. Rates near zero need hundreds of runs to compare, and a race inside the test (an iframe's onload calling a function a LATER parser-blocking script defines) depends on how far ahead the winning request is - which a probe can measure directly.

**What Happened**: In lane tpw's FULL A/B of cdp/main, Document-parseHTMLUnsafe-url-base.html and -pushstate.html ERRORed ("window.resolveLoadPromise is not a function") on their first run and passed on retry. Both ran in different runner processes at the same instant (shard 15 file 19, shard 17 file 4). Base and tip, 200 isolated runs and 30 inside their whole directory at 32 runners, side by side: 0 failures each. A scratch probe (a `.sub.html` with `{{$k:uuid()}}` naming an iframe and a parser-blocking script, a `.py` handler appending `name@time` to `request.server.stash` under its lock) showed the tip sends the script request BEFORE the iframe's 60/60 (base 16/60) and its margin - iframe subresource arrival minus script arrival - was median 5.1 ms (base 2.3 ms): the tip made the race safer, and the sweep's event was a momentary server stall. It did not recur in the next full sweep. The modulepreload-referrerpolicy flake in the same sweep read the same way: base 2/200, tip 2/200, every failure an earlier test's referrer (the test's uid collision).

**Fix**: `.tpw/flake.sh` in the lane: both runners, `--repeat=N`, same list, started together through crane-measure.sh, tallied per file. Probe files go into the host's served tree only for the measurement and are deleted after.

**Takeaway**: **Compare a flake's rate on base and tip under one load, and measure the race's margin at the server - never call a one-off flake a regression or a non-issue from the sweep alone.**
