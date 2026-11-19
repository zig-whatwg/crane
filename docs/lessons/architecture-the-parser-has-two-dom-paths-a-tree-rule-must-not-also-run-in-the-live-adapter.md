# Architecture: The HTML parser has two DOM paths - a tree-builder rule must not also run where the live adapter already applies it

**Date**: 2026-11-19
**Lesson**: The tree builder serves a tree-then-convert path (setHTML, parseHTML, innerHTML: its own TreeNode tree, converted after) and a live DOM adapter path (documents, streaming HTML: every TreeNode insertion mirrored into the live DOM at once); a parser rule added to the tree builder runs on both unless it asks which one it is on.

**Why**: The live adapter (src/html/parser_script_execution.zig DomTreeAdapter, parser_dom_mutation.zig) already implements some parser rules against the live DOM - streaming HTML's sanitizer element actions and insertion target redirection map among them - because script can move nodes between two tokens there, so the rule must be decided against the live tree. The tree builder cannot tell from its inputs alone: `parser_sanitizer` is set on both paths.

**What Happened**: Lane maj2 made the tree builder apply the sanitizer's "Remove" / "Replace with children" actions and the insertion target redirection map while parsing (so setHTML's text coalesces: sanitizer-api +49). The targeted A/B then lost 18 domparsing/stream-html-sanitizer and stream-insertion-logic subtests: on the streaming path both layers redirected the same replaced element, and the live adapter's own redirect no longer saw the element it expected.

**Fix**: The tree builder's element actions run only on the tree-then-convert path - `treeSanitizer()` returns the configuration only while no live adapter is attached (`dom_adapter_on_inserted == null`), the same test `patchedLocation` uses for template content patching. Attribute, comment and processing-instruction filtering stay on both paths: they are idempotent and the adapter does not repeat them.

**Takeaway**: **Before adding a rule to tree_builder.zig, grep the live adapter (parser_script_execution.zig, parser_dom_mutation.zig) for it; if the adapter implements it, gate yours to the tree-then-convert path - and A/B domparsing/ (the streaming tests) beside the files you target.**
