# Spec Compliance: A network error may need a native cause

**Date**: 2026-10-04
**Lesson**: Preserve the native failure distinction when a consuming algorithm must decide whether retrying is futile.

**Why**: Fetch deliberately represents transport, CORS, policy and unsupported-scheme failures as network-error responses. HTML EventSource then asks the user agent to distinguish retryable failure from failure it knows to be futile.

**What Happened**: EventSource's cross-origin tests require CLOSED after CORS denial, while a broken connection must reconnect. Crane's FetchJob converted both outcomes into indistinguishable responses. Deciding from status zero alone would either retry rejected requests indefinitely or stop retrying transient network failures.

**Fix**: Keep Fetch's observable response unchanged. Add an internal cause whose default is unspecified, marking only the network transport failure path as transport. EventSource retries only that explicit case. Pin the default and the cause's survival through main-fetch filtering in allocator-checked tests. Keep aborted responses, preflight denial and other policy failures outside the retry allowlist. Blink's EventSource::DidFail uses the same design distinction between access checks/cancellation and other load failures.

**Takeaway**: **An erased failure distinction cannot be reconstructed by the caller; preserve it at its source and make retries an allowlist.**

Design reference: https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/modules/eventsource/event_source.cc (DidFail).
