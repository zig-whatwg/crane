# Spec Compliance: Media resource selection waits for a task in every browser

**Date**: 2026-10-09
**Lesson**: HTML runs the resource selection algorithm's synchronous section in a microtask ("await a stable state"); Chrome, Firefox and Safari all run it after the current task, and WPT files depend on the difference both ways.

**Why**: The parser performs a microtask checkpoint before each inline script. With HTML's microtask, a parsed `<source>` whose `src` a later script sets has already failed by then; in every browser it has not. Chromium uses a 0-delay `load_timer_` (ScheduleNextSourceChild, crbug.com/593289 is the TODO to make it a microtask), Gecko `RunInStableState` (after the current task), WebKit a queued task.

**What Happened**: With WebM playable, content-security-policy/media-src/media-src-7_1_2.sub.html still timed out: its securitypolicyviolation subtest waits for two violations and the parsed source never fetched. All three browsers pass it 3/3. Making the wait a media element task (de68bbf93c) passed it, and lost 26 media-elements files - most of them `resource-selection-invoke-*` and `-pointer-*` files that check microtask timing, which all three browsers fail too, but also files that browsers pass: the document's load event now fired between the invocation and the task that set the delaying-the-load-event flag (HTML moved that step into the synchronous section for lazy loading; Chromium still sets it at invocation), and a failed source's selection task was queued after its error handlers ran, not with the error task (bfa8cc1dd9, 4e7ec0ba91). After both fixes every lost file is one all three browsers fail (Firefox alone passes resource-selection-invoke-in-sync-event).

**Fix**:
1. `awaitSelection` (HTMLMediaElement.zig) queues the synchronous section as a media element task, one per load generation, for load(), insertion, a src set, a source inserted while waiting and a source failure; with no event loop it keeps the microtask.
2. Set the delaying-the-load-event flag when the algorithm is invoked, not in the task.
3. Queue the continuation after a failed source when it fails, right behind its error task.

**Takeaway**: **When a spec's timing primitive moves, every step around it moves too: find what the browsers do at invocation (the load-event delay, the queueing point) before shipping the new primitive, and A/B the change on its own - a timing change trades files both ways.**
