# Spec Compliance: Selection focus is a position decision

**Date**: 2026-10-27
**Lesson**: A selection boundary's editable ancestor does not by itself determine whether selection movement focuses that ancestor.

**Why**: Blink focuses the canonical selection position's root editable element. A raw DOM boundary can lie outside that editable position even while its node belongs to an editable host. Focus and the Selection's exposed Range are separate results.

**What Happened**: Three-browser probes covered eleven element-boundary rows and sixteen text-position rows. Empty hosts, inline neighbours, hidden text, preserved whitespace and empty Text focus the editable host. Chrome and Safari leave focus alone for collapsible whitespace beside a noneditable block and for inert text; Firefox focuses the host in those cases. All three reject text inside a contenteditable=false span. Every browser preserves the exact supplied anchor node and offset. The upstream ancestor/descendant collapse expectations therefore do not all represent the browser majority.

**Fix**: Read editability, computed white-space and display through their existing APIs. Find the root editable region, examine the boundary's adjacent candidates, and apply the measured structural exclusions without changing the Range or inventing a caret rectangle. Focusing must be the last operation, because a focus listener can replace the selection and focus again.

The design reference is [Blink FrameSelection::SetFocusedNodeIfNeeded at 8d5ba1795f0c50b90072399d0403389df6eebbd6](https://github.com/chromium/chromium/blob/8d5ba1795f0c50b90072399d0403389df6eebbd6/third_party/blink/renderer/core/editing/frame_selection.cc). The browser probes and majority rulings are row129 Q10/Q20 (2026-10-27); no engine code was copied.

**Takeaway**: **Test the position, focus outcome and unchanged Range independently.** A visibility shortcut that rejects display:none text would contradict all three browsers, and an ancestor shortcut would incorrectly focus inert or noneditable positions.
