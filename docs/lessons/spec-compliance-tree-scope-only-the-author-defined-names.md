# Spec Compliance: Tree-scope only the author-defined names

**Date**: 2026-11-12
**Lesson**: A computed value that carries the tree scope of the declaration naming it (a counter style, a font family, an animation) must carry it only for author-defined names; the predefined names of the same grammar are keywords, one value from every tree.

**Why**: Scoping 1's tree-scoped names exist because an `@counter-style` (or `@keyframes`, `@font-face`) rule is looked up from the tree that named it. A predefined counter style (`circle`, `decimal`, Counter Styles 3 §§6-7) is not looked up in any tree: Blink parses it as a CSSIdentifierValue and only other names as tree-scoped custom idents. Scope it anyway and two equal declarations from different trees compare unequal - a change of value that starts transitions and defeats style sharing.

**What Happened**: Lane cssprop1 b2 made list-style-type's computed counter-style name carry its declaration's scope (list-style-type-transition-tree-scope-custom-ident.html, Chrome 1/1). The native test used `custom` only. The FULL A/B lost the sibling file list-style-type-transition-tree-scope-keyword.html (1 -> 0): `circle` moving from a shadow tree to the document now started a transition. Fixed by scoping only names that are not predefined (counter_style_descriptors.isPredefined), then a targeted re-check of css-lists, css-counter-styles, css-pseudo, css-content and cssom.

**Fix**:
1. Before giving a computed name a scope, exclude the grammar's predefined names (and strings, symbols()).
2. Test both directions: an author name differs across scopes; a predefined name (several, in mixed case) does not.
3. When a WPT file tests "X changes", look for its sibling testing "Y does not change" in the same directory, and probe both.

**Takeaway**: **Scope is part of a name's identity only where a rule is looked up by that name; a predefined keyword has no tree.**
