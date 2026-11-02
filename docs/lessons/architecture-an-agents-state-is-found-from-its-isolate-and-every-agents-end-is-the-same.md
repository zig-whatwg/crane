# Architecture: An agent's state is found from its isolate, and every agent's end is the same

**Date**: 2026-11-02
**Lesson**: The V8 adapter kept its context manager - every realm's record - per THREAD, so it needed a "host agent" whose end took the thread's state down; that agent's end freed the realms of every other agent on the thread. Per-agent state found from the isolate needs no such role: every agent's end frees its own state and nothing else.

**Why**: A `threadlocal` is per thread, not per agent (lesson: a threadlocal is per thread, not per instance or tab). Once state is per thread, something must end it, and "the agent made with no isolate entered" (`AgentRecord.host_agent`) was chosen. It was right while one agent ran per thread. A second agent on the thread - a test's, one made inside another's script - put its realms in the same map, and the host's end freed them under it (lane v8order1's fifth mechanism; tests/v8 had to give every test its own agent to avoid it).

**What Happened**: Lane engown1 moved the context manager's map and retired list onto the agent's record (`context_manager.Realms`, `AgentRecord.realms`), found from the isolate (`protocol_agents.realmsOf`), as Blink finds per-isolate state through `V8PerIsolateData::From(isolate)` and WebKit through its VM's client data. The RED test (tests/v8/agent_realms_isolation_test.zig) makes two agents on one thread, ends the host first and asks the other agent's realm: on the old tree the realm was gone (freed). The same move then took five more threadlocal lists the adapter kept "per thread" - callback wrappers, module records, worker realm records, live wrapper caches, the Window-realm end stack - each a field of the record now.

Two details mattered:
1. **The teardown still looks its contexts up.** A realm's teardown runs code that asks the context manager for contexts. The old host-agent path ran with the threadlocal still set; the record must likewise stay findable while the agent's realms end. `forgetAgent` marks the record `ending` (so `recordOf`, which every hook accessor uses, answers null as before), the realms end, and only then does `removeAgent` take the record out. The narrow accessors the teardown needs (`realmsOf`, `callbacksOf`, `cachesOf`...) ignore `ending`.
2. **An isolate createAgent did not make hosts no realm.** Tests that registered realms in bare isolates (`v8_Isolate_New`, `worker_realm.createAgent`) relied on the thread's map; they make agents now. A bare isolate could already make no Window realm.

**Fix**: Per-agent state is a field of the agent's record, found from the isolate; the agent's end frees it; no step of the end depends on which agent ended first. A hot path that would otherwise take the agents lock per call keeps the pointer it found (`WrapperCache.peers`).

**Takeaway**: **If an agent's end frees state other agents use, the state is keyed by the wrong owner: find it from the isolate (Blink's V8PerIsolateData), end it with its agent, and keep it findable until its own teardown has run.**
