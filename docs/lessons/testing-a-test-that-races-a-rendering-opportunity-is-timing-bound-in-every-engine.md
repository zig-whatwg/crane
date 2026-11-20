# Testing: A test that races a rendering opportunity is timing-bound in every engine

**Date**: 2026-11-20
**Lesson**: When a test reads, through a postMessage chain, the result of events that fire at "update the rendering", its outcome is set by where the chain falls against the next frame. Measure the chain and the gap to the next frame before you call it a Crane race.

**Why**: fullscreen/api/element-request-fullscreen-cross-origin.sub.html resolves iframe D's requestFullscreen() promise (Fullscreen step 15) before the ancestors' fullscreenchange events fire at their next rendering opportunity (step 12). It then asks frame B for its report through D -> top -> A -> B. The spec allows either order. Crane's rendering opportunities fall on a 60 Hz grid, so the gap to the next frame is anywhere from 0 to 16.7 ms.

**What Happened**: the file sat in tools/wpt_build_differences.txt with an owner as "a race in Crane": production failed it 10/10 alone and passed it once under 32 runners. A lane-only timing copy of the page (chat.local x10) measured B's report 0.0-0.13 ms after D's promise and B's event 1.9-12 ms after it. So Crane fails it unless the chain is delayed past the next frame: about 1% of runs at rest, more under load. Chrome and Safari fail it the same way, and Chrome 157 even missed a different frame's event (C instead of B). Firefox passes. No spec-conformant change makes the result deterministic: a frame that waits for queued tasks would starve rendering.

**Fix**:
1. No code change. The file is a follows-majority exemption (Crane = Chrome + Safari).
2. Its build-differences line is owned by `timing-bound`, with the measured chain and frame gap as the evidence.

**Takeaway**: **Before hunting a race in Crane, time both sides of it on the page: when one side is a rendering opportunity, the result is the frame phase, which the browsers also lose.**
