# Architecture: A shadow root outlives script's hold on its host, so the host's death must not tear it down

**Date**: 2026-09-30
**Lesson**: Keeping a child alive from its owner (a Pin on the child's wrapper, released in the owner's teardown) fixes the owner's dangling pointer. Severing the child when the owner dies is only right when script cannot be holding the child without the owner - and for a shadow root it routinely is.

**Why**: Without tracing, an edge from owner to child can be a Global (the Pin), but the reverse edge cannot: a Global from child to owner makes a strong cycle that leaks both. So the child does not keep its owner alive, and whether the owner can die first depends on how script uses them. `document.createElement("div").attachShadow({mode: "open"})` keeps nothing of the host.

**What Happened**: scoped-registry-effective-global-registry.html died in ShadowRoot.get_mode: the host held its shadow root as a bare pointer, the shadow root has no parent, so its weak wrapper was collected and the instance freed under the host. The first fix took flakes' Document `KeptChild` shape - pin, and sever (deinit) at the owner's teardown. The red test went green and 103 shadow-touching WPT files showed nothing, but gc_bench's loop body `const r = host.attachShadow(...); r.appendChild(...)` threw InvalidStateError on its first cycle: V8 had collected the host mid-statement, its teardown severed `r`, and `r.appendChild` found no state. Before the fix `r` kept working (only `r.host` read freed memory).

**Fix**: the host still pins its shadow root, but its teardown only tells the shadow root the host is gone (a hook, dom.shadow_hosts); the shadow root stays a working DocumentFragment, its `host` answers InvalidStateError (a stated deviation until the host <-> shadow root edge is traced), and it is freed - with its subtree, now that ShadowRoot.deinit chains to DocumentFragment's - when its own wrapper is collected.

**Takeaway**: **Before severing a kept child at its owner's death, ask whether script can hold the child without the owner. If it can, detach it from the owner instead - and run a loop that drops the owner under a forced GC; a red test that holds both will never show it.**
