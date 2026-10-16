# Spec Compliance: A reflection failure can come from an own accessor

**Date**: 2026-10-13
**Lesson**: Trace the generated delegate and its own-accessor override before changing a shared reflection algorithm.

**Why**: The reflection harness groups assertions by an IDL type, but some members have special getter or setter algorithms. A generated fallback runs only when the impl does not declare the corresponding accessor.

**What Happened**: The reflection files reported hundreds of integer, boolean-type and attribute-presence failures. Their main causes were HTMLElement's own tabIndex and hidden accessors: strict integer parsing and a constant default in the first, null for absence and an unconditional attribute write in the second. The ordinary numeric and boolean reflectors were not the source of those failures.

**Fix**: Follow each generated call into its selected accessor. Read the member's complete algorithm as well as the generic reflection rules. Test hidden's nullable boolean/number/string union, including objects whose DOMString conversion is empty or throws. Test tabIndex's HTML integer prefix and historical element defaults independently of focusability.

**Takeaway**: **A failure message names an assertion; the generated dispatch and the member's prose identify the algorithm to fix.**
