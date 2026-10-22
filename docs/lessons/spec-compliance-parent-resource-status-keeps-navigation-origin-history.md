# Spec Compliance: Parent resource status keeps navigation origin history

**Date**: 2026-10-20
**Lesson**: If a navigation's response contributes to its parent's Resource Timing, determine status visibility from the navigation request's origin and redirect history, independently of Timing-Allow-Origin and the child document's own Navigation Timing.

**Why**: A navigation response stays basic so its document can consume it. That does not authorize its parent to read a cross-origin HTTP status. TAO exposes timing, not the status of an otherwise hidden response. Returning to the parent's origin after a cross-origin hop does not restore visibility.

**What Happened**: Fetch's timing reporter read `response.redirect_taint`, which defaulted to same-origin and was never populated from the request. The no-CORS resource-status file passed images, scripts and stylesheets but leaked all 80 iframe/object statuses; the cross-origin-redirect file leaked all 30. Existing request origin and URL-history predicates already carried the needed information through automatic and manually followed redirects.

**Fix**: At the response-status reporting boundary, require same-origin current URL and same-origin request redirect history for navigations. Keep response filtering and document navigation intact. Native tests exercise automatic/manual redirects and TAO both ways; isolated and full WPT files verify the parent-visible result. The missing main-fetch step 17 and MIME/body metadata remain separate follow-ups.

**Evidence**: [Fetch issue 1602](https://github.com/whatwg/fetch/issues/1602) describes the unresolved spec mismatch. Chrome and Firefox pass the matching [no-CORS](https://wpt.fyi/results/resource-timing/response-status-code.no-cors.html) and [redirect](https://wpt.fyi/results/resource-timing/response-status-code.cross-origin-redirect.html) files at aligned revision `0f26972422`; Safari does not pass any of the five response-status files. Chromium's [NavigationRequest](https://github.com/chromium/chromium/blob/main/content/browser/renderer_host/navigation_request.cc) checks the parent origin and redirects; [DocumentLoader](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/loader/document_loader.cc) creates separate parent and child timing information. This is the browser-majority rule, not a newer-spec lag exception.

**Takeaway**: **A default-valued metadata field is not proof that the producing algorithm populated it. Trace the producer before trusting the value at an exposure boundary.**
