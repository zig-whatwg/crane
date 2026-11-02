# Architecture: An engine callback without an isolate is answered from the isolate current on the asking thread

**Date**: 2026-11-02
**Lesson**: V8 asks its platform for Date's time (`Platform::CurrentClockTimeMilliseconds`) and for random seeds (`V8::SetEntropySource`'s callback) with no isolate argument, and both are process-wide. They can still be per Browser. Answer each one from the record of the isolate current on the asking thread (`Isolate::TryGetCurrent()`), and fill that record before `Isolate::Initialize`.

**Why**: The process-wide answers make two Browsers in one process identical. V8's `--random-seed` gives every context of every isolate one Math.random sequence (V8's own mjsunit.status skips d8-os in the isolates variant for that reason). The process clock gives every Browser one Date. Crane runs many Browsers per process, so neither process-wide knob can make a single Browser replayable. But V8 makes each isolate's random number generator lazily, on that isolate's thread, with the isolate entered: `Isolate::Initialize` enters it (13.1 api.cc:9897), and every later use is script's own. Date is read the same way, on the isolate's thread while script runs. So "the current isolate" identifies the Browser at every call that matters.

**What Happened**: The research notes said Crane's V8 adapter "already forwards" its clock to the platform backend. It did not: CranePlatform forwarded `CurrentClockTimeMillis` to V8's own DefaultPlatform, so Date never reached Crane. The integrator's grant asked for "byte for byte today's" behaviour when no Browser opts in. Lane detplat1 met that and still made both values per Browser:
- IsolateData gained a seed and a clock. They are set by `v8_Isolate_New*WithOptions` before Initialize.
- CranePlatform's three `CurrentClockTimeMilli*` read the current isolate's clock and fall back to the backend.
- One `V8::SetEntropySource` in `v8_Platform_Start` answers the current isolate's seed, and returns false otherwise, which hands V8 back its own entropy.
- The callback answers the same bytes every time rather than a stream. Whichever generator V8 makes first, the isolate's own gets the seed, so a replay does not depend on what an earlier isolate of the process made.
- tests/v8/detplat1_agent_clock_seed_test.zig failed 3 of 4 with the protocol options present but ignored, and passed once V8 read them.

**Fix**:
1. Put what the agent asks for in engine.AgentOptions (`clock`, `random_seed`) and gate it on a capability (`host_clock`, `seeded_random`). JavaScriptCore's public C API has neither hook.
2. Copy the option into the isolate's embedder record before `Isolate::Initialize`.
3. In the platform callback, look the record up through `Isolate::TryGetCurrent()`. With no record, or no field set, give the old answer.

**Takeaway**: **Before giving up per-instance behaviour because an engine knob is process-wide, check which thread asks. If the engine asks on the instance's own thread with its isolate entered, the current isolate's record is the per-instance answer.**
