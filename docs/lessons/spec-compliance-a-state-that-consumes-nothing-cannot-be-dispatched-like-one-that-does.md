# Spec Compliance: A state that consumes nothing cannot be dispatched like one that does

**Date**: 2026-09-27
**Lesson**: In a consume-then-dispatch tokenizer loop, a state whose steps consume no input must run inline, or the loop eats a character on its behalf.

**Why**: Most HTML tokenizer states begin "consume the next input character". A few, such as the numeric character reference end state, do not: they act on what is already known and switch state. A loop that consumes one character and then dispatches on the current state consumes a character for those states too.

**What Happened**: The numeric character reference end state was dispatched through the common loop, which consumed and dropped the character after every numeric reference: "&#65;x" read "A".

**Fix**: b4fbd8892 runs the end state's steps inline when the numeric reference completes, so the next character is the return state's.

**Takeaway**: **Check each state's first step: one that does not consume must not be reached through a loop that consumes for it.**
