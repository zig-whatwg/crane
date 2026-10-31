# Spec Compliance: A sort key reached by two routes compares at the model's precision

**Date**: 2026-10-31
**Lesson**: When a spec sorts by a time and keeps queue order for equal times, two times the model makes equal must compare equal - and doubles reached by different arithmetic are not, so compare at the precision the spec gives time values (Web Animations 1 8.1: microseconds).

**Why**: finish() sets the start time to `T - end / rate`, and the finish event's scheduled event time converts the effect end back as `end * (1 / rate) + start`. That round trip lands on T, one rounding step above it, or one below, by the bits of T. A cancel() in the same task is scheduled at exactly T.

**What Happened**: web-animations/timing-model/timelines/update-and-send-events.html "Playback events with the same timeline retain the order in which they are queued" failed 22 of 60 isolated runs (lane flaky2, chat2). 4.4 step 6's stable sort put the cancel before the finish whenever the round trip rounded up: about 2 cases in 5 for timeline times on the 0.1 ms grid. It was recorded as a flake in several generations; it was deterministic arithmetic over a timeline time that differed per run.

**Fix**: registry.queueEvent stores `atTimePrecision(scheduled)`, the time rounded to the microsecond. Gecko is exact because it keeps scheduled times as integer TimeStamp ticks; WebKit never reorders two playback events of one animation. A Crane test (crane/fk2-animation-event-time-rounding.html) reads the timeline time and picks effect ends whose round trip rounds UP, so it fails every run without the fix instead of 2 in 5.

**Takeaway**: **A "flake" whose rate is a stable fraction is often float arithmetic over a value that changes per run (a timestamp). Find the value, and the test can pick the bad case every time.**
