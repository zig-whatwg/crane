# Testing: Shared algorithm migrations need caller context tests

**Date**: 2026-10-07
**Lesson**: Replacing a duplicate algorithm requires tests for each caller's context and subtype state, even when the common traversal is correct.

**Why**: Duplicate code can hide different assumptions about realms, context node types and the state copied by subtype-specific steps.

**What Happened**: Sharing Crane's fragment parser exposed outerHTML passing a DocumentFragment as an Element context. Sharing Node's clone traversal exposed CharacterData copies created in the source realm and SVG scripts missing their already-started cloning step. The previous importNode implementation discarded children, so script-inertness tests had passed without exercising a script at all. The complete WPT comparison caught these defects after narrower parser/template tests passed.

**Fix**: Test DocumentFragment replacement and its single mutation record, clone CharacterData between distinct native contexts and script realms, and require a copied script child to exist before asserting that it stays inert. Keep the full same-worklist comparison after integrating shared algorithms.

**Takeaway**: **A green caller can be vacuous; verify that the intended nodes exist and retain the caller's realm and subtype state.**
