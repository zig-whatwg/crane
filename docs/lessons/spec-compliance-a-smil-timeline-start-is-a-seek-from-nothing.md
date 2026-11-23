# Spec Compliance: A SMIL timeline's start is a seek from nothing

**Date**: 2026-11-20
**Lesson**: When an SVG timeline starts, run its seek update without first recording which elements were "already active" - nothing played before the start, so every element active at the start time owes a beginEvent.

**Why**: SMIL Animation's seek reports each element's net change across the seek (Blink SMILTimeContainer::PrepareSeek records the elements active before a setCurrentTime(), and TimingUpdate's end compares). An element scheduled before the timeline started has already resolved its first interval (SVGSMILElement::AddedToTimeContainer runs UpdateInterval at time 0), so its interval "contains" time 0 before anything has played.

**What Happened**: Lane dnd1's first time container ran `start()` as an ordinary seek. The prepare step saw the `<set begin="0s">` interval [0, indefinite) as active at 0, recorded it as the starting interval, and the seek's net change was "same interval, still active": no beginEvent. The unit test "begin=0 with no dur" failed; in a page, every `<set>` inserted before the load event would have begun silently, and sanitizer-svg-animate.html (which waits for beginEvent) would have timed out again.

**Fix**: A third update policy, `.start`, a seek without the prepare step (Blink's SMILTimeContainer::Start constructs its TimingUpdate as kSeek but never calls PrepareSeek). `setElapsed()` keeps the prepared seek.

**Takeaway**: **A seek reports the difference from the state before it; at a timeline's start there is no state before it, so do not compute one from intervals resolved ahead of time.**
