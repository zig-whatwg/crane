# Architecture: State made lazily keeps the time it would have been made

**Date**: 2026-11-20
**Lesson**: When you defer making an object until something needs it, find every part of its state that depends on WHEN it would have been made eagerly (a start time, a sequence number, a "connected since"), and record that moment cheaply at the time - otherwise the lazy object is a different object.

**Why**: Every browser gives each outermost svg element a SMIL time container when it is inserted, and starts it at the load or at an insertion after the load (Blink SVGSVGElement::InsertedInto -> SMILTimeContainer::Start; Gecko BindToTree; WebKit insertedIntoAncestor). Crane makes the timeline only when an animation or a timeline method asks for it, so that a page of animation-free icons allocates nothing. The timeline's start is part of its observable state: getCurrentTime(), and when an animation added later begins.

**What Happened**: Lane dnd1 moved timeline creation from svg insertion to the first animation (02447a99e, to fix a leak and a cache-count test). A timeline made after the load was then never started: the old code started it in svgInserted, which now returned early because there was no timeline yet. An svg and its `<set>` inserted together after the load never ran. sanitizer-api/sanitizer-svg-animate.html (0/22 -> 22/22 earlier in the batch) and the lane's own SMIL tests timed out again. The Linux gate was green, because no unit test covered the integration. The lane's 111-file WPT rerun caught it.

**Fix**: 30db1ad50 records only the time the timeline would have begun: the document's load time (one per document), or, for an svg inserted after the load, its insertion time in a document-level map that the element's removal drops. A timeline made later starts at that time (TimeContainer.start takes the reference time), and getCurrentTime() reads it when no timeline has been made. New Crane subtests pin both cases: an svg inserted after the load, and an svg in the markup with no animation.

**Takeaway**: **Lazy creation is only an optimisation if the lazily made object equals the eager one. Write down what the eager path did at creation (start, register, number) and make sure the lazy path does it at the same logical time. Rerun the WPT files that a "made only when needed" change touches, not just the unit gate.**
