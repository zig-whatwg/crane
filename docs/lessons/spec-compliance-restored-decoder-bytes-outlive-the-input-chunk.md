# Spec Compliance: Restored decoder bytes outlive the input chunk

**Date**: 2026-10-16
**Lesson**: A streaming decoder must retain restored bytes from earlier chunks and retry output from the state before the scalar was decoded.

**Why**: The Encoding Standard's input queue can prepend bytes that a slice API already reported as consumed. Backing up the current slice cannot restore a byte from an earlier write, and saving the handler's state after an output-full result loses the lead that produced the unwritten scalar.

**What Happened**: The legacy Big5, EUC-JP, EUC-KR and gb18030 wrappers inserted replacement characters themselves. Fatal callers never saw errors, ASCII trails disappeared, and output-full retries lost pending leads. gb18030's `81 30 81 2B` must produce `�0�+`, including when each byte arrives in a different write. Big5 can return two scalars for one pair; the second still needs draining when the input slice is empty.

**Fix**: Return the malformed result to the caller, which chooses fatal or replacement mode. Leave an ASCII trail unread. For gb18030's restored second and third bytes, keep the ASCII digit by value and retain the third byte as the next lead; emit the digit before processing that lead. This follows the compact state design in [encoding_rs](https://github.com/hsivonen/encoding_rs/blob/master/src/gb18030.rs), without retaining an input pointer. Before decoding a scalar, checkpoint the whole handler state and restore it if the output cannot fit. Drain Big5's pending scalar before consuming another byte or reporting end of input. Test every input split, both output encodings, EOF, and output capacities starting at zero, including valid prefixes before malformed input.

**Takeaway**: **Input consumption and output capacity are separate boundaries. Preserve both the restored queue prefix and the state needed to retry unwritten output.**
