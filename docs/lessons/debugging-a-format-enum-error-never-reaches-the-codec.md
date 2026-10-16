# Debugging: A format enum error never reaches the codec

**Date**: 2026-10-14
**Lesson**: Classify failing compression tests by format before treating a uniform TypeError as a broken transform or codec.

**Why**: WebIDL converts an enumeration argument before calling the implementation. A format missing from the pinned enum fails there, so changing the constructor body, byte copying or flushing cannot make that format work. A generic exception message hides this distinction.

**What Happened**: Row 33 was assigned 146 compression failures, all showing `TypeError: TypeError`. Its frozen BASE ran all 19 worklist files with 530 passes and 146 failures. Every failure named Brotli. The three pinned DEFLATE formats passed, including Float16Array after an earlier adapter fix. One isolated Brotli case failed at construction. `specs/idl/compression.idl` contained only deflate, deflate-raw and gzip; the enum conversion in the V8 adapter rejected Brotli before the compression implementation ran. Row 15's Q14 and handoff had already recorded the same deferred capability.

**Fix**:

1. Read the pinned IDL, current spec, WPT format list and the prior area's handoff.
2. Count failures by test name/format as well as by message, retaining the full suite results.
3. Reproduce one failing format in isolation and identify whether construction or a stream operation first fails.
4. Route missing pinned-IDL/codec work to its owners. Improve locally produced chunk errors at their own validation step without masking actual engine exceptions.

**Takeaway**: **An enum failure precedes the implementation: a shared message is not evidence of a shared codec defect.**
