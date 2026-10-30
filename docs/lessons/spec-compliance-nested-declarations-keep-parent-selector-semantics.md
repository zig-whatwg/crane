# Spec Compliance: Nested declarations keep parent selector semantics

**Date**: 2026-10-27
**Lesson**: Resolve a nesting selector and inherit a nested declaration block with two distinct operations.

**Why**: `&` represents the parent selector list with the specificity behavior of `:is()`, and cannot represent a pseudo-element. CSSNestedDeclarations instead uses the parent's individual selectors, including their individual specificity and pseudo-elements. Treating every declaration run as an implicit `&` rule changes both facts.

**What Happened**: Reading CSS Nesting 1 sections 4–5 and WebKit's separate RuleSetBuilder paths exposed the distinction before implementation. WebKit revision 3ef14dfb5202ec892329ebc5e1667dd9d9b88c4c resolves a style rule's parent reference separately from adding StyleRuleNestedDeclarations. The Q32 browser probe also pins the specificity contribution of a pseudo-element parent without allowing that branch to match through `&`.

**Fix**: Preserve the original selector AST for CSSOM. Build a lifetime-safe resolved representation for matching nested style rules, replacing parent references with the equivalent parent-list operation. Preserve the parent's actual matching list for CSSNestedDeclarations. Prepare every descendant replacement before committing a selector mutation, so allocation failure leaves the live tree intact and no child borrows freed parent text.

**Verification**: The semantic tests preserve individual specificity and pseudo-element behavior. The initial recursively copied representation showed exponential growth; the accepted implementation instead owns immutable counted parent-selector nodes. Separate storage, copied-holder, allocation-failure and mutation tests establish that representation's ownership contract. Those storage results do not establish matching-speed acceptance.

**Takeaway**: **A declaration run inherits the parent's selectors; it is not a synthesized nested style rule.**
