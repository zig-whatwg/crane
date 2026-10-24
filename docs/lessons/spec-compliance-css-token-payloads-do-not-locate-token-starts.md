# Spec Compliance: CSS token payloads do not locate token starts

**Date**: 2026-10-23
**Lesson**: Keep a source offset alongside lookahead; a token's value slice need not start at its spelling in the input.

**Why**: An unquoted URL token stores the URL argument as its value. Subtracting that slice's pointer from the input pointer points past `url(`. Quoted URLs use a different token shape, which can hide the mistake.

**What Happened**: Row 119 found that `content: url(picture.svg) 'tail'` was rejected before URL resolution. The property stream handed the content parser the argument and closing parenthesis instead of the complete URL token. Four of six public regression tests failed.

**Fix**: Record the tokenizer position after whitespace and comments but before consuming the token. Save and restore that offset with cached lookahead. Pin quoted, escaped, padded and mixed-token forms, lookahead, mark/restore and EOF. Blink's [CSSParserTokenStream](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/parser/css_parser_token_stream.h) also keeps source offsets independently of token payloads; its implementation was read as a design reference, not copied.

**Takeaway**: **Token contents and source spans are different facts; preserve each at its own boundary.**
