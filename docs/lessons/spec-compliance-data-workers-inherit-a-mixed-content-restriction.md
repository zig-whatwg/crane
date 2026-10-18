# Spec Compliance: Data workers inherit a mixed-content restriction

**Date**: 2026-10-17

**Lesson**: An opaque worker origin does not mean its requests may ignore the creator's mixed-content restriction.

**Why**: Mixed Content 4.3's opaque-origin branch says that the settings object does not prohibit mixed security contexts. Shipping browsers also carry the worker creator's HTTPS state. A data URL has an opaque origin, but a worker created by an HTTPS page still restricts insecure requests. The secure-context boolean is a different question and cannot substitute for this restriction.

**What Happened**: Crane's WorkerGlobalScope installed no mixed-content settings callback. Its requests consequently took the default false value. Reviewing data workers separately exposed a second gap: adding a callback that only authenticates the worker's own origin would still allow their HTTP requests.

On the aligned stable WPT revision `cc74d2669f`, Chrome 154 and Firefox 157 passed all eight cases in each of `sharedworker-{classic,module}-data.http-rp/opt-in/fetch.https.html`: six HTTP cases blocked and two HTTPS cases allowed. Safari 27 passed six; its two differences upgraded HTTP instead of blocking it. Every browser restricted the insecure requests, and the majority blocked them.

Blink's [WorkerGlobalScope constructor](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/workers/worker_global_scope.cc) consumes the starter's HTTPS state. [CalculateHttpsState](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/loader/fetch/https_state.cc) preserves a non-none parent state for an origin that is not HTTPS. These show the inheritance mechanism; the measured WPT results decide the behavior.

**Fix**: Read the creator's mixed-content callback on its own thread and carry the boolean by value through the existing worker-start settings. A tuple-origin worker derives its restriction from its own canonical origin without allocating. Only an opaque-origin worker uses the captured creator answer. A nested data worker captures its owner's already-folded answer, so the restriction propagates without retaining an owner pointer.

Tests must observe actual network delivery as well as rejection: a failed fetch could otherwise be DNS, CORS or transport failure. Pair an HTTPS-owner negative with an HTTP-owner positive, and cover dedicated/shared, classic/module and nested data workers.

**Takeaway**: **Treat worker origin, secure-context status and inherited mixed-content restriction as separate facts; measure opaque-origin behavior in browsers.**
