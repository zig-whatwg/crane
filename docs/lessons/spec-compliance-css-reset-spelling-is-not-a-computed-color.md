# Spec Compliance: CSS reset spelling is not a computed color

**Date**: 2026-10-23
**Lesson**: Preserve a shorthand's specified initial spelling independently of the equivalent computed color, including in the allocation-free initial-style table.

**Why**: `transparent` and `rgba(0, 0, 0, 0)` have identical computed components but different specified serialization. A shorthand that omits its color still creates a specified longhand value. Replacing its initial keyword with RGBA loses information before CSSOM reads it.

**What Happened**: Row 118's follow-up reproduced `background:none` resetting `background-color` to an RGBA value. Q86 explicitly chose `transparent` for that reset, while preserving both authored spellings. The user approved losing the contradictory `background-valid.html:34` expectation; that trade does not authorize changing other authored colors or another row's background grammar.

**Fix**: Give the typed Color an allocation-free `transparent_keyword` variant for the specified initial/reset. Resolve it to RGBA at computation, and explicitly keep `initialComputed(.background_color)` as RGBA too: the initial-style table bypasses the ordinary computation path. Update exhaustive Color queries, including the allocation-free recursive `containsCurrentColor`, rather than making consumers inspect expression variants. Pin authored spellings, shorthand resets, ordinary computed styles and the initial-style table separately with `std.testing.allocator` and script tests.

**Takeaway**: **Equal computed components do not make specified values interchangeable. Test every route that constructs an initial computed value when changing the specified representation.**
