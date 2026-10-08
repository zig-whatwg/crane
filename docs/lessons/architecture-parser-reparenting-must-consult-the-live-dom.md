# Architecture: Parser reparenting must consult the live DOM

**Date**: 2026-10-07
**Lesson**: A parser token tree cannot stand in for the DOM after script has moved nodes.

**Why**: The adoption agency algorithm and foster parenting refer to live parents and children. Script, including custom element reactions, can change those relationships while the parser's stack and formatting list retain the same elements.

**What Happened**: Crane's tree builder rewired its private TreeNodes, but its adapter only appended DOM children. Formatting reconstruction lost token attributes, moves did not remove existing parents, and script-created children were absent from the private tree. A cycle attempt also requires removal before the subsequent insertion is rejected.

**Fix**: Preserve formatting tokens with owned attributes. Give the adapter explicit insertion locations, removal operations, and a move-all-live-children operation. Resolve a fostered table's parent in the live DOM. Keep parser references alive through the existing engine ownership protocol and check generations before following saved native pointers.

**Takeaway**: **Keep parser state for parsing decisions; perform DOM moves against the live DOM, in the specified order.**
