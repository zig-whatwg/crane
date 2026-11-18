# Spec Compliance: A parse-time sanitizer must cover every step that writes attributes, not only element creation

**Date**: 2026-11-18
**Lesson**: When sanitizing moves from "parse, then sanitize the tree" to "sanitize while parsing", every parser step that writes to an element already in the tree needs its own check: the duplicate `<html>`/`<body>` start tag merges attributes into an existing element and never passes through element creation.

**Why**: Crane's setHTML ran its parser sanitizer at element creation and then sanitized the whole fragment again after the parse, so a hole in the parse-time pass was invisible: the second pass removed whatever the first let through. HTML's streaming methods (8.5.3) insert into the live document as they parse, with no pass after the parse. The "in body" rules for a start tag named "html" or "body" add the token's missing attributes to an element made earlier. HTML filters each through the parser sanitizer configuration at that step (step 1, "continue" when the configuration does not allow it), and Crane's `TreeBuilder.copyMissingAttributes` did not.

**What Happened**: Lane blk1's streaming work passed every upstream streaming test. A Crane test written for the abort-request rule on the same tag showed that `documentElement.streamHTML()` given `<body><body onclick=...>` put the event handler attribute on the live `<body>` under the safe default configuration: red at 33467da0598 (2 of 3 subtests: the safe default and an explicit `{attributes: ["class"]}` both merged forbidden attributes; the Unsafe control passed). sanitizer-api/sanitizer-duplicate-html-body.html passed all along, because it goes through parseHTML/setHTML, which sanitize after the parse.

**Fix**:
1. `copyMissingAttributes` asks the parser sanitizer about each attribute (`allows_attribute` with the element's local name and namespace) before adding it (eefb8e9027c).
2. Crane test crane/blk1-stream-body-attributes-sanitized.html pins it for streamHTML with the safe default, with an explicit configuration, and for streamHTMLUnsafe (every attribute merged).

**Takeaway**: **Grep the tree builder for every write to an existing element (attribute merges, adoption-agency clones, reparenting) and give each the sanitizer check, and test a parse-time sanitizer through a path with no post-parse pass (streaming); a test through setHTML proves nothing about the parse-time pass.**
