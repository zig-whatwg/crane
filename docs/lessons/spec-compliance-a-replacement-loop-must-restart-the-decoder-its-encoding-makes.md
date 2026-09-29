# Spec Compliance: A replacement loop must restart the decoder its encoding makes

**Date**: 2026-09-29
**Lesson**: After an error, a "replacement" error-mode loop that resets a decoder must reset it to the state `Encoding.newDecoder()` builds, never to `.neutral`: a single-byte decoder's state carries its index, and a neutral one decodes nothing.

**Why**: `DecoderState` is a union, and each encoding's initial state is chosen by `newDecoder()`: `.single_byte = .{ .index = ... }` for the single-byte family, `.neutral` for the rest. `Decoder.decodeReplacement` (src/encoding/encoding.zig) writes `self.state = .neutral` after every `.malformed` result. The single-byte decoder treats any state but `.single_byte` as invalid and returns `.input_empty` with nothing consumed, and `decodeReplacement` passes that `.input_empty` on. The decode ends at the first unmapped byte, silently, with the rest of the input dropped.

**What Happened**: Found while writing the document decoder for HTML's "determining the character encoding" (`html_core.parser.encoding_sniffing.decode`). It needed the Encoding Standard's "decode" to UTF-8, and `hooks.decode` - which calls `decodeReplacement` - looked like the obvious call. Reading the loop showed the reset. Only UTF-8 and the single-byte decoders report `.malformed` (the multi-byte ones substitute U+FFFD themselves), and UTF-8's initial state is `.neutral`, so UTF-8 input never shows it; windows-1253, ISO-8859-3 and the others with unmapped bytes do. `hooks.decode` serves `FileReader.readAsText` and `XMLHttpRequest`'s text decoding, so a Blob or a response in such an encoding loses everything after its first unmapped byte. TextDecoder has its own loop, which resets with `newDecoder()`, and is not affected - which is why `textdecoder-fatal-single-byte.any.js` passes.

**Fix**: The document decoder resets with `encoding.newDecoder()`, as TextDecoder does, and `tests/html/encoding_sniffing_test.zig` pins it ("a\xAAb\xAAc" in windows-1253 is "a\u{FFFD}b\u{FFFD}c"). `decodeReplacement` itself is src/encoding's and was reported, not changed: it should take the decoder's encoding's `newDecoder()` state too.

**Takeaway**: **A decoder's "initial state" belongs to its encoding: reset through `newDecoder()`, and test an error loop with a single-byte encoding that has unmapped bytes, not with UTF-8.**
