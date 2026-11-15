# Debugging: A figure that explains a result must be printed by the code that produced the result - a profile's number for a thing of the same name is another number

**Date**: 2026-11-14
**Lesson**: Lane wrap1 told the integrator, and through it a design document, that V8 was told 1,072 bytes for every wrapped Event and still collected only every 105 to 123 MB told. The code told V8 112 bytes for an Event. The 1,072 came from an allocation profile of "an Event's state"; the code read `vtable.state_size`, which is another block that is also called state.

**Why**: An Event has two things named state. The generated `State` block (48 bytes; its size is in the vtable, because `Instance.deinit` needs it) and the impl's `InternalState`, a 1,079-byte block of the Browser's arena that neither the instance nor its vtable names. `instanceHeldBytes` adds the slab slot, the vtable's `state_size` and the cache's record: 32 + 48 + 32. The profile (gc_bench --profile, by allocation site) reports what a kept Event holds: 1.2 KB, nearly all of it the arena block. The explanation joined a figure from the profile to a mechanism in the code without one line of output that showed the code using that figure. The arithmetic even agreed: 650,000 Events x 1.1 KB over six full collections is about 120 MB, which matched V8's allowance as read from its source - so the wrong figure looked confirmed. What V8 was really told between two full collections was about 12 MB (650,000 x 112 bytes over six collections).

**What Happened**: The first make-and-drop table of batch 3 (650,000 dropped Events ending at 198 MB against main's 88 MB) was sent with the reason "V8 answers a report with a full collection only every 105 to 123 MB". The integrator's ruling (wrappers V8 will not drop in a young collection keep a weak handle) rests on the table and stands; the reason was quoted in tmp/plans/dom-memory-figure-design.md as something lane wrap1 measured. The account's own test printed `V8 is told 112 B for an Event` the first time it ran, in the next build, and failed its pin of "at least 512". The run shows what V8 does when told 112 bytes an Event; it does not show what V8 does when told the whole of it.

**Fix**:
1. Before quoting a figure as what the code does, make the code print it (a counter, a test's print) and quote that line. A figure from a profile, a design or an earlier lane describes the thing measured there.
2. When two blocks share a name, say which: "the generated State block (vtable.state_size)" and "the impl's internal state (an arena block)".
3. Pin the figure in the test of the mechanism from the start - here `told == 1000 * instanceHeldBytes(instance)` - so the first run settles it.
4. When a sent explanation turns out wrong, send the correction with what the measurement does and does not show, and name the documents that quote it.

**Takeaway**: **An explanation is only as measured as its least measured number. If the code under test did not print the figure, the figure is a guess with a citation - and agreement with the arithmetic is not evidence, because the arithmetic was built from the guess.**
