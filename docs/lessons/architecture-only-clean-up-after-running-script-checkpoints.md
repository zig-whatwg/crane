# Architecture: Only "clean up after running script" checkpoints

**Date**: 2026-09-27
**Lesson**: The microtask checkpoint after script belongs to HTML's "clean up after running script", which performs it only when the JavaScript execution context stack is empty - never unconditionally after each executed script.

**Why**: A script can insert another script that executes synchronously, from inside the first. HTML runs the checkpoint in "clean up after running script", and only once the execution context stack is empty (recipe R10), so the inner script's end runs no microtasks while the outer script is still on the stack.

**What Happened**: Crane ran an engine microtask checkpoint after every executed script. A nested script's end ran microtasks in the middle of the script that had inserted it (Crane test crane/script-nested-microtask-checkpoint, 0 of 3 cases). WPT's script-for-event and microtasks/evaluation-order-1 moved with the fix.

**Fix**: 7423457f9 (R31, classic scripts through engine.runClassicScript) drops the unconditional checkpoint; the realm's clean-up is the only place that checkpoints.

**Takeaway**: **A checkpoint needs the spec's condition (an empty execution context stack), not a call site; one after every script is one inside some other script.**
