# Spec Compliance: Resolve automatic minimums without changing computed storage

**Date**: 2026-10-26
**Lesson**: A box-dependent CSSOM value belongs at resolved serialization when the stored computed value must remain unchanged.

**Why**: CSS Sizing 3 §3.2 makes an automatic minimum resolve to zero when no box is generated. Flex and grid items can still need their computed `auto`, so replacing that value during the cascade would discard information that other consumers need.

**What Happened**: The Flexbox work exposed `min-width` and `min-height` returning `auto` for own `display:none`, a suppressed ancestor, and own `display:contents`. Chrome, Firefox and Safari agreed on `0px` in the integrator's probes. Four native regression cases failed with expected `0px`, found `auto` before the fix, including the allocation-failure control.

**Fix**: In `ComputedStyle.serializeResolved`, check only the two physical minimum properties, the stored `auto`, and the existing suppressed-box or own-contents state. Serialize `0px` there. Tests also retain `auto` for ordinary flex/grid items through a contents ancestor and preserve explicit minimums and other automatic sizes.

**Takeaway**: **Resolve CSSOM's box-dependent result at its boundary, and test that serialization preserves the stored computed value.**
