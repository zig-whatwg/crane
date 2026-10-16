# Spec Compliance: Parse selectors over CSS tokens, not characters

**Date**: 2026-10-16
**Lesson**: Selectors are "parsed according to a CSS grammar": tokenize the string exactly as CSS Syntax 3 does, then match the Selectors 4 grammar against the tokens.

**Why**: Escapes, comments, NUL and surrogate replacement, numbers and dimensions, and blocks that the end of the input closes all come from the tokenizer. A character-level selector scanner has to rediscover each of them, and every one it misses is a valid selector that throws SyntaxError (or an invalid one that does not).

**What Happened**: Crane's selector tokenizer read characters into its own token set (`^=` as one token, numbers as idents, no escapes, no comments) and its parser accepted trailing junk. In gen 136, 554 selector subtests failed: 55 of 68 in ParentNode-querySelector-escapes, `.5cm` accepted as a class, `[class^= apple]` and `[align="center"` rejected, every `ns|`/`*|`/`|` form rejected, An+B with whitespace rejected. Lane selectors replaced the tokenizer with CSS Syntax 3 section 4 (allocation-free, values decoded once by the parser) and the parser with section 16's grammar over those tokens (blocks matched by their closing token or the end of the input); every dom/nodes selector file then passed in full.

**Fix**: src/selector/tokenizer.zig and parser.zig (lane selectors). The validity table in tests/selector/parser_validity_test.zig was red 0/10 groups at the branch point.

**Takeaway**: **A selector is a CSS grammar over CSS tokens: tokenize per CSS Syntax 3 first, and validity questions (escapes, unclosed blocks, whitespace inside an attribute selector) answer themselves.**
