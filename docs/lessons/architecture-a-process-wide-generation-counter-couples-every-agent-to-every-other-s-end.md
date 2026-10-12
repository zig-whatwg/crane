# Architecture: A process-wide generation counter couples every agent to every other agent's end

**Date**: 2026-10-12
**Lesson**: A cache invalidated by a process-wide generation is invalidated by every agent's end, not by its own.

**Why**: The V8 adapter kept a `cache_generation` in template_registry.zig, bumped by every
`clearForIsolate` - every agent's end - so that per-interface caches keyed by isolate address would
notice a new isolate reusing a dead one's address. Each isolate's template storage (data slot 1)
remembered the generation it was made at and was thrown away whenever it no longer matched. The
storage was already the isolate's own and could never outlive it; the counter added nothing but a
coupling between unrelated isolates.

**What Happened**: With every worker on a thread of its own (instances B1-B3), a worker's end bumped
the counter while the page's isolate ran on another thread. The page's next iterator was made from
a NEW "<Interface> Iterator" template, so `Object.getPrototypeOf(new URLSearchParams().entries())`
was a different object before and after the worker ended - WebIDL wants one %<Interface> Iterator
Prototype% per realm. The WindowProperties template on the agent record compared the same counter
and was rebuilt too. tests/v8/agent_templates_isolation_test.zig is red on base, deterministically:
agent A reads its iterator prototype, agent B is made and ended on another thread, A's next iterator
has a different prototype.

**Fix**: Per-isolate state lives in the isolate's data slot - the template registry's map became a
second map of the isolate's template storage - and ends with the isolate. No generation, no lock: an
isolate is used on one thread at a time, and a new isolate at a reused address starts with an empty
slot. Blink keeps its templates the same way, in V8PerIsolateData
(`isolate->GetData(gin::kEmbedderBlink)`).

**Takeaway**: **If state is per isolate, key it by the isolate's data slot, not by a process-wide
table plus a counter: a process-wide invalidation signal turns one agent's end into every agent's
cache miss.**
