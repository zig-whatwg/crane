# Testing: A WebDriver click reads the element's box, and that read updates style first

**Date**: 2026-11-18
**Lesson**: WebDriver's Element Click scrolls the element into view (step 5) before it clicks; in a browser that read of the element's box updates style and layout first, so a runner that skips the "layout-only" steps leaves a page clicked before any style was computed.

**Why**: A style change in a click handler transitions only from a before-change style. A browser's driver always computes the element's style before the click (the scroll-into-view and in-view checks read its box), so in every browser the page's first style exists when the handler runs. Crane computes style lazily and renders on demand; its runner treated Element Click steps 5-7 as no-ops without layout, and a click dispatched 1 ms after the parse found no style at all.

**What Happened**: fullscreen/rendering/fullscreen-css-transition.html (all three browsers 1/1) blocked: its click handler sets `color: red` and the transition never started (red instead of green). A probe showed it exactly: the plain click gave red and 0 animations; the same click after a `getBoundingClientRect()` gave green and a running transition. The brief had guessed at the event loop's style update; that update already ran for documents that declare transitions - the click simply came before the first frame.

**Fix**: Element.scrollIntoView updates style first, as Crane's other CSSOM View geometry reads do (`dom.style.engine.updateStyleForRead`); the runner's Element Click step 5 calls it through the generated interface (tests/wpt_runner/test_driver.zig). Steps 6-7 stay true without layout. Test: tests/wpt/crane/css2-click-updates-style-first.html.

**Takeaway**: **A WebDriver step that reads geometry is a style update in a browser: skip the geometry, never the style read - and probe the timing (how long after the parse the input arrives) before blaming the event loop.**
