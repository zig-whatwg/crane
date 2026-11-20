# Spec Compliance: A fast path that advances the input must clear the state the slow path keeps

**Date**: 2026-11-19
**Lesson**: A batch that moves the tokenizer's input position past characters itself must also do what consuming those characters one by one would have done to the input stream's state - here, forget a preceding CR.

**Why**: HTML 13.2.3.5 normalizes newlines in the input stream: a CR becomes an LF, and an LF right after a CR is dropped. Crane's InputStream keeps that pairing in `last_was_cr`, which `consume` sets on a CR and clears on every other character. The tokenizer's attribute-value batch (`batchAppendAttributeValue`) appends a run of plain ASCII and writes `input.position` directly - so `last_was_cr` survived the run, and the next LF was taken for the second half of a CR LF pair.

**What Happened**: `<input value='before\rABCDEF\nafter'>` gave `before\nABCDEFafter` (html/syntax/parsing/newline-normalization-cr-then-lf.html, Chrome, Firefox and Safari PASS). Text content passed: the text batch refuses to start on a newline character, so the CR's LF had already been consumed by the slow path, which cleared the flag. The attribute batch starts on any ASCII current character, the LF a CR became included.

**Fix**: after the batch advances the position over a non-empty run, `self.input.last_was_cr = false` (lane maj3, tests/html/maj3_parser_namespace_scope_test.zig "a CR in an attribute value is a newline...").

**Takeaway**: **When a fast path skips the per-item routine, list every piece of state that routine updates (position, line, column, pairing flags) and update each one in the fast path too - or refuse the fast path where that state is live.**
