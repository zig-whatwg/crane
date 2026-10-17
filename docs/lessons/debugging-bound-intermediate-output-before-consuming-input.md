# Debugging: Bound intermediate output before consuming input

**Date**: 2026-10-16
**Lesson**: A decoder that converts through an intermediate buffer must reserve the final output's worst-case expansion before advancing input or state.

**Why**: A UTF-16 chunk and its UTF-8 serialization have different lengths. Discovering that UTF-8 output is full after decoding the chunk leaves the input cursor behind the decoder's state. Treating UTF-16 units individually also turns one supplementary scalar into invalid surrogate encodings.

**What Happened**: The generic UTF-8 fallback advanced its decoder through a 256-unit chunk, then returned an old byte count when conversion did not fit. It skipped empty EOF calls and wrote surrogate halves separately. Tests at the chunk boundary exposed another defect: the UTF-8 decoder retained a complete scalar under its `bytes_needed == 0xFF` marker when only one UTF-16 slot remained, but never drained it. This also lost characters in document decoding through a 4096-unit buffer.

**Fix**: Bound the intermediate chunk to at most one UTF-16 unit per three available UTF-8 bytes. Convert complete scalars from native numeric UTF-16 units, independently of host byte order, call the handler on empty final input, and return output-full if the bounded chunk cannot make progress. This conservative fallback may require six available bytes for a supplementary scalar. The handlers emit surrogate pairs atomically; their existing state retains a scalar that does not fit. At UTF-8 decoder entry, drain the pending scalar before new input or EOF, and append any ASCII prefix after it. Pin every input split, a scalar after 255 units, empty flush, zero/tiny output, and repeated short-buffer retries. A document fixture puts the scalar after 4095 ASCII units and includes an invalid byte to force replacement decoding instead of the valid-UTF-8 shortcut.

**Takeaway**: **Input boundaries, intermediate-unit boundaries, and final-byte boundaries are independent. Exercise all three, including the empty call that drains pending output.**
