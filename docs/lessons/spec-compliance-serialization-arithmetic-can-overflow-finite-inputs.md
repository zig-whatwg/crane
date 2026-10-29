# Spec Compliance: Serialization arithmetic can overflow finite inputs

**Date**: 2026-10-26
**Lesson**: A grammar's finite-number check does not prove that a later coordinate conversion stays finite.

**Why**: SVG relative coordinates are individually valid finite values, yet adding one to the current point can overflow. A relative control point can overflow even when that segment's endpoint does not. Converting earlier segments before discovering this leaves a mixed output unless the serializer owns the whole conversion.

**What Happened**: Row125's shape-outside absolute-path serialization needed to preserve the shared path scanner and clip-path's relative serialization. Q50 required a whole-value relative fallback for an unrepresentable absolute sum, with this oversized-coordinate gap reported explicitly.

**Fix**: Convert into an owned temporary, check every endpoint and control-point addition, and publish only a complete finite result. On the ruled overflow path, discard all converted text and retain the original canonical relative value. Cover finite boundary sums, late overflow, control-point overflow, unaffected consumers and allocation failures.

**Takeaway**: **Validate arithmetic where it happens, and preserve the whole original value when the ruled fallback requires it. Do not change a shared grammar to hide a serializer's limit.**
