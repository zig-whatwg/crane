# Spec Compliance: Accept typed lengths independently of their storage tag

**Date**: 2026-10-28
**Lesson**: A grammar consumer must accept every representation its scalar parser uses for a valid CSS length.

**Why**: The CSS value type and its storage tag are different contracts. Common units can use a direct length value while extended relative units use a typed calculation, even without a math function in the authored text.

**What Happened**: Position parsing accepted `calc(1cap + 2px)` and background-position's bare `cap` lengths, but rejected the same bare length for perspective-origin and object-position. A filter accepted the calculation tag only for a math token or background grammar. That discarded a valid length already returned by the shared scalar parser. The native RED isolated four failures while calc, zero, background, invalid dimension and anchor-function controls passed.

**Fix**: At the Position consumer, accept both the direct length and typed calculation representations. Preserve the scalar parser's existing grammar and type checks. Keep per-property availability policy downstream: accepting a relative length does not provide its missing font metrics. Pin specified serialization, the differing cascade policies, invalid scalar categories, anchor rejection and allocation failures.

**Takeaway**: **Validate the scalar parser's semantic result; do not infer its storage representation from the authored token shape.**
