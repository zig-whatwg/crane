# Spec Compliance: Cascade Order Includes Each Declaration

**Date**: 2026-10-22
**Lesson**: Preserve declaration order inside a rule as the final cascade tie-break, especially when logical and physical properties map to the same computed slot.

**Why**: A source-order number shared by every declaration in a rule cannot distinguish two declarations after logical-to-physical mapping. A stable sort does not supply the missing priority: the later declaration must win.

**What Happened**: Adding logical sizing properties exposed width winning over a later inline-size in horizontal writing mode. A regression using already-supported margin-left and margin-inline-start reproduced the same defect, independently of the new sizing feature. Both candidates had the same rule source order.

**Fix**: Record each candidate's appearance order and compare it only after all existing cascade priorities tie. Test both declaration orders, important declarations, logical mapping, and CSSOM updates that move a declaration to the end of its logical property group. The focused sizing and legacy margin tests passed after adding this final criterion.

**Takeaway**: **A rule's source order and a declaration's order are distinct parts of the cascade.**
