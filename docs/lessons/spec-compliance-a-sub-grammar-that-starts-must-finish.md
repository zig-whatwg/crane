# Spec Compliance: A sub-grammar that starts must finish

**Date**: 2026-11-12
**Lesson**: When an optional part of a grammar (`auto || <ratio>`'s ratio) consumes tokens and then fails, the whole value is invalid; returning the part that matched before it leaves the consumed tokens behind, and a caller that checks only "at end" accepts the junk.

**Why**: Crane's property parsers take a `Stream` and return `?Value`; `parseLonghand`'s caller decides validity by `stream.atEnd()` after the call. A parser that returns an earlier success after a later sub-parser has advanced the stream hides the failure: the stream is at its end because the failing sub-parser ate the rest.

**What Happened**: Lane cssprop1 b2's `aspect-ratio` parsed `auto`, then tried `<ratio>`; on `auto 16 /` the ratio read `16 /`, failed on the missing second number, and the parser returned `auto` - with the stream at its end. aspect-ratio-invalid.html, passing 11/11 before the property existed, lost "auto 16 / should not set the property value". The native tests had `1 /` invalid but not `auto 16 /`.

**Fix**:
1. Decide whether the optional part starts by peeking (`<ratio>` starts with a number token or a math function); only then call its parser.
2. Once it has started, its failure is the value's failure: `orelse return null`, never the earlier match.
3. Test the partial forms after every optional prefix (`auto 16 /`, `auto 1 / auto`), and run the property's `-invalid.html` file in the probe: a new property can turn its passing invalid file red.

**Takeaway**: **Peek before an optional sub-grammar; once it has consumed a token, its failure invalidates the whole declaration.**
