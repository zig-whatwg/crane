# Architecture: A queued native task holds its nodes with a TaskHold, and its tracker is a lookup, not a pointer

**Date**: 2026-10-19
**Lesson**: A task the DOM queues for script - a toggle event, a planned navigation, a close event - has no wrapper and no Instance to hang a hold from, so it holds each node with `node_holds.TaskHold` (a counted hold plus one counted pending-activity keep of the node's wrapper: refcount design 2.4's GCReachableRef), taken when it is queued and released exactly once at its run, cancel or drop; and anything that must find the task again (a toggle task tracker) looks it up, because the queue may already have dropped it before `queueTask` returns.

**Why**: `Holder` and `MemberHold` keep their nodes from an owner's wrapper. A task record has neither, so each task invented its own answer: HTMLDetailsElement's toggle task took `keepPlatformObjectAlive` beside an address and a generation; HTMLFormElement's PlannedNavigation kept its form, submitter and form document by address and generation alone - nothing kept them, so a submitter script removed and dropped was collected and the navigate event read `sourceElement` null; popover.zig queued no toggle task at all, waiting for a holder. WebKit's `Node::queueTaskKeepingNodeAlive` captures `GCReachableRef(node)`; Blink posts `WrapPersistent(element)`.

**What Happened**: Lane closewatch1 built the holder for the popover toggle task, PlannedNavigation and the close watcher manager (whose watchers keep their owners the same way). Three details decided the shape:
- An unwrapped node's keep waits for a wrapper; if a wrapped ancestor root is collected first, the node goes with its tree (L1). So `take` wraps an unwrapped node first - the shadow-mode net `keepMember` already uses - and takes the keep while that temporary hold still roots the wrapper (lesson: a wrapper made and released before you take your hold can be collected in between).
- A closing loop drops a task inside `queueTask`, so a pointer kept to the record after the handoff can be freed already (lesson: a queue handoff may drop the task before return). The HTML toggle task tracker is therefore `ElementTask.pending(element)`: a scan of the Browser's queued element tasks (a BrowserScope supplement), never a stored pointer.
- The tracker forgets the task before its steps fire the event, as WebKit's ToggleEventTask exchanges its data out before dispatching; the spec's literal order (fire, then null the tracker) would let a listener's own toggle read the running task's old state and then have its tracker nulled.

**Fix**:
1. `node_holds.TaskHold`: `take` (counted hold + keep, wrapping first), `get` (null only after a teardown freed the node - a net), `release` (keep first while the node is live, then the counted hold; a Debug panic on a second release).
2. `node_holds.ElementTask(Payload)`: "queue an element task" with both ends built in; `cancel` releases at once; the Browser's `ElementTasks` books count holds taken and released, and its end logs an error if they differ - which fails a unit test.
3. Callers convert: popover.zig's queue a popover toggle event task, PlannedNavigation's form, submitter and form document.

**Takeaway**: **A task that will hand nodes to script holds them with a TaskHold from queueing to its one end, and whatever must find that task later looks it up - after the handoff the record is the loop's.**
