# Architecture: One module loader serves every settings object

**Date**: 2026-10-18
**Lesson**: The module map's callback lists (HTML "fetch a single module script" steps 5-7 and 13) belong to a settings object, not to a Document. Crane's asynchronous loader was document-only because of one field, its owner. With that field generalised, workers use the same loader, and the worker's synchronous path, with its permanent `fetch_failed` sentinel, is gone.

**Why**: Workers kept the synchronous loader of 2026-09, which cached a failed fetch as a `fetch_failed` entry forever. That made two things impossible for workers. A retry of a failed URL never fetched again (repeated-imports.any.worker). Imports of a URL already in flight could not join its fetch (concurrent-failed-imports.any.worker). The same path also fetched from a task, so a blob URL revoked right after import() failed (blob-url.any.worker), against the lesson that asynchronous delivery does not defer fetch start.

**What Happened**: `AsyncModuleLoader` held `document: *Instance` and `document_generation`. Its liveness check, its fetch client (`env.context_instance`), its agent's fetch pump (`dom.agent_fetches.of`) and its event loop (`realm.getOptionalEventLoop`) all work for a WorkerGlobalScope too. WebKit's ScriptModuleLoader does the same with one class and an OwnerType. The service worker kept its old path: that lane owns its rules, which differ.

**Fix**: Rename the owner field (`owner`, `owner_generation`). WorkerHost holds `module_loader`, made by the first import(), and each import is a `LoaderImport` client that finishes the engine request in `done` or `gone`. The order at the worker realm's end matters:
1. Drop the loop's tasks. Graph and SingleFetch drops cancel their graphs, and each `gone` finishes its import while the realm is alive.
2. `destroyModuleLoader`, which cancels the rest and terminates their fetches.
3. Only then `disposeModules`, which frees the records the graphs named.

The synchronous path still serves the module worker's own graph, a ShadowRealm's import() and engine-less contexts. It no longer makes an entry for a failure.

**Takeaway**: **When a mechanism exists for one kind of owner, look for the one field that ties it there before writing a second copy - and when you move it, write down the teardown order the new owner needs.**
