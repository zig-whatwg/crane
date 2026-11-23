# Architecture: A DevTools hook in the DOM is one process-wide load, then the Browser's sink

**Date**: 2026-11-23
**Lesson**: Instrument a hot DOM algorithm for an inspector the way Blink's probes are built: an inline check of one process-wide atomic count of enabled agents, and only behind it the node's Browser's sink - never a hook call, a table lookup or an argument computed while no agent is enabled.

**Why**: CDP's live DOM needs an event at every insertion, removal, attribute and data change, shadow attach and top-layer change - the hottest paths the parser and every page take. Blink's generated probes (third_party/blink/renderer/build/scripts/templates/instrumenting_probes_inl.h.tmpl) start with `CoreProbeSink::HasAgentsGlobal(mask)`, an acquire load of the static `s_existingAgents` bit set (probe_sink.h.tmpl), and only then find the local frame root's sink and its agents. With no DevTools anywhere a probe is a load and a branch not taken.

**What Happened**: Lane cdpd1 put the DOM's probes in src/dom/inspector_probes.zig: `enabled_agents`, a reviewed `// process-wide:` atomic (enable increments, disable or session end decrements), `active()` as the inline check at each call site (`if (inspector_probes.active()) inspector_probes.didInsertDOMNode(n)`), the probe bodies `noinline`, and the Browser's agents in a BrowserScope side table (`.inspector_probes`, one atomic load) that src/devtools fills when it adopts the Browser. A per-Browser gate reached from the node (node -> realm -> scope -> registry) would have cost a dependent chain on every mutation of every Browser; a hook slot would have been an indirect call always. A Browser whose sink is empty while another Browser's agent holds the gate open pays one table load and returns.

**Fix**: For any inspector instrumentation of a hot path: one process-wide atomic gate with the reason on its `// process-wide:` line, the arguments computed only behind it, the sink per owner (Browser), and a cost pair over the hot rows with no session (DOM, parser, load, gc_bench).

**Takeaway**: **The cost of an inspector hook with no inspector must be one load of one global - Blink's s_existingAgents - and everything else, the sink, the agents and their work, lives behind it.**
