# Architecture: A worker takes its tab's state as a copy when it is made, not through a shared table

**Date**: 2026-11-21
**Lesson**: When a dedicated worker needs something its owner's tab holds (a host's user agent override, an emulation setting), copy it on the owner's thread into the worker's start record, as Chrome copies into the worker's creation params - do not build a mutex-guarded per-Browser table the worker thread reads.

**Why**: A tab's state lives on the window thread (a BrowsingContext and its host_overrides; dom.browser_state checks that thread in Debug builds), and a dedicated worker's fetches and navigator run on the worker's own thread. A shared table needs a lock, owned copies, a key from the worker back to its tab, and clearing when the override goes - and it is not what any browser does. Chrome's DedicatedWorker::CreateGlobalScopeCreationParams copies the owner's user agent (FrameLoader::UserAgent, which applies the DevTools override through probe::ApplyUserAgentOverride) into the creation params; WorkerFetchContext::PrepareRequest sends that copy; an override set later reaches only workers made later.

**What Happened**: Lane cdph proposed a per-Browser, mutex-guarded table keyed by tab id for workers' user agent overrides, and the integrator approved it. Checking Chrome's mechanism before writing it showed the creation-time copy; the plan was changed to it, with the integrator's approval (8:26 PM ET 2026-11-21). Fetch's override hook reads only a request's traversable for user prompts, which a worker's request does not have (no-traversable, by spec), so the worker's request carries its global as a separate `user_agent_client`.

**Fix**: html_core host_overrides.UserAgentSnapshot (owned copies), taken in ThreadHost.create on the owner's thread (a Window owner's tab's override, or a dedicated owner worker's own copy) and moved into the WorkerHost on the worker's thread; WorkerNavigator and fetch's reader read it there (html.worker_host.userAgentOverrideOfRealm). No lock: the copy is made before the worker's thread starts and read only on it.

**Takeaway**: **Before designing cross-thread access for a worker, read how the browser hands the worker its inputs - a copy in its start record is thread-safe by construction and is usually the browsers' own semantics.**
