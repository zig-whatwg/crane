# Debugging: Optional CSS groups must restore the token stream

**Date**: 2026-10-26
**Lesson**: A failed optional grammar alternative must restore every token it consumed before the caller tries another alternative or supplies a default.

**Why**: A shorthand distinguishes a missing component from an invalid component only through the component parser's result and stream position. Returning null after consuming an invalid group can make the shorthand mistake the group for an omitted value.

**What Happened**: The first text-spacing implementation accepted `trim-start punctuation punctuation` and serialized it as `trim-start`. Its autospace parser consumed both punctuation tokens, detected the duplicate and returned null. The shorthand then saw end-of-input and supplied autospace's default. Testing the longhand alone did not expose this: the longhand caller rejected null correctly. The shorthand regression failed with expected empty output, found `trim-start`.

**Fix**: Save the stream before consuming an optional autospace group and restore it whenever that group returns null. Keep allocation failures as errors and release any partial values. Test malformed groups after a valid first group, both ambiguous group orders, and allocation failures through the containing shorthand.

**Takeaway**: **Exercise an invalid component through every shorthand that can treat it as optional; a longhand rejection does not prove the shorthand rejects it.**
