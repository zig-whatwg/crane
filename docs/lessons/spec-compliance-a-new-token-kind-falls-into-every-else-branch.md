# Spec Compliance: A new token kind falls into every `else` branch

**Date**: 2026-10-16
**Lesson**: Adding a kind to the HTML tokenizer's Token union makes the compiler flag only the exhaustive switches; every insertion mode that ends in `else =>` takes the new token as "anything else" without a word.

**Why**: The tree builder's insertion modes are switches on the token. Some list every kind; many end in `else =>`, which is the spec's "Anything else" branch. A new kind compiles in all of those, and lands in a branch written for other tokens. In the "initial" mode "anything else" sets quirks mode and reprocesses in "before html"; in "after body" it is a parse error that switches to "in body"; in "in frameset" it is ignored.

**What Happened**: Lane pi-parser added the processing instruction token (HTML 13.2.5.72-76, whatwg/html#12118). Fixing only the compile errors would have left `<?pi><!DOCTYPE html>` in quirks mode (the initial mode's "anything else"), `<frameset><?pi>` dropping the node, and `</body><?pi>` reopening the body. The spec gives the token a rule beside the comment token's in sixteen places: every mode that names "A comment token" names "A processing instruction token" next to it, with the same insertion location (the Document, the html element, or the current node), and the modes that delegate a comment (in head noscript, in template) delegate it too.

**Fix**: List the spec's rules for the new token first (grep the parsing chapter for the token's name and map each hit to its mode heading), then add an arm beside every `.comment` arm, whether or not the compiler asked. Test each mode with a whole-document tree (tests/html/parser_processing_instruction_test.zig), including one that pins the initial mode's quirks outcome.

**Takeaway**: **When a union gains a kind, the compiler finds the exhaustive switches; the `else` branches are yours to find - map every spec rule for the new kind to its switch before trusting a green build.**
