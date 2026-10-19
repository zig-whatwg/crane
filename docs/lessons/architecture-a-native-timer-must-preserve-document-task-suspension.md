# Architecture: A native timer must preserve document task suspension

**Date**: 2026-10-19
**Lesson**: Moving delivery from a document task to a native timer must preserve the task's inactive, active and gone cases.

**Why**: A Window's native timer interface belongs to its agent's event loop. It does not by itself suspend a callback when that Window enters the back/forward cache. An event-loop task tagged with the Window and its slab generation does suspend. A live instance and an attached realm are therefore insufficient permission to run script.

**What Happened**: Resource buffer delivery used an ordinary task. After an awaited script load, a subsequently armed zero-delay timer could overtake it: `crane/rt2-buffer-after-script.html` failed both assertions. Blink and WebKit instead arm a zero-delay one-shot on overflow. A direct substitution would repair that ordering while removing Crane's document-activity gate. Blink's timer retains this gate through `WindowPerformance`'s `kPerformanceTimeline` frame task runner, whose scheduler queue is pausable.

**Fix**: Keep one owned timer per overflow burst. At delivery, classify a Window through `dom.document_activity`: run when fully active, drop when gone, or transfer the same allocation to a Window-tagged event-loop task when inactive. After transferring it, the timer no longer owns the allocation. Worker globals have no document activity to classify. Test two overflows while a real popup is cached, delivery exactly once after restoration, and eviction before and after the handoff with a leak-checking allocator.

Primary designs: [Blink Performance](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/timing/performance.cc), [WindowPerformance](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/timing/window_performance.cc), [frame scheduler](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/scheduler/main_thread/frame_scheduler_impl.cc), and [WebKit Performance](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/Performance.cpp). The one-shot follows Chrome/Safari's existing behavior; Firefox fails the two mixed-buffer WPT files at aligned revision `23b0b89b1a472cac446e3c6e75fc7d6254913ef0`.

**Takeaway**: **Changing the delivery mechanism must not remove the document's permission to run the callback. Preserve suspension and transfer ownership exactly once.**
