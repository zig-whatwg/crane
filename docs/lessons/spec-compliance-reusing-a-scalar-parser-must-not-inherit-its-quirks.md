# Spec compliance: Reusing a scalar parser must not inherit its quirks

**Date**: 2026-10-23
**Lesson**: Borrow a component grammar without borrowing another property's quirks-mode exceptions.

**Why**: CSS Values4 Appendix C and CSS Color4 Appendix B allow unitless lengths and hashless colors only for named properties. A parser called for another property's component still knows the borrowed property's name, so forwarding quirks mode unchanged can accidentally enable those exceptions.

**What Happened**: The new SVG paint, filter, shape and mask parsers reused color and margin-left parsing. In quirks mode this admitted hashless paint colors and unitless blur, shape and mask offsets. The native regression failed even though the standards-mode grammar tests passed.

**Fix**: Copy ParseOptions at the component boundary and clear only quirks. Keep allocator, resource provenance and the independent SVG presentation parsing mode. The regression checks paint and fallback colors, filter lengths and colors, basic-shape radii/positions, and mask position/size/shorthand, alongside text-indent's deliberately allowed quirky lengths.

**Takeaway**: **Grammar reuse does not grant the caller every compatibility exception of the reused property.** Test component grammars in quirks mode too.
