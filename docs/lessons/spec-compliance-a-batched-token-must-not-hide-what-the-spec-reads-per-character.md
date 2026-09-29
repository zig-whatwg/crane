# Spec Compliance: A batched token must not hide what the spec reads per character

**Date**: 2026-09-28
**Lesson**: The tokenizer batches a run of text into one text_run token, and the tree builder's insertion modes decide "whitespace or anything else" by the run's first character. A run that began with spaces was taken for "anything else".

**Why**: The spec emits one character token per character, and most insertion modes treat whitespace on its own. "in head" inserts it, "before head" ignores it, and "in body" inserts it without clearing frameset-ok. A batch is only equivalent if every character in it would have gone down the same branch. Leading whitespace doesn't, and neither does whitespace inside a run in a mode that stays put on "anything else" (the frameset modes insert the spaces and ignore the rest). Every text_run branch carried the comment "text runs contain non-whitespace text", but nothing in the tokenizer made that true.

**What Happened**: Indentation in `<head>` ("\n    <title>": LF ends a run, so "    " starts one) popped the head, and the title landed in a body. Whitespace before `<frameset>` cleared frameset-ok, so the frameset was never inserted. Top-level pages had always parsed like this. Increment 2 routed frames and document.write through the batching tokenizer too, which turned template-descendant-head/-frameset, end-tag-frameset, template-end-tag-without-start-one, and html5lib tests5/tests19's write variants red.

**Fix**: the tokenizer never starts a run on TAB, FF or SPACE (LF and CR already ended one), so a run's first character is never whitespace. That invariant is now written on `TextRun`. The three frameset modes process a run one character per token. Four tree-construction tests pin it.

**Takeaway**: **When a fast path batches what the spec processes one unit at a time, write down the property every consumer relies on, and make the producer guarantee it.**
