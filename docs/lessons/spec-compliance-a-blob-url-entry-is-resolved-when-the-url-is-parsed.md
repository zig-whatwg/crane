# Spec Compliance: A blob URL's entry is resolved when the URL is parsed, not when it is fetched

**Date**: 2026-10-16
**Lesson**: The URL parser resolves a blob URL into its blob URL entry as it parses it, and scheme fetch "blob" reads that entry. So an algorithm that parses now and fetches later still gets the blob after `URL.revokeObjectURL`.

**Why**: The SharedWorker constructor parses urlRecord, but the shared worker manager's steps fetch the script in a task after the constructor has returned. Crane's fetch asks the blob URL store when it runs, so the entry has to be captured at parse time and carried to the fetch.

**What Happened**: `workers/shared-worker-from-blob-url.window.js` timed out at 1/4. `new SharedWorker(url); URL.revokeObjectURL(url)` revoked the URL before the manager's task fetched it: the store answered nothing, the worker failed, and the test waited for a message. The two cases after it never ran. All three browsers pass 4/4 (Blink resolves the blob URL in SharedWorker::Create). A dedicated Worker was unaffected only because Crane fetches its script inside the constructor.

**Fix**: `script_fetch.captureBlobScript` in the constructor. The entry's blob travels with the SharedWorkerRequest, and `WorkerScriptFetchOptions.blob_entry` makes the fetch use it (CSP's check still runs). A second constructor with the revoked URL still finds the running worker by its URL key.

**Takeaway**: **When a spec parses a URL in one step and fetches it in a later task, the blob URL entry belongs to the parse: capture it there, or a revoke in between turns a valid script into a network error.**
