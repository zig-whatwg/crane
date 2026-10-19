# Spec Compliance: Render-blocking timing is request metadata

**Date**: 2026-10-19
**Lesson**: Capture a resource fetch's render-blocking classification when it starts and preserve it for its imports; current document membership is a different fact.

**Why**: An element can lose its blocking attribute before its request finishes. A document can also stop accepting actual render blockers once it has a body. Recomputing the timing classification later, or using the loader's current membership flag, loses the request's original classification.

**What Happened**: Explicitly blocking scripts inserted after the body existed reported non-blocking. Stylesheet requests never received a render-blocking flag, and their imports started before the loader recorded actual document membership. Chrome is the only engine shipping `renderBlockingStatus` in the aligned stable runs at revision `23b0b89b1a472cac446e3c6e75fc7d6254913ef0`; Firefox and Safari return undefined. Chrome therefore supplies the implementing-browser behavior for this field.

**Fix**: Keep scheduling and document membership unchanged. Preserve the existing implicit script classification and let an explicit render token set request metadata independently. Do not blindly substitute the generic potentially-blocking predicate: Blink's preload scanner separately classifies parser scripts in the body, and ResourceFetcher exposes only its `kBlocking` classification. For sheets, record one scalar classification before the first fetch. Nonmatching media and alternate links are non-blocking; parser sheets in the body are non-blocking; dynamic sheets use their explicit render token. Imports inherit that captured value even after attributes change.

Primary designs: [Blink ScriptLoader](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/script/script_loader.cc), [HTML preload scanner](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/parser/html_preload_scanner.cc), [ResourceFetcher](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/loader/fetch/resource_fetcher.cc), and [stylesheet classification](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/pending_sheet_type.cc). Preload consumption and its own classification remain a separate loader concern.

**Takeaway**: **Timing describes the fetch that started, not the element's current attributes or its current place in a document's blocking set.**
