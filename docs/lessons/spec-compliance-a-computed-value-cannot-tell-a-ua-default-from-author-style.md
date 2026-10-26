# Spec Compliance: A computed value cannot tell a UA default from author style

**Date**: 2026-10-26
**Lesson**: When the browsers' behaviour depends on WHERE a style came from (the UA sheet or the page), the computed value is not enough. The editing join needed the cascade origin.

**Why**: Computed style is what the cascade produced, with its origin thrown away. `pre { white-space: pre }` from the UA sheet and the same rule in a page's `<style>` compute identically. Chrome and Safari still treat them differently: when a line moves out of a `<pre>`, they keep its white-space in a new `<span style="white-space:pre">` only when an author declaration set it.

**What Happened**: Lane editing2 (batch 1b) built Gecko's white-space join (HTMLEditor::MoveNodeOrChildrenWithTransaction). It compares the moved node's computed white-space with its new parent's, then styles the moved element or wraps the moved text. Gecko skips a `<pre>` outright (ConsiderWhetherPreserveWhiteSpaceStyle). That is why Firefox scores 28/46 on editing/other/join-pre-and-other-block.html while Chrome and Safari score 46/46: the 18 failing subtests add `<style>pre { white-space: pre }</style>` and expect the span. Gecko's own TODO there names Chrome and Safari as the target ("If `white-space` is specified by non-UA stylesheet, we should preserve it"). No computed-style read could tell the two cases apart.

**Fix**: Crane gained one read-only query, `dom.style.engine.authorDeclares(element, names)`. It runs the element's existing rule matching (collectMatched) and reports whether a block of the AUTHOR origin declares any of the named properties. The author origin is the sheets and the style attribute, never the UA sheet or presentational hints. Pass longhand names: a shorthand in a sheet is stored as its longhands. The join skips a `<pre>` only when no element from the moved node up to that `<pre>` has an author white-space declaration.

**Takeaway**: **When behaviour turns on "did the page set this?", ask the cascade for the declaration's origin. Never infer it from the computed value, which is identical either way.**
