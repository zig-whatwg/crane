# Debugging: Before saying a timed mechanism is gone, read its delay and wait past it

**Date**: 2026-11-11
**Lesson**: "It never happens" measured for 17 seconds was a mechanism whose delay had moved from 8 to 30 seconds.

**Why**: A collector, a cache or a retry that runs on a timer looks absent to any measurement shorter than its
delay, and an engine update can move the delay without removing anything. A grep for the mechanism's old entry
point (here `PostIdleTask`) finds nothing and seems to confirm the absence, when the entry point was never the
mechanism.

**What Happened**: The V8 13.1 -> 15.7 port read 1.33 of main's memory. Lane v8up b4 measured that main's footprint
fell by itself within 7 s of idle time (27.8 -> 22.3 MB) and the port's did not after 17 s, found no `PostIdleTask`
caller in 15.7's heap, and reported "V8 15.7 does not collect in idle time". A new lane was briefed to give V8 the
idle signals a browser gives. In both versions the collection at idle is the memory reducer, a delayed foreground
task Crane's loop already ran; `gc_memory_reducer_start_delay_ms` is 8,000 in 13.1 (flag-definitions.h:2177) and
30,000 in 15.7.112.43 (flag-definitions.h:2761). With `--trace-memory-reducer` the two consoles printed
`8112 ms: Memory reducer: started GC #1` and `30111 ms: Memory reducer: started GC #1`; with 40 s of idle time the
port's footprint fell by itself to its forced-collection level (31.5 -> 25.5 MB). b4 had listed the reducer's other
delays as "the same in both" and missed this flag.

**Fix**:
1. Name the mechanism that produces the effect on the side where it happens, from a trace, before looking for it on
   the side where it does not: `--trace-gc --trace-memory-reducer` say which collector ran, when and why.
2. Read every delay and threshold of that mechanism in both versions' sources (flags and constants), and make the
   measurement longer than the longest.
3. Only then call it absent. A measurement route for engine flags (`-Dv8-extra-flags`) costs one build.
4. A trace written through C stdio lands in a redirected file after the page's own lines: place its events by their
   timestamps, never by their position.

**Takeaway**: **A negative result is only as long as its measurement: before reporting that a scheduled mechanism
no longer runs, find its delay in the source and measure past it, with the mechanism's own trace turned on.**
