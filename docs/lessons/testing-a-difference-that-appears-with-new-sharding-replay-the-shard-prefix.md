# Testing: When a result moves only under new sharding, replay the shard's prefix serially

**Date**: 2026-10-01
**Lesson**: Raising a sweep from 3 runners to 8 kept every one of 4,712 statuses, but two files lost subtests they had kept in 26 earlier sweeps. One loss was load. The other was state carried from an earlier file in the same process, and the new shards had put a different file in front of it.

**Why**: a runner process runs its shard's files one after another, in one agent (and its workers' agents). When the shard count changes, so does the list of files that precede each file in its process. A file whose result depends on what ran earlier in the process passes or fails according to the shard layout, which looks like noise from the concurrency change.

**What Happened**: in the 8-runner sweep, xhr/idlharness.any.js went from 344 to 342 and websockets/Create-blocked-port.any.js from 502 to 501. Solo runs gave 344 and 502. A serial replay of each file's shard prefix (`--from-file` with the shard's worklist up to the file, `--parallel=1`) gave 342 (2/2) and 502 (2/2), so idlharness carried state and blocked-port depended on load. Pairing each of the 29 prefix files with idlharness found a single trigger: workers/modules/shared-worker-options-credentials.html run just before it. After it, the dedicated-worker variant's XMLHttpRequestEventTarget.prototype is no longer chained to EventTarget.prototype. Create-blocked-port's lost subtest makes a real WebSocket handshake to wpt serve, which failed in one more variant under load.

**Fix**: none here. The trigger went to the integrator as an engine bug (the per-isolate template caches kept in process globals). The concurrency change stood, because no status moved.

**Takeaway**: **A difference that appears only when the sharding changes is either load or file order. A serial replay of the shard's prefix tells them apart in minutes, and pairing each prefix file with the target finds the trigger.**
