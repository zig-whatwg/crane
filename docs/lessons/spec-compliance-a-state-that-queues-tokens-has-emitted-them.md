# Spec Compliance: A state that queues tokens has emitted them

**Date**: 2026-09-27
**Lesson**: Characters a tokenizer state queues and returns nothing for are emitted at that point; drain the queue before the next state runs.

**Why**: The HTML tokenizer's character reference states "flush code points consumed as a character reference": those characters are emitted then, before anything the next state reads. An implementation that queues them and returns no token from that step has to hand the queue out before it runs another state, or the next token overtakes them.

**What Happened**: Crane's tokenizer queued the flushed characters and went straight on to the return state. The next character token was returned first, so "a && b" came out as "a  b&&" - in script text (Crane test crane/script-svg failed with "Unexpected identifier 'document'") and in ordinary HTML text alike. A "&" at the very end of the input was never returned at all, because nothing drained the queue at end of file.

**Fix**: 598b0ac73 drains queued characters before dispatching the next state, and at end of file. Tests: tests/html/parser_tree_construction_test.zig and the Crane test crane/parser-character-reference-flush (0 -> 5 of 5 cases).

**Takeaway**: **A token queued is a token emitted: the queue drains before the next state runs and before end of file, or order and text are lost.**
