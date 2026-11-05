# Testing: A chunked sweep waits for its slowest shard - compare summed file wall before blaming the tests

**Date**: 2026-11-04
**Lesson**: Crane's full worklist run took 2,353 s against Chrome's 1,647 s. Yet Crane's per-file walls summed to 1,348 s per runner against Chrome's 1,539 s. 905 s, 38% of Crane's wall, was runners idling at chunk barriers.

**Why**: `crane-measure.sh sweep` cuts the worklist into chunks of CHUNK=200 files. Each chunk is one wpt_runner that splits its files into static shards, 40 per runner with 5 runners, and the next chunk starts only when the slowest shard ends. A 60 s timeout in a shard of 40 holds the whole chunk for at least 60 s while the other four runners finish in 10-20 s. wptrunner feeds its processes from one queue, so a slow test delays only its own process. The release runner (ReleaseSafe throughout, libc malloc) was no faster than the correctness runner (2,353 s against 2,280 s): the files' wall is waiting (test timers, timeouts), and the barrier is the same for both.

**What Happened**: Asked where Crane's wall goes, the obvious answer was timeouts. Summing each engine's per-test wall by final status showed timeouts take the same share in both, 21.3% for Crane and 21.6% for Chrome. Per chunk, the chunk's wall is its `.done` time minus the previous one's, against the slowest and the mean shard's summed `wall_ms`:
- 66 chunks: 2,353 s = slowest shards 2,252 s + start-up/teardown/acquire 101 s;
- the mean shard, which a balanced pool would need: 1,348 s.

**Fix**: Before attributing a wall-time gap to the engine, the tests or the build mode, compute the pool's utilization: summed per-file wall / runners / wall. Crane's was 57%, Chrome's 93%. Glob `journal.shard*.jsonl` but drop `*.wptreport.jsonl`, which matches the same pattern and halves a per-shard mean. The structural fix is a shared queue across the sweep, or larger chunks; it is engine-side work and was not made here. Projected, not measured: Crane's run at about 1,450 s.

**Takeaway**: **Sum the per-file wall before explaining a wall clock: a chunked, statically sharded sweep pays for every chunk's slowest shard, and that barrier, not the tests, was 38% of Crane's wall.**
