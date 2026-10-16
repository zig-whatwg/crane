# Spec Compliance: Resource timing opacity is field-specific

**Date**: 2026-10-14
**Lesson**: Response filtering and the timing-allow check hide different fields; neither makes the whole timing record empty.

**Why**: Fetch's report timing steps read the filtered response's status. An opaque or opaque-redirect response has status zero even when Timing-Allow-Origin exposes its network timestamps. Conversely, creating opaque timing info preserves the fetch's end time and render-blocking flag while clearing network and redirect details.

**What Happened**: Crane stores internal response fields alongside a response_type marker. The timing reporter read the internal status directly, exposing 203 for a no-CORS response and 302 for a same-origin manual redirect. Its opaque timing constructor also dropped end_time, so responseEnd was zero. Native tests reproduced all three errors, independently of the network or clock.

**Fix**: Apply the response type when reading status and body metadata in Fetch's fetch-response-handover steps 4.2.4 and 4.2.7; keep basic and CORS statuses and content encoding visible independently of TAO. Copy end_time and render_blocking in createOpaqueTimingInfo. A manual redirect's request tainting can still be basic, so it cannot stand in for the response filter. Preserve browser body-size gating: Chrome and Safari hide CORS body sizes without TAO, although the current spec and Firefox expose them. Pin that deviation separately from metadata. The report's scheduling and body ownership are separate work. Blink's [CreateResourceTimingInfo](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/loader/fetch/resource_timing_utils.cc) likewise sets response_end before its timing-allow branch and gates response_status on IsCorsSameOrigin.

**Takeaway**: **Read the algorithm's named view of each field: a response's status is not its internal response's status, and opaque timing still has a completion time.**
