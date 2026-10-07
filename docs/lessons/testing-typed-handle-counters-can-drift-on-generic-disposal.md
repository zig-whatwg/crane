# Testing: Typed handle counters can drift on generic disposal

**Date**: 2026-10-06
**Lesson**: Check that a diagnostic counter observes the disposal path before treating its growth as retained handles.

**Why**: Crane's V8 wrapper increments the string counter in v8_String_NewFromUtf8 and decrements it in v8_String_Dispose. Generic v8_Global_Dispose and v8_Value_Dispose reset and delete a handle without adjusting that typed counter.

**What Happened**: CustomStateSet.forEach converted two borrowed string arguments through the engine protocol. A 10,000-cycle probe reported 20,000 extra live_string_globals, while V8's global-handle bytes remained flat, engine heap returned to 4.6 MB, native instances returned to nine and exit leak stacks contained no forEach allocation. The generic disposal path explained the counter drift. Separately, labels exposed real engine-heap growth that an ordinary childNodes control also reproduced; that needed its own investigation.

**Fix**: Keep the raw counter in the report, inspect its increment and decrement sites, and compare handle bytes, engine heap, allocator counts and exit leak stacks. Record a counter-owner follow-up; never dismiss a separate heap trend because one counter is inaccurate.

**Takeaway**: **A counter's ownership coverage is part of the measurement contract.**
