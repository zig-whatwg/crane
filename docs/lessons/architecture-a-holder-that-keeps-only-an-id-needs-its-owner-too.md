# Architecture: A holder that keeps only an ID needs the ID's owner too

**Date**: 2026-11-03
**Lesson**: A per-thread map keyed by ID looks like the easiest global to move - until you find that its readers are the holders that kept only the ID precisely so they could outlive the record. Moving the map to its owner moves the problem to every holder: each must now carry the owner as well, and free what it carries exactly once, at its own end.

**Why**: HTMLIFrameElement kept every navigation in flight in a `threadlocal` map by ID. Event-loop tasks, the navigation fetch's client and the streamed body's holder held only the ID - deliberately: "a task holds only the ID, so a navigation ended while its task waited is simply not found". The map's owner is the Browser (its `Navigables`), but about twenty entry points reached it with nothing but the ID, on the window thread, with no current Browser to ask.

**What Happened**: Lane gstate4 moved the map to `Navigables.navigations` and gave every holder a `Ticket` - the owner's list and the ID, looked up there each time (Chromium's WeakPtr shape: the holder keeps a handle, not the object). The work was in the holders' ends, not the map:
- an event-loop task: the ticket is redeemed as the task runs, and the task's `drop` frees it when its loop ends with it queued;
- a fetch's client: `gone` or `finished` is its last word - but only if `finished` is set, a terminate by the client calls nothing, and a body adopting the fetch replaces the client; each of those three ends frees the ticket;
- a streamed body's holder outlives the record: its `kept` (released once, at the body's release) now always holds the ticket, beside the timing reporter it held before;
- an arriving response's consumer lives inside the record, so it needs no ticket - the record itself is safe there, because the response is taken or destroyed, clearing the consumer, before the record goes.
Each of those guarantees was read in the holder's code and pinned by a test before it was relied on (tests/fetch/gs4_fetch_client_last_word_test.zig, tests/html/gs4_navigation_fetch_holders_test.zig).

**Fix**:
1. Before moving an ID-keyed registry, list who holds only the ID, and for each, where its life ends (run, drop, last callback, release).
2. Give each such holder a ticket {owner, id}, allocated where the holder is made and freed exactly at that end - never by the record, which the holder may outlive.
3. A holder whose life is contained in the record's needs no ticket: say why, and pin the containment.
4. Pin every "this is the last call" guarantee with a test of its own; a leak-checking allocator in the behaviour tests then catches a ticket freed twice or never.

**Takeaway**: **An ID is a weak reference only while its registry is global. Move the registry to its owner and every holder of the ID must carry the owner too - a ticket freed exactly once at the holder's own end, whose last-call guarantee you have pinned.**
