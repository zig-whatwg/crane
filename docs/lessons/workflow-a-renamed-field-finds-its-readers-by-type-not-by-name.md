# Workflow: A renamed field finds its readers by type, not by name - two tree types share `first_child`

**Date**: 2026-11-15
**Lesson**: Before converting every reader of a field by its name, list the OTHER types that have a field of that name; a name-driven rewrite converts their readers too, and only the compiler tells the two apart.

**Why**: Crane has two trees with the same link names: `dom.NodeBase` (the DOM) and the HTML parser's `TreeNode` (`src/html/parser/tree_builder.zig`), both with `first_child`, `next_sibling` and `parent`-like fields, read side by side in the parser's adapters and in `tests/html/parser_*`. A grep cannot see which one `node.first_child` is.

**What Happened**: Lane nm2 made NodeBase's first-child word a leaf's own data word on CharacterData nodes, so every read had to become `firstChild()`. A script rewrote `.first_child` in 58 files; 12 test files and `src/html/window/iframe_integration.zig` read the parser's TreeNode and did not compile ("no field or member function named 'firstChild' in 'parser.tree_builder.TreeNode'"). The integrator had been asked for a grant on two lines of that file that needed no change. The reverse error - a NodeBase reader left unconverted - cannot happen silently only because the field was RENAMED (`child_or_leaf`): an unconverted reader is a compile error, where an accessor added beside the old field would have left it reading a text node's bytes as a pointer.

**Fix**:
1. Rename the field, so the old name is a compile error on the type that changed and nothing else.
2. Convert by name only in files that never name the other type (`grep -L 'TreeNode'`), and read the rest by hand.
3. Ask for file grants after the first compile, from the compiler's list, not from the grep's.

**Takeaway**: **A field's name is not its type: rename the field and let the compiler list the readers; a grep lists every type that happens to share the name.**
