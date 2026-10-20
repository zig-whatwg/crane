# Spec Compliance: Select responsive image sources after the microtask

**Date**: 2026-10-20
**Lesson**: Responsive source selection belongs in the existing image update microtask, before request creation.

**Why**: HTML's update-the-image-data algorithm waits until the calling task finishes before selecting a responsive source. Script can change src, srcset, sizes, and crossorigin in one task. Selecting at each setter can fetch obsolete candidates or resolve them against an obsolete base URL.

**What Happened**: Crane's ordinary img loader already had generation-based cancellation, current and pending requests, document load delays, and pending-activity retention. However, every update selected only src. A native Browser test selected the fallback instead of the 1x candidate, and resource-timing/initiator-type/img-srcset.html timed out waiting for its resource entry.

**Fix**: Treat a responsive update as a deferred source selection. Parse candidates after the existing microtask checks its generation, resolve the selected URL, and pass its pixel density into the existing current/pending request. Reuse the loader's fetch, decode, event delivery and teardown paths. Keep the first candidate at a duplicate density and apply density correction when exposing natural dimensions. Test changes made in the same task and a disconnected image after script drops its reference and requests GC.

**Takeaway**: **Adding source selection should reuse the image request lifecycle; the source's URL and pixel density must travel together.**
