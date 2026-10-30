# Testing: A Test Name Does Not Identify the Throwing Operation

**Date**: 2026-10-28
**Lesson**: When an exception test contains several operations, isolate the expression that actually throws before changing the API named in the test.

**Why**: An assertion observes the whole expression. Construction, argument conversion, property access and the final method call can each throw; a descriptive test name does not prove which one did.

**What Happened**: Two CSS Typed OM arithmetic tests were named as incompatible-type checks but evaluated `new CSS.px(0)[methodName](CSS.px(1), CSS.s(2))`. Crane allowed the expression and failed the tests. Chrome 156 and Safari 27 probes showed that `new CSS.px(0)` itself throws TypeError, while an ordinary factory call followed by the same multiplication or division succeeds. Rejecting compound-unit arithmetic would have introduced a second defect.

**Fix**: Probe the factory with and without `new`, then call each arithmetic method on the normally created value. Record the exception, resulting class, serialization and type separately. Read the complete numeric algorithm and the WebIDL operation-function contract. Route constructible operation functions to the bindings owner, retain the valid numeric algebra, and preserve the original WPT failures as evidence until the binding is repaired. This was row128 Q134, with the probe and two browser records retained for integration.

**Takeaway**: **An exception test identifies an expression; reduce it before assigning the defect to an operation.**
