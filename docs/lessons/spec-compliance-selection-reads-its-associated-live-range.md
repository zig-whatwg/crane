# Spec Compliance: Selection reads its associated live Range

**Date**: 2026-10-10
**Lesson**: Associate the live Range when a Selection method runs, and derive anchor and focus from its boundaries and direction.

**Why**: Range is already responsible for following DOM mutations. A second copy of Selection's anchor and focus becomes stale when script calls Range.setStart or a node is removed.

**What Happened**: Selection.collapse stored raw node/offset pairs and delayed making a Range until getRangeAt. A node removed between those calls left Selection pointing at the removed node, and addRange copied boundaries that no longer followed its Range. The same implementation omitted validation and document checks, producing thousands of failures across collapse, extend and addRange WPT files.

**Fix**: Validate in each method's specified order, construct and set both boundaries before replacing the associated Range, and retain it through the existing traced range edge. Read its live start/end for getters, with direction choosing anchor/focus. Use the boundary-point comparison algorithm for cross-node and ancestor/descendant ordering. Document associates its Selection through an owner-installed hook and traces the reciprocal document edge after wrapping the Selection.

**Limit**: This model covers same-root selections, including a shadow tree. Browsers also keep composed endpoints across different shadow roots that cannot fit into one DOM Range. That additional state and its mutation/lifetime design are a separate follow-up (codex-selection Q8); do not infer that a DOM Range alone represents it.

**Takeaway**: **Range identity and live boundaries are Selection's state, not a cache to reconstruct from copied endpoints.**
