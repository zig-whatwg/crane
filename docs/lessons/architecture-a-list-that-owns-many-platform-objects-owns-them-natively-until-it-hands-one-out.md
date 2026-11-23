# Architecture: A list that owns many platform objects owns them natively until it hands one out

**Date**: 2026-11-23
**Lesson**: A native list that holds many non-node platform objects - a text track's cues - should own each one natively (no wrapper) and draw its traced edge only when script first reaches the object. Drawing the edge at add time makes a wrapper for every object, and an edge that waits on an unwrapped owner holds its child as a root.

**Why**: Crane's only bridge from a native holder to the collector is a wrapper. `engine.traceChild(owner, child, slot)` makes the child's wrapper if script has not seen it, so an edge per held object is a wrapper per held object. Blink traces a native `Member<>` and makes wrappers only on access. And an edge from an owner script has not seen yet waits in its realm's wrapper cache with the child held STRONGLY. For a cue that names its track, that strong hold is a root on the track, and through the track's wrapper a root on its realm: a cycle through a root, which a detached frame's realm can never get out of (same_object.Pin's problem).

**What Happened**: Lane vtt1's first cut kept each cue of a text track's list by `traceChild` at add time, as TextTrackList keeps its tracks. The integrator stopped it before any run: a 1,000-cue WebVTT file would make 1,000 wrappers that nobody reads ("do it Blink's way").

**Fix**: KeptChild's made/handOut, per entry (src/webidl/impls/TextTrackCueList.zig):
- Each list entry is `{ link, exposed }`. A cue the parser made is the list's alone, unwrapped and unexposed. While unexposed it names its track and region by `same_object.Link` only, so it holds no edges and no roots.
- Hand-out paths expose the cue: the list's getter and getCueById, and an event fired at the cue (time marches on's enter/exit). Exposing draws the list's edge (making the wrapper) and then the cue's own edges (`hooks.cueExposed`: cue to track, VTTCue to region).
- A cue that is already wrapped when added (`new VTTCue` from script; `dom.media_elements.mayBeWrapped` = not `instance_lifecycle.provablyUnwrapped`) is exposed at once.
- When the list lets an unexposed cue go (remove, src clear, the list's own teardown), the cue goes whole with `runtime.gc.releaseOwned`, which makes no engine call and is therefore safe inside the collector's teardown. For an exposed cue only the edge goes; the cue is its wrapper's.
- A view list (activeCues) owns nothing. It exposes a cue it hands out in the cue's track's own list.
- Every read prunes dead links: a cue made in another realm dies with that realm.
- Test it by counting slab slots: a 1,000-cue file leaves 0 wrapped VTTCue slots until script reads one, then 1 (tests/html/media/vtt1_text_track_test.zig).

**Takeaway**: **When a native list owns many platform objects, own them natively and draw each object's edges at its first hand-out to script. An edge drawn at add time costs a wrapper per object, and an edge waiting on an unwrapped owner roots its child.**
