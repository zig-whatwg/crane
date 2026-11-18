# Workflow: Zig 0.17's Run.setEnvironmentVariable copies the whole configure-time environment, and a cached configuration replays it

**Date**: 2026-11-17
**Lesson**: In a Zig 0.17 build, a Run step that sets one environment variable carries a copy of the ENTIRE environment the configure process had; the configure cache does not key on the environment, so once the configuration is cached every later build runs that step with an old environment.

**Why**: `std.Build.Step.Run.setEnvironmentVariable` (and `getEnvMap`) starts from `graph.environ_map.clone()` - the configure process's environment - and the configuration serializes the whole map. At make time the Maker runs the step with exactly that map; only a step with no map of its own gets the Maker's current environment. The configure cache is keyed by build.zig, the command line and the declared path dependencies, never by the environment. While something poisons every configure the copy is always fresh, so the problem is invisible; it appears the moment the configuration is cached.

**What Happened**: Lane cfg1 made Crane's configure cacheable. Two kinds of Run step carried a copy: the engine-late test run (`CRANE_TEST_ENGINE_EARLY=0` for tests/v8's late platform start) and, under -Dsanitize-thread, the V8 snapshot generator's three runs (`TSAN_OPTIONS` through the protocol's `prepare_run` hook). With a cached configuration, `CRANE_TEST_STATE=report zig build test` would not have reached the engine-late run. The copy also hashes into the step's own cache key, so before the change each pool job's different `SSH_CLIENT` port made the step run again.

**Fix**: Pass the variable as an argument and let a program set it at make time over its inherited environment: the test launcher's `--child-env=NAME=VALUE` (into every process it starts), and for a program run directly, `env NAME=VALUE <program>` (the engine build protocol's `startupRun`, from `StartupRequest.run_environment`). `zig build check-configure-cache` fails on any Run step a configuration gives an environment of its own (build.zig `checkNoEnvironmentCopies`), under each gate's flag set.

**Takeaway**: **Never call Run.setEnvironmentVariable in a Zig 0.17 build: it freezes the configure-time environment into a cached configuration; pass the variable as an argument to something that sets it at make time.**
