# Testing: Pseudo applicability probes need distinct controls

**Date**: 2026-10-26
**Lesson**: A computed value that stays unchanged proves filtering only when the declaration's control value differs from the original value.

**Why**: Both an applied declaration and an ignored declaration can produce the initial value. Checking only that a pseudo-element's computed value stayed unchanged confuses those two behaviors.

**What Happened**: A CSSOM probe tested `text-autospace:no-autospace` on `::first-line` and `::first-letter`. All three browsers reported `no-autospace` before and after, and on the normal control. The initial classification called the property filtered. Auditing the raw records showed these six records were inconclusive; the other supported cases had distinct controls.

**Fix**: Keep support, specified, original-pseudo, resulting-pseudo and normal-control values in the raw evidence. Require the control to differ from the original before classifying the unchanged result as filtered. The corrected `ideograph-alpha` / `ideograph-numeric` probe showed Firefox and Safari apply both values; Chrome did not support those values. The original exclusion was withdrawn before any product edit, and the property was admitted by the shipping majority. Preserve the original evidence when correcting a decision.

**Takeaway**: **A probe must distinguish the competing behaviors; a default-valued control cannot establish whether a declaration applies.**
