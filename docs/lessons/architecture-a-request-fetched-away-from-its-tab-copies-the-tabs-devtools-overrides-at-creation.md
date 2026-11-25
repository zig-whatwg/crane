# Architecture: A request fetched away from its tab copies the tab's DevTools overrides when it is made

**Date**: 2026-11-24
**Lesson**: DevTools' extra headers and User-Agent override reached a page's own fetches but not its navigations or its workers' script requests, because Crane found the tab through the request's client, and those requests have no Window client on the thread that fetches them.

**Why**: `http_fetch.userAgentOverrideOf` found the tab's overrides through the request's traversable for user prompts, a Window standing in for its tab. Two kinds of request have none:
- A navigation's request never set one.
- A dedicated worker's script request is built on its creator's thread but fetched on the worker's, where the tab cannot be read.

Both kinds of request also outlive the moment they were made: a navigation's fetch can outlive the document that started it. Putting a Window pointer on the request would have meant a borrowed pointer crossing a thread and a commit. Setting the traversable would also have turned on the 401/407 prompt path for navigations.

**What Happened**: Lane mcp1 (batch 4b, the emulate tool) recorded Chrome 157 under `Network.setExtraHTTPHeaders`. Crane matched on the page's fetches, the preflight, the Referer entry and the errors. It missed the navigation and the worker's `worker.js`: Chrome sent `x-test` on both, Crane on neither. The same gap had silently kept `setUserAgentOverride` off navigations since it landed.

**Fix**: Chrome's model. Chrome applies DevTools overrides to a navigation once, at its start, keyed by its frame (`devtools_instrumentation.cc` `ApplyNetworkRequestOverrides`, from `NavigationRequest`). It applies the ancestor frame's overrides to a worker's main script (`OnWorkerMainScriptRequestWillBeSent`). Crane now does the same:
- `InternalRequest.override_snapshot` is an OWNED copy, made where the tab is readable: `navigationRequest` from `user_agent_override.ofNavigable`, `workerScriptRequest` from `ofRealm(outside settings)`.
- `clone` copies it, and `deinit` frees it.
- `userAgentOverrideOf` answers the copy before it asks the tab.

Also from Chrome's code: a session's extra headers apply only while its Network domain is enabled, and `Network.disable` clears them (`NetworkHandler::Disable`).

**Takeaway**: **When state belongs to the tab but the request is fetched elsewhere or later, copy what the request needs when it is made. Do not lend it a pointer to the tab.** Before wiring an override, ask which requests reach the code with no client, and record them all against Chrome.
