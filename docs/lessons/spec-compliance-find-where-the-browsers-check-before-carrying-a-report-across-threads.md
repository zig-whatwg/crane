# Spec Compliance: Find where the browsers check before carrying a report across threads

**Date**: 2026-10-19
**Lesson**: The spec put a service worker script's CSP check in a fetch that runs on another thread. All three browsers check at register(), on the client's own thread, so no cross-thread violation payload was needed.

**Why**: The Service Workers spec fetches the script in the Update algorithm, given the job's client. Main fetch step 7 checks CSP, so the violation belongs to the client's global. In Crane that fetch runs on the manager's job thread. The client's reporter is a borrowed pointer to a global on the page's thread, so the job thread cannot use it. The brief therefore asked for a design first: an owned violation payload, delivered as a task to the right client, that survives a dead client.

**What Happened**: Lane sw1-b10 read the engines before designing that payload:
- Blink `ServiceWorkerContainer::registerServiceWorker` runs `AllowWorkerContextFromSource` after the URL checks and rejects with kSecurity. Its browser-side register job and script loader check no CSP.
- WebKit `ServiceWorkerContainer::addRegistration` runs `allowWorkerFromSource` and rejects with a SecurityError. `ServiceWorkerJob::fetchScriptWithContext` loads with `ContentSecurityPolicyEnforcement::DoNotEnforce`.
- Gecko `ServiceWorkerScopeAndScriptAreValid` runs `NS_CheckContentLoadPolicy` (TYPE_INTERNAL_SERVICE_WORKER, with the client's CSP event listener) and throws a SecurityError. The `ServiceWorkerScriptCache` channel carries no CSP.

So the check is a synchronous call in the client's own realm, using its own reporter, and it yields a SecurityError. The spec's fetch-time network error would have yielded a TypeError. The job's fetch enforces nothing; update() is never checked. The one cross-thread case left, importScripts() in a service worker, runs on the worker's own thread and reports to its own global, and it lacked only a field to carry the reporter.

**Fix**: `register()` (src/service_worker/realm.zig) runs `fetch.algorithms.csp_check.isBlockedFor` with destination "serviceworker" after Start Register's URL checks and before Schedule Job. A blocked URL rejects with a SecurityError and creates no job. The job thread's fetch stops enforcing the client's CSP list, and update() is pinned by `crane/sw1b10-update-csp.https.html`. The deviation from the spec text is stated with all three engines' functions.

**Takeaway**: **When a spec step puts a check on a thread that cannot report it, read where the three engines make that check before designing a delivery. Often they make it earlier, on the caller's thread, and the cross-thread mechanism is never needed.**
