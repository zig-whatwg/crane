# Spec Compliance: A decoder error can restore input and retain state

**Date**: 2026-10-10
**Lesson**: A replacement-mode caller must use the decoder handler's exact error extent and resulting state, including an extent of zero.

**Why**: Encoding handlers specify their own recovery. Shift_JIS restores an invalid ASCII trail byte. UTF-16 restores a code unit after an unmatched high surrogate. ISO-2022-JP restores up to two bytes after an invalid escape and resumes its previous output state. A caller cannot substitute a generic “skip one byte and reset” rule.

**What Happened**: Converting the UTF-16 and Japanese handlers to report errors exposed existing replacement loops that forced a zero error extent to one and reset the decoder. A split malformed UTF-8 sequence lost its following ASCII character; the parser lost both restored ISO-2022-JP escape bytes and its Roman state. Native tests recorded these failures before the caller changes. A small output-buffer test then found that rolling back an entire decode call when U+FFFD did not fit could retry the same valid prefix forever.

**Fix**: Let handlers perform their specified recovery and let one shared replacement loop append U+FFFD. Consume exactly the reported extent. Guard a true lack of progress by comparing input, output and handler state. If replacement output does not fit, retain preceding output and reconstruct the state at that prefix, leaving the error for the next call. Run end-of-queue even on an empty final call; shortcuts must respect pending input and BOM serialization state.

**Takeaway**: **Error recovery is part of a state machine's contract. Restored input and retained state must cross the caller boundary together.**
