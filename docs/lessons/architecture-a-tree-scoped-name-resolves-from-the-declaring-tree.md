# Architecture: A tree-scoped name resolves from the tree that declared it - carry the scope on the computed value

**Date**: 2026-11-07
**Lesson**: An animation-name (like a font-family name) is a tree-scoped reference: it looks up its @keyframes from the tree of the sheet whose declaration won the cascade, not from the element's own tree, because a `:host` or `::slotted()` rule declares inside a tree the element is not in.

**Why**: CSS Scoping makes @keyframes names tree-scoped. A shadow tree's `:host { animation: spin 1s }` styles the host - an element of the OUTER tree - and `spin` is defined in the shadow tree's sheet. An element-outward lookup (the element's tree, then its hosts' trees) never visits that inner tree, so the name finds nothing. Blink carries the scope on the computed value (ScopedCSSName's TreeScope), WebKit too (nameStyleScopeOrdinal).

**What Happened**: Lane anim1 (batch 3, C2 CSS Animations) first designed the element-outward lookup as a stated deviation. The integrator asked whether the cascade already carried the declaring scope. It did: css.cascade.Source.tree_scope is set per matched block (a shadow root's serial for its sheets, :host, ::slotted rules) and reaches computeValue as ValueSource.tree_scope; font-family already captured it into its computed value. css/css-shadow/keyframes-003.html (:host), -004 (::slotted) and -006 (:host::before) fail with the outward lookup and pass with the captured scope.

**Fix**: css.animation_values.List gained `tree_scope` (ignored by serialization, part of eql); cascade.computeValue sets it for animation-name, as for font-family. The style engine's findKeyframes starts at the active scope whose root has that serial (the document's sheets for 0, the element's own tree for a scope with no sheets, i.e. a style attribute's) and walks outward through each host's tree.

**Takeaway**: **Before writing a "lookup from the element's tree" deviation for a name, check whether the cascade already knows the declaring tree - it usually does - and capture it on the computed value the way an existing tree-scoped property does.**
