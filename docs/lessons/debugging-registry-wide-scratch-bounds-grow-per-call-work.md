# Debugging: Registry-wide scratch bounds grow per-call work

**Date**: 2026-10-28
**Lesson**: A local array sized by a global registry can add work to existing calls whenever an unrelated entry joins the registry.

**Why**: Zig's safety instrumentation can fill an `undefined` local array with `0xaa`. The source declaration looks like reserved scratch space, but the compiled code may initialize the entire capacity on each call. A runner with an optimized root can still contain this instrumentation when its Crane modules retain Debug semantics.

**What Happened**: Row 125 added 54 CSS longhands. Two local arrays in `CSSStyleDeclaration.computedValue` used `properties.max_assignments`, the capacity for expanding `all`. That bound grew from 248 to 302. Disassembly of the actual frozen runners showed two fills growing from 7,936 + 9,920 to 9,664 + 12,080 bytes: 3,888 extra bytes per generic shorthand read, including an existing `margin` read that consumes only four entries. The protected pooled 14-pair comparison found that read 8.67% slower by the ratio of medians and 8.77% slower by the median paired change. CPU samples identified the fill sites as hot; sampling alone did not prove they explained the whole regression.

**Fix**: Check the caller's reachable domain before choosing a bound. This caller already returns for `all`, so derive a separate capacity by visiting every other `Shorthand` enum tag and asking its existing `longhands()` mapping. The largest is currently `font`, with 19 members including reset-only components. Use that bound for these two local arrays, retaining the existing cleanup, ownership and safety checks. Keep the general `all` bound for callers that can actually expand `all`; replacing every occurrence would be incorrect.

Pin the largest case and coverage of every eligible enum tag in a native test, observe its failure against the old bound, and inspect the corrected generated code. Then gate and compare newly frozen binaries with the same fixtures and acceptance method. A plausible hot operation is a repair hypothesis until the corrected tree passes its cost bars.

**Takeaway**: **Size scratch storage for the values the call can reach, and inspect the compiled initialization cost.**
