# Spec Compliance: A predicate precondition is not a type test

**Date**: 2026-10-03
**Lesson**: Classify the input before calling an abstract operation whose contract requires that type.

**Why**: A boolean result does not mean a predicate accepts every JavaScript value. ECMAScript IsDetachedBuffer requires an ArrayBuffer; it does not classify arbitrary objects or SharedArrayBuffers.

**What Happened**: IndexedDB's value-to-key algorithm called IsDetachedBuffer before its array branch. The adapter answered true for a non-ArrayBuffer, so valid arrays became DataError and an array-index getter's own exception never ran. The direct key regression measured four of six passing subtests after the key protocol helpers landed; both array cases failed.

**Fix**: Follow ED7.4's type dispatch using the protocol's existing classification contracts. A view descriptor includes detached state. With views excluded, ordinary BufferSource conversion identifies an ArrayBuffer, making IsDetachedBuffer valid. Remaining AllowSharedBufferSource conversion handles SharedArrayBuffer, which cannot detach. Non-buffer objects then reach the Array exotic-object branch without invoking user methods. Release the empty copy when a detached ordinary buffer is rejected.

**Takeaway**: **An abstract operation's input precondition must be established before interpreting its answer.**
