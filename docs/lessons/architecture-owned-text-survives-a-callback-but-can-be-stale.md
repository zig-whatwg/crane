# Architecture: Owned text survives a callback but can be stale

**Date**: 2026-10-09
**Lesson**: An owned copy solves memory lifetime; an algorithm that resumes after script must separately decide which state to read again.

**Why**: A beforeinput listener can replace a text control's value. Applying the pending deletion to the earlier owned copy erases the listener's change even though every byte remains safe to read.

**What Happened**: Row 9 routed deletion through the control's editor hook but built the final edit from the copy acquired before beforeinput. The previous setRangeText path applied the pending range to the live value instead. The review found this behavioral regression without a use-after-free.

**Fix**: Keep the initial read for the event and pending range. After the uncanceled event returns, acquire the live editor value, clamp the pending endpoints, and splice that value. Crane tests cover longer, shorter and empty replacements on input and textarea. The integrator confirmed this as Crane's pre-batch range policy; the corresponding browser range behavior remains unverified.

**Takeaway**: **Across script, audit content freshness as well as ownership, and distinguish a restored local policy from verified browser behavior.**
