# Architecture: A component list's property is part of its equality

**Date**: 2026-11-12
**Lesson**: `text_values.Components` compares its `property` in `eql`, so the halves of a shorthand whose longhands share one grammar (contain-intrinsic-width/-height) never compare equal unless every longhand stores its lists under one canonical property.

**Why**: Components carries the longhand it belongs to so that `serialize` and `compute` can special-case it (clip's `rect()`, the ratio's `a / b`, the dash list's commas). Shorthand serialization collapses an equal pair (`auto 1px auto 1px` -> `auto 1px`) with `Value.eql`, which for Components includes the property.

**What Happened**: Lane cssprop1 b2 planned to create each `auto <length>` list with the longhand being parsed. The shorthand contain-intrinsic-size would then have serialized `auto 1px auto 1px` (WPT expects `auto 1px`), because the width's list and the height's list named different properties. The four longhands (two of them logical) store their lists under `.contain_intrinsic_width`; the per-property rules key on that one name, and interpolation's `mixComponents` dispatches on the animated longhand, not the list's property.

**Fix**:
1. Give a family of longhands with one grammar one canonical Components property, and say so where the list is created.
2. Key serialization and computation special cases on that canonical property; key combination on the longhand being animated.
3. Test the shorthand's equal-pair collapse with a multi-part value, not only with single tokens.

**Takeaway**: **A value's identity includes every field `eql` reads: choose those fields so equal CSS values compare equal across the longhands that share a grammar.**
