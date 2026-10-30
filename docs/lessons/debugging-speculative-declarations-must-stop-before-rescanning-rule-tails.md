# Debugging: Speculative Declarations Must Stop Before Rescanning Rule Tails

**Date**: 2026-10-29
**Lesson**: A parser that rewinds after a failed declaration must reject an impossible declaration before scanning the rest of its enclosing block.

**Why**: An ident-led nested rule can initially look like a declaration. Collecting all component values before checking its colon or block restrictions scans the remaining sibling rules again for each attempt, making an otherwise linear group body quadratic.

**What Happened**: Row 127's group-body parser produced the expected rule trees but repeatedly scanned their tails. At frozen tip 31a9e02739d, doubling 64 rules to 128 used 4.31–4.53 times the allocated bytes. One untimed, same-host stylesheet observation at 1,000 and 2,000 mixed ident-led rules took 785.900 and 3049.700 ms (3.880519 times). Correct output alone did not reveal the cost.

**Fix**: Apply CSS Syntax 3 §5.5.6 steps 1–3 immediately: consume the ident and whitespace, then return null if no colon follows. Apply step 8 while collecting top-level components: a non-custom value with a brace block beside another value cannot be a declaration, except for trailing `!important`. Preserve custom properties, `@property initial-value`, and existing final validation. Both callers restore their stream mark on null. Blink's [ConsumeDeclaration at 97f9cf6fa75f](https://github.com/chromium/chromium/blob/97f9cf6fa75f/third_party/blink/renderer/core/css/parser/css_parser_impl.cc) documents the same speculative-call contract and rejects a missing colon immediately; the implementation here uses Crane's own tokenizer and ownership.

Pin deterministic allocation growth without native timing loops, compare grouped rule trees with independently parsed children, and preserve a separate stylesheet fixture for the one-shot scaling observation.

**Takeaway**: **When a caller will rewind, stop speculative parsing as soon as failure is certain; measure scaling as well as correctness.**
