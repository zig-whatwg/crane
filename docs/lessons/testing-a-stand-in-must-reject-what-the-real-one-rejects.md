# Testing: A stand-in must reject what the real one rejects

**Date**: 2026-10-01
**Lesson**: src/css's CSS.supports tests used a stand-in selector check that accepted any text without ":unknown" or a comma, so it accepted "(div > p)" - and hid that the evaluator passed the function's own "(" along with the selector.

**Why**: The CSS tokenizer leaves a function token's "(" for the next token. The evaluator treated the function token as an opener too, so `selector(div > p)` reached the check as "(div > p)". The permissive stand-in said yes; src/selector, the real check, said no.

**What Happened**: All css unit tests passed; the tests/v8 case `CSS.supports('selector(div > p)')`, which binds the real selector parser, returned false. The same double-opener bug made a top-level `;` after a function in a custom property value read as nested.

**Fix**: Count only `(`, `[`, `{` tokens as openers and consume the "(" after a function token; make the stand-in reject parentheses (and anything else the real parser rejects that the code under test could produce), so the old behaviour fails the unit test.

**Takeaway**: **A fake dependency must be at least as strict as the real one on the inputs your code can hand it - otherwise it certifies the bug.**
