# Architecture: Registering a realm put the legacy import() callback back on the isolate

**Date**: 2026-09-26
**Status** (2026-09-28): superseded. The legacy import() handler, setDynamicImportHandler and its guard are gone (ff17c8591), and so is protocol_agents.hasModuleHooks: every agent's import() is the protocol's. The takeaway still holds for any per-isolate callback.
**Lesson**: V8's HostImportModuleDynamicallyCallback is per isolate and last-writer-wins, and context_manager.getOrCreate* installed the legacy handler for every realm it registered - replacing the protocol agent's loadImportedModule hook as soon as the agent had a realm.

**Fix**: engine.setDynamicImportHandler leaves an agent whose host supplied loadImportedModule alone (protocol_agents.hasModuleHooks).

**Takeaway**: **A per-isolate callback set from per-realm code is overwritten per realm; guard it where it is set.**
