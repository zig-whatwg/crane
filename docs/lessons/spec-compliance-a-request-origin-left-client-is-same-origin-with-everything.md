# Spec Compliance: A request whose origin is left "client" is same origin with everything

**Date**: 2026-10-16
**Lesson**: A request built without a client keeps the origin "client", and `InternalRequest.currentUrlIsSameOrigin` answers true for "client" - so a "same-origin" mode request with no origin set passes main fetch's check at every hop, whatever the URL.

**Why**: Fetch resolves "client" to the client's origin when the fetch starts. A Crane request made outside a realm (a worker's top-level script, fetched by the worker host) has no client object to resolve it, so the caller must set the origin itself. The request's mode alone proves nothing: the check compares the URL with the origin, and an unset origin compares as a match.

**What Happened**: `workers/same-origin-check.sub.html` was 0/16 ("Worker loaded unexpectedly"): cross-origin worker scripts, direct or through redirects, loaded. `script_fetch.fetchHttpWorkerScript` set mode "same-origin" but took the request's origin from `options.origin`, a field that held a BASE URL and that only the dead `fetchImportScripts` passed. Worker and SharedWorker passed `requesting_origin`, which only the blob store read. The same defect cost `secure-contexts/basic-dedicated-worker*.html` three subtests each.

**Fix**: `script_fetch.workerScriptRequest` builds the request as HTML "fetch a classic worker script" step 1 says, origin included (`setOrigin(requesting_origin)`), and a native test pins mode, destination and origin. The constructors pass the outside settings' real origin (`dom.global_settings` origin of the relevant global, "null" for a sandboxed document), not their API base URL's.

**Takeaway**: **When a request has no client to resolve "client", set its origin - and test a same-origin request with a URL that must fail, because an unset origin makes every URL pass.**
