# Testing: A test encoder written beside its decoder can share its mistake

**Date**: 2026-10-12
**Lesson**: A codec test that round-trips through an encoder written for the test proves only that the two agree; pin the encoder's output to bytes from an independent encoder that a reference decoder accepts, and end hand-built streams where the format says they end.

**Why**: The GIF decoder's hardest rules - when an LZW code widens, what a full table does (the deferred clear) - are the rules a test encoder must get right to produce the stream at all. Written by the same person, the same week, the encoder mirrors the decoder's reading of Appendix F. If that reading is wrong, both are wrong the same way, every round trip passes, and real files fail.

**What Happened**: Lane imggif's GIF tests needed streams no WPT file contains: a table filled and never cleared (deferred clear), every minimum code size, codes past the next free one. The test's encoder tracked the decoder's width state to choose each code's width - a mirror by construction. Two things kept it honest:

1. A scratch Python encoder, written separately with giflib's width rule (widen after writing a code once the next code to assign reaches the width's limit, never past 12), whose streams PIL 12.0 decoded back to the input for deferred-clear and clearing tables. The Zig test pins its own encoder's bytes for one fixed input to that encoder's SHA-256: if the two encoders ever disagree, the test says so before any decoder is involved.
2. The real-file check: all 30 GIFs in WPT, from real encoders, against PIL's pixels.

A second trap showed up in the first green run. A hand-built stream with no end code ended in the middle of a byte; the zero padding bits after the last code were enough for one more code, which decoded as index 0 - one red pixel where the test expected transparency. The decoder was right (Firefox and Safari read padding the same way); the test stream was not what it meant to be.

**Fix**: Pin the test encoder's output to an independent encoder's (a digest over a fixed input is enough), validate that one against a reference decoder outside the test, and keep real files from real encoders in the suite. Build any stream that stops without its terminator so its last code ends on a byte boundary, and assert the length.

**Takeaway**: **An encoder and decoder written together agree with each other, not with the format: anchor one of them to an independent implementation, and build truncated streams that end where you think they do.**
