# Architecture: Resolved CSSOM Values Do Not Replace Computed Values

**Date**: 2026-10-27
**Lesson**: Share the resolved-value helper between longhand and shorthand serialization while keeping the computed value intact.

**Why**: CSSOM §9 resolves an applicable relative auto inset to zero or to the negative of its opposite absolute length. Inheritance and Typed OM still consume the computed auto value. Mutating stored computed values to satisfy getComputedStyle changes those other consumers.

**What Happened**: Row128 found that adding a longhand serialization branch alone would leave inset, inset-inline and inset-block inconsistent: CSSStyleDeclaration builds shorthand text from a separate loop over computed longhands. Q76 granted one read-only helper called at both boundaries.

**Fix**: Resolve only the style-derived subset through ComputedStyle.get, keyword and display. Feed that result to both serializers. Leave percentage geometry, over-constrained sides and non-applicable boxes at their computed values. Pin the original computed auto values after serializing and exercise logical mappings and shorthand consistency.

**Takeaway**: **Resolve at the CSSOM read boundary; share that calculation without rewriting the source value.**
