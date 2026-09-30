# Spec Compliance: A parsed element is inserted before its text

**Date**: 2026-09-29
**Lesson**: Crane's parser inserts a `<style>` into the DOM empty and flushes its text afterwards, so an element that reacts to insertion and to children changing processes every parsed instance twice - once with no text.

**Why**: HTML runs "update a style block" when "the element is popped off the stack of open elements of an HTML parser", and on becoming connected only when it is not on that stack. The parser mirrors its tree into the DOM incrementally: the element is appended when its start tag is seen, and its text arrives in a later flush (`flushPendingText`) - not always before the end tag, since the text-mode end tag popped without flushing. Insertion and children-changed steps alone cannot tell a parsed element from one script builds.

**What Happened**: The first style element implementation updated on insertion and on children changed. For a parsed `<style onload>`, that made one style sheet for the empty element and another for its text, and would have fired `load` twice - the double-fire lesson (architecture-load-and-domcontentloaded-were-each-fired-twice.md) in a new place. Blink and Gecko both carry the signal: Blink's StyleElement skips insertion and children changes while `created_by_parser_`, and processes in FinishParsingChildren.

**Fix**: d0ea645a2. The parser drivers mark a style element they create (`dom.style_sheet_owners.createdByParser`, beside `markParserInserted` for scripts); the tree builder's text insertion mode flushes the element's pending text and then reports the pop through a new adapter callback (`setDomAdapterPoppedCallback`); the style element ignores its insertion and children-changed steps until the pop. Crane test crane/net-style-events ("a parsed style element fires load once").

**Takeaway**: **An element whose processing reads its children must hear from the parser when they are all there: for a parsed element, insertion and children-changed run before its content has arrived.**
