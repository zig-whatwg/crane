# Spec Compliance: An unobservable order deviation is observable to the next reader

**Date**: 2026-10-18
**Lesson**: A deviation stated as "nothing can observe the order" is a claim about the readers that exist today; a feature that reads the reordered state makes it observable, so check every stated ordering deviation in the path before relying on the spec's order.

**Why**: HTML "the end" updates the document's readiness to "interactive" (step 3) and then pops every node off the stack of open elements (step 4); "abort a parser" does the same (steps 3-4). Crane's tree builder pops them all as it reaches the end of its input, BEFORE the readiness change (TreeBuilder.popAllOpenElements), stated as harmless because what an element type does on a pop only queues work. The expect link type (lane style3) processes its links on every pop, and step 5 of "process internal resource link" blocks while readiness is "loading" - which it still is during Crane's pops.

**What Happened**: With the pop processing alone, a `<link rel=expect href="#unknown" blocking=render>` would have stayed in the render-blocking set after parsing ended, holding every frame until the 30 s cap: element-render-blocking-024, -027 and -039 time their first frame against parsing's end. The same reading found a second ordering trap: "insert a foreign element" inserts the element (step 3) before it pushes it (step 4), so the HTML insertion steps' step 3 ("an Element that is not on the stack of open elements") would unblock a link at its target's START tag. WebKit attaches after the push and Blink's insertion check requires finished parsing, so both unblock at the target's pop.

**Fix**: Document's becomeInteractive - the one point "the end" and "abort a parser" pass - processes the expect links again after the readiness change, generation-checked (stated beside the deviation). DocumentParser.isOnStackOfOpenElements counts the element the tree builder is inserting (DomTreeAdapter.inserting) as on the stack. Crane tests crane/style3-expect-pop.html (unblocks at the pop, not the start tag) and crane/style3-expect-open-target.html (the html element stays open until the end).

**Takeaway**: **Before a new feature reads state whose order the spec fixes, grep for stated ordering deviations on that path: "unobservable" was true only until you became its first observer.**
