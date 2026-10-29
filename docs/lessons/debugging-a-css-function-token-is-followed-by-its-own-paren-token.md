# Debugging: A CSS function token is followed by its own "(" token

**Date**: 2026-10-29
**Lesson**: Crane's tokenizer (and properties.Stream over it) yields `repeat(` as a `.function` token AND then a separate `.left_paren` token; a function parser must consume both.

**Why**: CSS Syntax 3 makes the `(` part of the function token, so a parser written from the spec reads the first argument right after the function token. Crane's tokenizer leaves the `(` for the next token (grid_tracks.zig `require(.left_paren)`, the fit-content() arm in properties.parseLonghand), so such a parser sees `(` where it expects an argument and rejects every call.

**What Happened**: Lane gaps1's first gap decoration parser rejected every `repeat()` list (`column-rule-color: repeat(4, blue)`) while every plain list (`red, blue`) passed. The native tests failed only on cases containing repeat(); the count parser saw `(` instead of `4`.

**Fix**: After taking the `.function` token, require `stream.next().token_type == .left_paren`, then parse the arguments up to `.right_paren` (or the end of the value, which closes the function). A native test with a repeat() case pinned it.

**Takeaway**: **In Crane's CSS Stream a function's `(` is a token of its own: consume it after the function token, as grid_tracks.zig does.** (Related: [A stand-in must reject what the real one rejects](testing-a-stand-in-must-reject-what-the-real-one-rejects.md) met the same tokenizer shape from the other side.)
