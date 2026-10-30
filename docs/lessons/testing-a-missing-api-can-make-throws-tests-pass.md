# Testing: A Missing API Can Make a Throws Test Pass

**Date**: 2026-10-29
**Lesson**: A passing exception assertion does not prove that execution reached the intended operation.

**Why**: A TypeError from reading an absent API satisfies the same exception class as a deliberate validation error. Adding the API can expose that accidental pass as a conformance loss, even when the implemented behavior follows shipping browsers or the specification.

**What Happened**: Row128's baseline had no attributeStyleMap. Typed OM shorthand tests expecting set() to throw therefore passed before a property map was reached. Implementing maps exposed background, margin and logical-border losses. Per-subtest browser evidence separated real negative-border range errors from shipping-browser splits. The native regression test used an existing rule map and confirmed six exact failures before the setter fix; four controls showed that ordinary negative margins, background positions, longhand wrapping and math values retained their behavior.

**Fix**: Keep raw BASE and TIP messages beside exact source, runtime URL, subtest name and multiplicity. Establish the operation's prerequisites in a separate assertion or native control. Do not add an incorrect throw to recover an accidental pass; ask for the required passing-subtest disposition and retain the raw counts. A broadened set of registered tests needs its own identity check, independent of lost passes.

**Takeaway**: **Verify where an exception originates before treating an expected exception as evidence of conformance.**
