# Architecture: A host pointer an agent was given is only its creator's type

**Date**: 2026-10-30
**Lesson**: `engine.agentHost(agent)` hands back the `AgentOptions.host` pointer the agent was created with, and only the code that created the agent knows its type. Code that reaches an agent from a node or a realm - the DOM, the runtime tier - must not cast it to the Browser's `html.AgentHost`: ask the engine for what it needs by name (`engine.deferredTeardownOf`), or keep the thing on a type the protocol names.

**Why**: The protocol's `host` is `?*anyopaque` on purpose: a Browser passes its AgentHost, a worker host its own, and tests pass hosts of their own types (tests/v8: code_generation_checks, structured_serialization_wasm, xo2_cross_origin_objects, html_constructor) or null. A cast that is right for every Browser page is a write into an unrelated struct the first time a node of a test's agent reaches it.

**What Happened**: Refcount step 6's zombie audit found an agent's teardown queue and books as `@ptrCast(engine.agentHost(agent))` to `AgentHost`. It ran only under CRANE_REFCOUNT_AUDIT, in the WPT runner, where every agent is a Browser's, so it never met another host type. Lane refcount9's step 7 sink (`dom.refcount_teardown.settle`) first copied that lookup - and settle runs on every garbage moment, in every build and every test binary. The tests/v8 agents with foreign hosts would have had their structs written as an AgentHost's queue and books. Caught in review before the first test run.

**Fix**: A protocol operation, `engine.deferredTeardownOf(agent)`: the `AgentOptions.deferred_teardown` queue the agent was made with, handed back BORROWED, null when none was given - agentHost's sibling, which every adapter answers from its agent record. The switch's books moved from the AgentHost onto the queue itself (`DeferredTeardown.books`), a type the protocol names. tests/v8/rc9_deferred_teardown_of_test.zig makes an agent with a foreign host and a queue and checks both are handed back untouched.

**Takeaway**: **A pointer an agent was given is only its creator's type: never cast `agentHost` outside the code that made the agent - ask the engine for the thing by name, or keep it on a type the protocol names.**
