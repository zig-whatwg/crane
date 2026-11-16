# Workflow: Read the engine today before citing it - a brief's citation is a claim

**Date**: 2026-11-16
**Lesson**: A brief said "Blink: EventTargetData in NodeRareData; WebKit: EventTargetData via NodeRareData"; neither engine does that today, and the precedent for the design was a third engine.

**Why**: Engines move their fields, and a citation remembers one date. Blink keeps `Member<EventTargetData> data_` in every EventTarget today (core/dom/events/event_target.h; its history was not read). WebKit keeps the listener map in the EventTarget's weak-pointer control block (`WeakPtrImplWithEventTargetData`, dom/EventTarget.h). Gecko is the one that keeps a node's listener manager in its rare data: `nsINode::mSlotsOrListenerManager`, a tagged word that is the manager itself until the node has slots, then `nsSlots::mListenerManager` (dom/base/nsINode.h). The node-memory plan's own review recorded the same pattern once already: a design copied a Blink shape that Blink had deleted eleven months earlier.

**What Happened**: Lane nm3 fetched the three files before writing the mechanism (ten minutes), found the brief's citation out of date, cited what it read in the commit and the comments, and told the integrator in its first report. The design did not change - a node's listeners belong in its rare data on the numbers (nearly no node has one) - but the commit would have named two engines for something neither does.

**Fix**: Before a commit cites an engine: fetch the file from the engine's main branch, find the field or function by name, and cite the file, the name and the date read. When what you read contradicts the brief, say so in the first report, with the lines.

**Takeaway**: **A citation in a brief, a plan or an older comment is a claim with a date. Read the engine's file today, cite what is there, and report the difference.**
