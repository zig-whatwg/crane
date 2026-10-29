# Spec Compliance: Register geometric grammars in the unavailable-input gate

**Date**: 2026-10-26
**Lesson**: A new CSS length grammar must join the cascade’s geometric capability allowlist when unresolved metrics are valid stored values.

**Why**: The shared unavailable-input check runs before property computation. It must retain an unknown geometric length while rejecting an unknown metric that would determine an integer, angle or scalar. A correct parser and serializer alone cannot make the declaration survive that earlier decision.

**What Happened**: Multicol’s `column-width:1cap` parsed successfully but lost to the retained earlier candidate because the new `column_size` grammar was absent from `Builder.pick`’s `geometry_length` switch. The native regression demonstrated that loss before the registration fix. The companion `column-count:calc(1cap / 1px)` control correctly retained its earlier integer.

**Fix**: Add only the new geometric grammar to the existing allowlist. Keep the scalar path, default and shared math machinery unchanged. Check literal and mixed unknown lengths, the contrasting scalar fallback, real substitution, and allocation failures through the full cascade.

**Takeaway**: **Test a new grammar through candidate selection as well as parsing; preserve unresolved geometry without admitting unavailable scalar results.**
