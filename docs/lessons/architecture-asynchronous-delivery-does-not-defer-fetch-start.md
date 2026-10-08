# Architecture: Asynchronous delivery does not defer fetch start

**Date**: 2026-10-08
**Lesson**: Start a resource request at the algorithm's prescribed point, even when its completion must run later.

**Why**: Deferring completion and deferring acquisition are different operations. Script can revoke a blob URL between them, and File API 8.4 requires requests already started before revocation to succeed.

**What Happened**: The document module loader queued its entire graph startup to keep completion after script-element queue registration. The full worklist comparison then changed FileAPI/url/url-in-tags-revoke.window.js from seven passing subtests to six: appending a module and immediately revoking its blob URL made the fetch fail. The other six resource cases still passed.

**Fix**: Initialize the graph root and start its fetch before returning from script preparation. Start known imports of inline or cached roots at the same boundary; keep response parsing, later expansion, linking, and client completion queued. AsyncFetch.start explicitly promises no client callbacks until a later pump, so acquiring the blob response now does not evaluate script synchronously. Convert root allocation failure into the normal queued failure path. Finish initialization before queueTask and do not touch the graph afterward: queue allocation failure can synchronously drop and destroy it. The Crane probe covers both revocation after append and revocation before append, with asynchronous evaluation and event delivery assertions, plus an inline-import revocation probe.

Design reference: [Blink ModuleTreeLinker::FetchRoot](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/loader/modulescript/module_tree_linker.cc) calls FetchSingle while starting the root; it does not postpone initiating the fetch merely to defer completion. HTML fetch-single steps 8–13 construct and initiate the request; File API 8.4 defines the revocation boundary.

Inline dependency initiation follows HTML fetch-inline step 2 / fetch-descendants step 5 and [Gecko ModuleLoaderBase::StartFetchingModuleDependencies](https://github.com/mozilla-firefox/firefox/blob/59c8a945f229e17d78d091d82f1624494e2c5006/js/loader/ModuleLoaderBase.cpp#L1409). Blink and WebKit defer this inline path, so no claim of three-engine agreement applies.

**Takeaway**: **Queue delivery when required; preserve the specified moment of resource acquisition.**
