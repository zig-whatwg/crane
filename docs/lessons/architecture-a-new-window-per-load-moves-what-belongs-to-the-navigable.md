# Architecture: A new Window per load moves what belongs to the navigable, and swaps the realm only when nothing of it is on the stack

**Date**: 2026-10-26
**Lesson**: Giving a navigable a new Window per load (HTML "create and initialize a Document object" step 7) means sorting everything the old Window held into what belongs to the navigable - which must move to the new Window - and what belongs to the Window, which ends with it. A parentless realm entered for its life can be swapped only when no nested entry of it is on the native stack.

**Why**: Crane's host page kept one Window for its whole life, so several things lived on that Window that HTML puts on the navigable or the user agent:
- the top-level browsing context, which Window.init made and owned;
- the popups the page opened (Window.auxiliary_navigables), with their realms parented to the opener's realm, and each popup record's `parent_realm`.

Frames already swapped Windows, so their popups died whenever the frame navigated. The old Window's end (at a GC-chosen time) took its popups down, and a popup's next realm was made under the freed opener realm. The engine side has the same split: a parentless realm entered for its life hands its context AND isolate entries to its successor. Exiting a context that a running script or task entered on top corrupts V8's entered-context stack.

**What Happened**: Lane newwin1 moved the host page onto a traversable record (dom.top_level_traversables) that owns the browsing context, its session history and its WindowProxy record. It then swapped realms per load. The pieces that had to move were found one at a time:
- The browsing context would have been freed by the first Window's end.
- Popups died with the old Window (Illegal invocation on a torn-down popup; tests/html/nw1_popups_test.zig).
- The old realm's isolate entry was exited under the new one (tests/v8, a second agent).
- A ScriptLoader that loaded another page from inside the parser would have swapped the realm under the parser.
- One trap in the forced-reuse test: a plain object made by the old page's script and stored in a popup kept the old realm alive. That is correct JS reachability, and the test has to build its holders in the holding realm.

**Fix**:
1. The traversable record owns the navigable's state. Each new Window adopts the browsing context (dom.window_globals adopt/release).
2. engine E1: a parentless replaced realm hands over its entries, becomes its successor's child, and is detached (collect-later) like a frame's. E2: window.open's realm is `auxiliary` and is adopted by the realm built around its opener's proxy.
3. Every realm swap moves the old Window's popups and their `parent_realm` to the new Window (dom.window_globals.moveAuxiliaryNavigables). A new window_holders kind records it.
4. A load asked for while one of the page's own parses is on the stack waits for the outermost to return (Context.parse_depth / pending_load). That retired the re-queued destroy task, and the document.open deviation went with it.

**Takeaway**: **When an object that lived for the whole page starts dying per navigation, inventory what it holds and give each item to its spec owner (navigable, user agent, Window). Swap an engine realm only from a point where nothing of it is on the stack.**
