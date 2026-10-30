# Debugging: Known Child Counts Avoid Arena Growth

**Date**: 2026-10-30
**Lesson**: When a flattening pass already knows its final child count, reserve that capacity before appending into an arena.

**Why**: Geometric array growth can exhaust a backing chunk even when the final array is tiny. An arena keeps the abandoned capacity until its expression is destroyed, so balanced cleanup does not prove that the operation performs the same allocation work.

**What Happened**: Widening CSS numeric powers from i16 to the required i32 enlarged Type from 16 to 32 bytes and Node from 88 to 104 bytes. Across 1,000 two-child calc parses, parent allocation calls rose from 3,000 to 4,000. A matched diagnostic changing only the power width restored all 54 counters, while every variant still cleaned up completely. Narrowing the shared type was unsafe: native variadic trees can need wide intermediate powers even when their final result has a small type.

**Fix**: After recursive simplification, count the children the existing sum/product flatten loop will append, using checked addition. Reserve that exact capacity and keep the original allocating append calls, order, and owned destination. Pin allocation work separately from type, serialization, computation, and allocation-failure cleanup. The work test went from 4,000 calls against a 3,000-call budget to passing that budget, alongside unchanged value and cleanup controls; timed performance still requires its separate matched comparison.

**Takeaway**: **Measure backing allocations before narrowing a semantic type; remove avoidable capacity where the measured growth occurs.**
