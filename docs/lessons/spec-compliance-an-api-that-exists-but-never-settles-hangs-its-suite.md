# Spec Compliance: An API that exists but never settles hangs its suite

**Date**: 2026-09-29
**Lesson**: Exposing an API before the machinery that settles its promises turned 89 fast failures into 89 timeouts.

**Why**: With `window.navigation` missing, every navigation-api test threw at once and its file finished in under a second. Once the object existed - its entries, currententrychange and method promises - but the navigate event never fired, tests that wait for navigatesuccess, a transition, or an intercepted navigation's promises waited out the harness's ten seconds. A timeout blocks a file; a failure does not.

**What Happened**: Increment 3 of the navigation lane shipped the Navigation object without the navigate event (stated in its file comment). Sweep 505cfb9e3 found navigation-api/ blocking 89 files it had not blocked before. The lane's own A/B missed it because its base already had the change.

**Fix**: The navigate event (HTML 7.2.6.10.4), intercept(), the transition, precommit handlers, navigatesuccess and navigateerror, fired from every navigation path: pushState/replaceState, fragment navigations, "navigate" step 21, reload and traversals.

**Takeaway**: **Before exposing an API whose promises and events depend on machinery not yet built, count what waits on them: an object that exists and never settles is worse than one that is missing.**

**Again (2026-09-29, networking lane)**: making `link.crossOrigin`'s setter work (it threw NotImplemented) turned modulepreload-cross-origin-referrerpolicy.sub.html from OK (7 fast failures) into a TIMEOUT: the test got past the setter and waited on a `load` no modulepreload link ever fired. A setter or a constructor that starts working is exposure too - check what the test does next. Fixed with the modulepreload link type's fetch and events (f15c983f8): 0 -> 7/7.
