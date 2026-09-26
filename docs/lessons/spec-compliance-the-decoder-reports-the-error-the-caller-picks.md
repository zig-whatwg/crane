# Spec Compliance: The decoder reports the error; the caller picks the mode

**Date**: 2026-09-21
**Lesson**: A decoder that substitutes U+FFFD itself makes `{fatal: true}` impossible.

**Why**: Encoding § 8.1.1 returns `error` from the handler and § 5.1.3 turns it
into a TypeError or a U+FFFD. Deciding inside the decoder throws away the only
information the caller needs.

**What Happened**: The UTF-8 decoder wrote U+FFFD at all three error sites and
returned `input_empty`, so `TextDecoder.zig`'s `if (result.status ==
.malformed) { if (fatal) ... }` was dead code — 35 of 36 subtests in
`textdecoder-fatal.any.js` failed on `assert_throws_js`, while
`textdecoder-fatal-single-byte.any.js` passed 64,512, because the single-byte
decoder reports. The contract was already written down, in that decoder's own
comment.

**Fix**: Return `.malformed` with the spec's error extent — step 4 RESTORES the
offending continuation byte, so it is not part of the error — and give
`Decoder` a `decodeReplacement` so replacement-mode callers substitute once
instead of four times by hand.

**Takeaway**: **When one decoder in a family passes a conformance file and its
siblings do not, diff their contracts before their algorithms.**
