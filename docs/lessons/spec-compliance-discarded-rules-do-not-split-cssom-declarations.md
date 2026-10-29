# Spec Compliance: Discarded rules do not split CSSOM declaration blocks

**Date**: 2026-10-29
**Lesson**: Form CSSOM declaration runs after deciding which child rules survive grammar validation.

**Validation**: Six native regression blocks pass on the repaired tree, including five complete allocator-failure sweeps under std.testing.allocator. The new Crane page and final targeted A/B remain required after freezing.

**Why**: The generic CSS Syntax parser preserves boundaries before the CSSOM builder knows whether an at-rule or qualified rule is valid in its context. Carrying every raw boundary into CSSOM leaves declarations after a discarded rule in the wrong block.

**What Happened**: Three isolated BASE/TIP pairs reproduced two lost style-rule declarations in at-rule-in-declaration-list.html and four lost following declarations in var-with-blocks.html. All three aligned browsers pass these names. Blink's ConsumeBlockContents advances nested-declaration boundaries only after a retained child rule. The invalid var-containing declaration was already rejected; substitution was not the defect.

**Fix**: Within model construction, append a declaration run to the parent style while no retained child precedes it, or to the immediately preceding CSSNestedDeclarations block. Retain genuine child boundaries, including empty rules, and keep the first wrapper in conditional groups. Reuse the declaration parser's importance and ordering rules without reparsing earlier runs. Leave the generic Syntax AST and its boundary tests unchanged. Q122 and Q123 grant this interpretation.

**Takeaway**: **A discarded syntax node cannot create an observable CSSOM boundary. Validate child retention before choosing a declaration block.**

References: CSS Syntax 3 sections 5.5.2–5.5.6; CSS Nesting 1 nested declarations; Chromium 97f9cf6fa75ffd2d1f6847c167d11efc2683c833, third_party/blink/renderer/core/css/parser/css_parser_impl.cc, ConsumeBlockContents (design only).
