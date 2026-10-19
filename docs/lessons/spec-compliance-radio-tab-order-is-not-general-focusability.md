# Spec Compliance: Radio Tab Order Is Not General Focusability

**Date**: 2026-10-18
**Lesson**: Choose a radio group's Tab representative only while deciding sequential eligibility, leaving ordinary focus and arrow navigation independent.

**Why**: A radio group contributes one sequential focus stop, but script and arrow keys can focus its other members. Sharing the group filter with general focusability would reject those valid targets and could invalidate the document's current focus designation.

**What Happened**: The radio-focus-navigation WPTs failed because Crane put every radio into the Tab order. The arrow implementation also stopped collecting after 256 members and checked only disabledness, so it could activate an invisible member while focus stayed behind. Chrome and Firefox passed all nine assigned radio assertions; Safari differed (aligned wpt.fyi revision 23b0b89b1a).

**Fix**: Follow HTML's group identity (same nonempty name, form owner and tree). In sequential eligibility, choose an eligible checked member, otherwise the currently focused member, otherwise the first eligible member. Keep this read-only and separate from the designation reader. For arrows, walk the tree without a fixed-capacity group array and use general focusability, including a member with negative tabindex. Test intervening buttons, disabled checked members, external form association, hidden and inert members, and a group larger than the old bound.

Blink's `RadioInputType::IsKeyboardFocusableSlow` additionally remembers the last focused unchecked member after focus leaves the group; Gecko's `HTMLInputElement::IsHTMLFocusable` and WebKit's `RadioInputType::isKeyboardFocusable` do not keep that state in their corresponding rules. Row 72 Q3 approves the stateless policy above and leaves persistent group state to a separate owner.

Do not rescan the whole tree for every radio during Tab navigation. The first implementation made a 20-Tab benchmark exceed the 60-second ceiling, against 7.68 seconds on BASE. Q15 grants a lazy group summary local to one synchronous order calculation, destroyed before focusing or running script. It reuses each radio's eligibility across the order passes, allocates nothing on a non-radio page, and falls back to the scan on allocation failure. Native tests check parity, every allocation failure, and the absence of script callbacks in the walk.

**Takeaway**: **Being focusable, being in the Tab order, and currently holding focus are different questions. Keep each policy at its own boundary.**
