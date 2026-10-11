# Debugging: A pull inflater needs short-input and block-transition tests

**Date**: 2026-10-10
**Lesson**: A successful whole-buffer round trip does not establish that a pull inflater can safely decode arbitrary stream chunks.

**Why**: The source reader, inflater bit buffer, history window and destination limit each carry state. A short read can interrupt an operation after it has changed several of them; a block transition can produce more output than the caller's remaining limit.

**What Happened**: Compression Streams uses Zig 0.16's `std.compress.flate` raw inflater. An externally encoded dynamic-Huffman stream, split inside its table, reached a `tossBitsShort` assertion: its short-input check adds `consumed_bits` instead of subtracting it. After that was addressed, a compressed block followed by a stored block reached `Reader.stream`'s output-limit assertion: `streamInner` used the original limit for the stored block after already producing compressed output. Whole-buffer examples did not expose either failure. The native codec suite recorded both panics, then passed all eleven tests with the adapter corrections.

**Fix**: Keep bounded decode checkpoints, including input position and the inflater's bit and history state. Supply bounded zero lookahead but commit only steps whose consumed bits are within real input; short input suspends without treating padding as data. Account for the inflater's maximum output across the compressed-to-stored transition, and use the actual destination position. Validate headers, checksums, truncation and trailing bytes separately. Test every split of external compressed vectors, bytewise dynamic-Huffman input, every truncated prefix, and mixed compressed/stored blocks.

**Takeaway**: **Test a streaming adapter at interrupted operations and block transitions, using externally produced data. A self round trip is not enough.**
