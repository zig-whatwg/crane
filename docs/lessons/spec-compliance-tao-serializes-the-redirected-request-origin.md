# Spec Compliance: TAO serializes the redirected request origin

**Date**: 2026-10-14
**Lesson**: A raw stored origin and Fetch's serialized request origin differ after a redirect chain.

**Why**: Fetch's TAO check step 5 compares Timing-Allow-Origin against the result of serializing a request origin. That serialization returns null when redirect-taint is no longer same-origin. Comparing the original origin string can expose redirect and network timing that the response did not authorize.

**What Happened**: Crane's TAO check compared its stored origin string. A cross-origin-to-same-origin redirect with an explicit original-origin TAO header passed, exposing redirectStart. A native test reproduces the mistake and pins null, wildcard and comma-separated controls. Chrome and Firefox pass all four cases of WPT's SO-XO-SO-redirect-chain-tao test; Safari passes three.

**Fix**: Reuse InternalRequest.serializeOrigin for step 5 and free the owned temporary at the call site. Keep wildcard handling first, and avoid allocation when there is no TAO header. Step 6 still compares navigation against the original origin: it asks a different question. The request's existing redirect bookkeeping remains the source of truth.

**Takeaway**: **Use the serialization named by the algorithm; do not substitute a stored string that happens to match before redirects.**
