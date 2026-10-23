# Testing: Allocation Failure Must Cover Owned Parser Output

**Date**: 2026-10-22
**Lesson**: Exercise allocation failure across parsing, ownership transfer and declaration storage, including every unconsumed item in a shorthand expansion.

**Why**: A parser can return several owned values successfully and the caller can still fail while moving them into its collection. Cleaning up only the collection or the current item leaks the remaining values. Catching an allocation error as an invalid token can also make a parser silently discard a valid declaration.

**What Happened**: The CSS math allocation-failure test exposed an existing 26-byte leak when rules.consumeDeclarationList could not append an already-owned declaration. A separate four-color shorthand test found a swallowed OutOfMemory error in named-color parsing and uncovered ownership transfers that covered only the current assignment. Ordinary parsing and cascade tests had passed.

**Fix**: Guard owned declaration strings until their append succeeds. Track the consumed prefix of an assignment list and release the untouched suffix on every exit. Advance the prefix before calling a function whose contract consumes its argument even on error. For fixed-size shorthand expansions, reserve output capacity before acquiring component values. Propagate color allocation errors instead of treating them as grammar rejection. Run checkAllAllocationFailures across both declaration parsing and CSSOM assignment; the focused regression tests then passed 2/2 and the math parse/cascade allocation-failure case passed.

**Takeaway**: **Ownership cleanup must cover the entire untransferred suffix, and allocation failure must remain distinguishable from invalid syntax.**
