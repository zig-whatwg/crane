# Architecture: An agent's role is recorded when it is made

**Date**: 2026-09-28
**Lesson**: `protocol_agents.endAgent` decided whether an ending agent was the thread's host agent (the one whose end takes down the thread's context manager, templates and ShadowRealm support) from `v8_Isolate_GetCurrent()` at the moment it ended: none entered, or its own, meant host.

**Why**: Which isolate is entered at teardown depends on who is tearing down, not on whose agent it is. A top-level Window realm keeps the page isolate entered for its whole life and exits it when it ends. So a worker agent ended after the page's realm, for example by a Browser ending its workers once its page was gone, found nothing entered and was treated as the host. It would have torn the thread's state down under the page, before the page's own cleanup ran. It is the same mistake as [A null parent is not proof of ownership](architecture-a-null-parent-is-not-proof-of-ownership.md): a fact about ownership re-derived later from whatever state happens to hold.

**What Happened**: Designing `worker_host.endWorkersOn` for the end of a Browser's loop, the first placement was after the page's teardown. Reading endAgent showed that a worker's end there would take the host's branch. The red test (tests/v8 page_realm_operations_test, "an agent made inside another's realm is not the host agent, even when it ends with no isolate entered") failed on the context manager losing the file's realm, and the next test in the file segfaulted.

**Fix**: `AgentRecord.host_agent`, set in createAgent from whether an isolate was entered when the agent was made. A Browser makes its page agent with none entered. A worker's agent is made by its owner's script, so the owner's isolate is entered. endAgent reads the record, and an isolate createAgent did not make is never the host, because releasing only its own state is the safe default. The call site also moved before the page's teardown, so the two fixes do not depend on each other.

**Takeaway**: **Record a role when it is taken. A predicate over teardown-time state is answered by whoever happens to be tearing down.**
