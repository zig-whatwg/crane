# Spec compliance: Preserve the owning property's quirks

**Date**: 2026-10-24
**Lesson**: A shared component parser must apply the containing property's compatibility rules, including exceptions that the property explicitly allows.

**Why**: Clearing quirks prevents borrowed grammar from inheriting another property's exception, but clearing it unconditionally can remove the caller's own required exception.

**What Happened**: Standalone background-position passed through two adapters that both cleared quirks. The shared scalar parser could accept unitless lengths, but never saw the required mode. The position adapter also rejected its valid calculation result. Thirteen unitless-length WPT assertions regressed when the property became recognized; earlier equality between two empty computed values had concealed the missing implementation.

**Fix**: Preserve the caller's mode for the standalone background-position pair, while keeping the whole background shorthand and other position grammars strict. Accept the math owner's typed length-percentage result and carry it through both computed offset consumers. A strict unitless-length rule is separate from valid length admission: shared shorthand parsing should also accept valid root-font units, with positive specified and computed controls. Test each allowed form at parser, declaration, setter and computed boundaries, require nonempty expected output, and retain positive-recognition controls for the strict callers.

**Takeaway**: **Choose compatibility rules from the destination property, not from a blanket policy for the reused parser.** Pair mode-specific positive cases with controls for every shared caller.
