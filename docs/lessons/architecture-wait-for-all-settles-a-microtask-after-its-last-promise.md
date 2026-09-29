# Architecture: "Wait for all" settles a microtask after its last promise

**Date**: 2026-09-29
**Lesson**: Deliver a "wait for all" outcome one microtask after the reaction that decides it, as `Promise.all(promises).then(steps)` does - browsers wait that way, and WPT's ordering tests depend on it.

**Why**: WebIDL's "wait for all" runs its success steps inside the reaction that sees the last promise fulfill. Browsers implement it as `Promise.all(...)` followed by a reaction to the all-promise, which is one tick later. Script that attaches its own reactions after the navigation begins - `result.committed.then(...)`, `Promise.resolve().then(...)` - is enqueued between the two.

**What Happened**: The navigation API's commit waits for all of the API method tracker's committed promise and the intercept() handlers' promises, then fires navigatesuccess. Delivered in the deciding reaction, navigatesuccess came before the page's "committed fulfilled" and "promise microtask" records. `navigation-api/ordering-and-transition/navigate-intercept.html` expects navigate, handler run, committed fulfilled, transition.committed fulfilled, promise microtask, navigatesuccess.

**Fix**: `Navigation.zig`'s `Wait`: when the last promise fulfills (or any rejects), react to a fresh resolved promise and deliver the outcome from that reaction.

**Takeaway**: **When a spec's promise combinator has an observable order, check what the browsers build it from - `Promise.all(...).then(...)` is one tick later than "run the steps when the last one settles".**
