# Architecture: A nesting limit does not bound a left-associative chain

**Date**: 2026-10-15
**Lesson**: A recursive-descent parser's depth limit bounds nesting, not the height of the tree its operator loop builds; evaluate a left-associative chain by folding its left spine iteratively.

**Why**: Precedence climbing parses `a + b + c + ...` in a loop at ONE nesting level, building `((a + b) + c) + ...`: a left-deep tree as high as the chain is long. A depth counter in `expression()` sees depth 1 however long the chain is, so it bounds nothing an evaluator that recurses on `left` will do.

**What Happened**: The XPath engine (Codex row 37) capped parser nesting at 256 and called itself safe. Review M1 found that `document.evaluate('1' + '+1'.repeat(200000), document)` - a 400 KB string any page can build - made `Evaluation.evaluate` recurse 200,000 frames deep on `binary.left` and killed the process with SIGSEGV. `and`/`or` chains and `|` chains did the same. Unary minus, parentheses, predicates and arguments all went through `expression()` and were capped; only the operator loop escaped it.

**Fix**: `Evaluation.operators` walks the left spine into a list, evaluates the leftmost operand, then folds upward, innermost first, evaluating each node's `right`. Right operands come from `expression(prec + 1)`, one nesting level deeper, so recursion through them stays within the parser's limit. Keep `and`/`or` short-circuiting per node, and merge a run of `|` operands into one set ordered once. Do NOT cap chain length in the parser instead: parentheses multiply it (256 nested levels of 1,000-term chains are still 256,000 levels high). The grammar arena frees the tree without walking it, so teardown never recursed. Tests: a 200,000-term chain in `tests/dom/xpath_api_test.zig`; `crane/xp2-deep-chain.html` (+, -, mixed precedence, and/or with short-circuit, |).

**Takeaway**: **Bound recursion by the height of the tree you walk, not by the parser's nesting depth - any left-associative operator loop builds a tree as high as its input is long.**
