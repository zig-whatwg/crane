# Architecture: No FFI returned the value a call threw

**Date**: 2026-09-22
**Lesson**: `v8_TryCatch_Exception` opens its OWN TryCatch, so it can never see
an exception thrown before it was called; the `_Safe` call variants return only
strings. "Rethrow the exception" and "reject with the exception" were therefore
unimplementable.

**Fix**: `v8_Function_CallCatching` (02973cfcf) returns the call's completion -
normal or throw - with the thrown value as a handle.

**Takeaway**: **A catch you open after the throw catches nothing. Capture the
completion at the call.**
