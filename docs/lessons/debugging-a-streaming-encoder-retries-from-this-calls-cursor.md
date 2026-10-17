# Debugging: A streaming encoder retries from this call's cursor

**Date**: 2026-10-16
**Lesson**: Save the current input position and carried surrogate before forming a scalar; a previous call's input cannot be recovered by indexing backward in this call.

**Why**: A UTF-16 scalar may begin with a high surrogate carried from an earlier chunk. Its low surrogate consumes one unit here, while an invalid low surrogate consumes none. Subtracting one or two from a single cursor cannot represent both cases.

**What Happened**: Six legacy streaming encoders restored a high surrogate from `input[in_pos - 1]` after backing up on output-full. A high surrogate in one call and a low surrogate with a short output in the next caused an integer-underflow panic. A carried high followed by an ordinary character could underflow on an unmappable result or repeat a preceding character. EOF error paths also retained the failed high surrogate and reported it repeatedly. ISO-2022-JP had the latter error paths despite already checkpointing output-full correctly.

**Fix**: Checkpoint the current cursor and pending surrogate before processing each input item. Restore both when output cannot fit. Report an unmappable result at the current item's start, without subtracting from a cursor that may not have advanced. Consume a final lone-surrogate error once. In ISO-2022-JP's JIS state, emit the required ASCII designation before the error, and retry that designation without consuming pending input if output is full. Return the handler's `error_code_point` from `encodeOrFail`; reconstructing it from a UTF-16 cursor loses supplementary scalars. Native tests cover split pairs, capacities zero through three, non-low input, valid prefixes, and repeated EOF in ASCII, JIS and Roman states.

**Takeaway**: **Checkpoint input and state together; error position, input consumption, and output capacity are different facts.**
