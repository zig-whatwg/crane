# Debugging: A sweep-only PASS can be a duplicate request that the load cancelled

**Date**: 2026-11-20
**Lesson**: When a subtest fails every time alone but passes once under sweep load, count the requests the page makes before you look for a race. A request the engine restarts can reach the server twice at rest and only once under load.

**Why**: Crane started an SVG `<image>` fetch synchronously at every href or crossorigin change. fetch/metadata's record-headers.py keeps the FIRST request for a key and refuses a second one: wptserve's stash raises StashError on an overwrite, which the handler does not catch (it catches only KeyError), so the second request gets a 500. A test that sets href and then crossorigin therefore made two requests. The first (no-cors) was recorded, and the second (cors) failed, so the image fired error. Under a 32-runner sweep the first transfer was sometimes cancelled before curl sent it. Only the cors request then reached the server, and the subtest passed.

**What Happened**: generation 232's bug-finding run passed "sec-fetch-mode attributes: crossorigin" once, while production failed it 10/10 alone, and the difference went to tools/wpt_build_differences.txt as a race. A lane-only probe page on one host varied the order of the attribute sets. Any second request for the same URL errored: the same href twice, or crossorigin set after a finished load. A different URL loaded. That pointed at the server, not at the transport. Chrome and Firefox issue one request with the final attributes (Blink's ImageLoader::UpdateFromElement queues a microtask). Safari fetches at once and fails two of the three subtests.

**Fix**:
1. The SVG image's fetch runs in a microtask queued at the change, with the attributes as they are when the microtask runs, as img's "update the image data" does. The element is kept, and its load event delayed, until the microtask runs (src/webidl/impls/SVGImageElement.zig `queueUpdate`).
2. A Crane test pins one request per task: crane/flk2-svg-image-fetch-once.https.html, which uses record-headers.py's refusal as the detector.
3. The build-differences line went: the result is now the same in every run.

**Takeaway**: **A pass that appears only under load can be load cancelling a request the engine should never have sent. Probe the request count with the same server handler before you hunt a timing race.**
