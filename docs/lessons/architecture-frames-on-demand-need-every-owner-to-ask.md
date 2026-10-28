# Architecture: Frames on demand need every owner whose state shows at a rendering opportunity to ask for one

**Date**: 2026-10-28
**Lesson**: Once rendering opportunities come only when something asks (as in every engine), any step that runs at one - reveal, the focus fixup, a later observer - silently stops running for a page that never calls requestAnimationFrame, unless the owner of its state asks for a frame when that state changes.

**Why**: HTML's "update the rendering" runs at every rendering opportunity; step 4 lets the user agent skip a document whose rendering would change nothing and that has no animation frame callbacks. Blink (`ScheduleAnimation` -> BeginMainFrame only when needed), WebKit (`Page::scheduleRenderingUpdate`) and Gecko (refresh-driver phases; `StopTimer` when none is needed) all render on demand, and so does Crane's frame clock (src/browser/rendering.zig): one timer while a document has callbacks or asked through `dom.update_the_rendering.requestFrame`, none otherwise.

**What Happened**: Lane rendering1 moved rAF onto that clock. The reveal step (pagereveal) and the focus fixup (step 17) then ran only when some other frame happened: a page with no rAF never got pagereveal, and `shadow-dom/focus/focus-shadowhost-display-none.html` (a `:focus { display: none }` rule) timed out because nothing asked for the frame whose fixup blurs the host. The first native test of the focus trigger PASSED without the trigger: the page's load had asked for a reveal frame, which ran after the test focused the host.

**Fix**: Each owner asks when its state changes: a shown document after its pageshow ("the end" step 9.11), a reactivated one (step 4.2), one made visible; `dom.focused_area.set` when an element is designated, plus a one-bit watch beside the DOM tree version (refcount `DocumentCounts.version`) so the next mutation of a document with a focused element asks once. Tests of a trigger first settle the loop (`frames.timer_id == null`), so no unrelated frame is pending.

**Takeaway**: **With frames on demand, every owner whose state is read at a rendering opportunity must ask for one when it changes - and a test of that ask must start from a settled loop, or an unrelated frame passes it.**
