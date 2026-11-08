# Debugging: Nesting depth is input, not a stack budget

**Date**: 2026-11-08
**Lesson**: A parser step that recurses once per nesting level hands the page the depth of Crane's native stack; consume nested blocks over an explicit stack (or a bounded, spec-backed limit) instead.

**Why**: CSS Syntax 3 5.5.9 "consume a simple block" sets no depth limit, and a page controls the depth: `'('.repeat(60000)` is one line of script. One native frame per level overflows the stack at a depth any page can reach, and the crash takes the whole process (the WPT runner reports SIGABRT / SIGSEGV, not a failing test).

**What Happened**: Lane anim1 batch 5's base probe found css/css-syntax/crashtests/unclosed-open-brackets.html (crbug 41343497) crashing on main: a style attribute of `content: ` and 60,000 `(`. rules.zig's consumeComponentValue/collectComponentValue recursed per level (19,993 frames in the trace before the guard page), and import_rules.zig's @import pre-scan had the same shape. Crashtests are not in the worklist, so no sweep had shown it.

**Fix**: One iterative consumer (rules.zig consumeBlockRest) over a stack of the closing tokens still expected - 64 inline, the rest on the heap - shared by consumeComponentValue, collectComponentValue and skipBlock; the same shape in import_rules.zig. Only the expected closer pops (a `]` inside `( )` is an ordinary token), as Blink's CSSTokenizer block_stack_ and Gecko cssparser's consume_until_end_of_block do. Tests at a depth that crashed (300,000) plus allocation failure past the inline 64. The semantic recursions, probed with the fixed runner at 100 / 1,000 / 10,000 / 60,000 levels: calc() (calculation_max_depth 128; Blink's kMaxExpressionDepth is 100), @media (max_nesting 128), @supports (a fixed closer array) and var() fallback chains (substitution max_depth 128) do not crash; :is() selector nesting crashes at 10,000 (not 1,000) and CSS nesting rules at 1,000 (not 100) - both recursive descents with no limit, queued for their owners (Gecko's cssparser stops every nested parse at 75 blocks, TooManyNestedBlocks).

**Takeaway**: **Treat nesting depth as untrusted input: anything that recurses per level needs an explicit stack or a limit the browsers share, and a crashtest at 60,000 levels is the check.**
