# Architecture: Registering a realm put the legacy import() callback back on the isolate

**Date**: 2026-09-26
**Lesson**: V8's HostImportModuleDynamicallyCallback is per isolate and last-writer-wins, and context_manager.getOrCreate* installed the legacy handler for every realm it registered - replacing the protocol agent's loadImportedModule hook as soon as the agent had a realm.

**Fix**: engine.setDynamicImportHandler leaves an agent whose host supplied loadImportedModule alone (protocol_agents.hasModuleHooks).

**Takeaway**: **A per-isolate callback set from per-realm code is overwritten per realm; guard it where it is set.**
