# Workflow: A measurement console with switches makes each candidate one run of one binary

**Date**: 2026-11-12
**Lesson**: When each build of the product takes eight minutes or more, put the candidates of an investigation behind switches in ONE uncommitted measurement build and run the whole benchmark under each: a configuration costs a run, and every comparison is the same binary.

**Why**: The port's memory investigation had spent a console build per hypothesis (a build per V8 flag set through -Dv8-extra-flags: 8-12 minutes each on the pool, plus the freeze), so each batch tried two or three ideas. The product may read no environment variable for V8 flags (snapshot_loader.zig says why), but a measurement patch that is never committed may.

**What Happened**: `.v8up/b7-diag2.patch` added to v8_wrapper.cpp: `CRANE_DIAG_V8_FLAGS` (applied after the product's flags), `CRANE_DIAG_FIRSTPASS=1` (the candidate fix behind a branch) and a SIGUSR1 heap dump. perf_bench passes its environment to the engine it launches, so `perfexp-b7.sh` ran the 48-workload suite three times under each of eleven configurations in 45 minutes, one engine pinned, and printed one matrix: memory per row per configuration, geometric means against main, time and instructions against the session's first configuration. The same binary on both sides of every comparison removed the build-to-build band (about 1% of instructions here).

**Fix**: The candidate that the numbers kept was then written properly - test first, no switch - and the final table re-measured on consoles built from the committed tree (a flag candidate through the existing -Dv8-extra-flags route).

**Takeaway**: **For one-change experiments, build one measurement binary with the candidates behind switches (never committed; the product reads none of them), check that the benchmark tool passes the environment through, and run each configuration as its own session with a control first. Then rebuild only the winner from committed code for the numbers that go in the report.**
