# Spec compliance: A unit-test pin that breaks does not decide who is right

**Date**: 2026-11-21
**Lesson**: When a change gains WPT rows but breaks another lane's unit-test pin, the pin is one reading of the question, not the answer. Before reverting either side, find out what the spec says and what Chrome, Firefox and Safari do for the exact value the pin asserts, and record it.

**Why**: A pin records what its author decided, and the author may have followed the spec's more cautious reading, or one browser, with no probe at all. Reverting because a pin broke can throw away the majority behaviour and leave the wrong side in the tree with nothing written down, so the next lane rediscovers the conflict and makes the same call.

**What Happened**: Lane maj6 made mod() and rem() of percentages alone simplify at computed-value time (44891f640: computed `mod(18%, 5%)` = `3%`, specified kept). That gained the two css/css-values/round-mod-rem-computed.html rows. The change broke lane cv1's pin in tests/css/cv1_math_functions_test.zig, which expects `mod(10%, 3%)` unsimplified at both stages, so maj6 reverted it as "not worth contradicting that pin for 2 rows". The integrator asked which side the spec and the browsers take. A probe (tmp/plans/maj6-evidence/mod-percent-probe.txt) gave these computed values:

| Browser | Computed `mod(10%, 3%)` |
|---|---|
| Chrome 157 | `1%` |
| Firefox 159 | `1%` |
| Safari 27.0 | `mod(10%, 3%)` |

For the specified value, Chrome and Safari keep the function and Firefox gives `calc(1%)`. So the reverted change was the majority on both stages (it was Chrome exactly), and the pin's computed half follows Safari alone. The spec leaves the question open: css-values-4 simplification step 4 says a leftover percentage "usually" blocks simplification, and mod() and rem() are linear in the percentage's basis.

**Fix**: When a pin breaks, probe the three browsers on the asserted value. Chrome headless `--dump-dom` works; Firefox headless with `browser.dom.window.dump.enabled` and `dump()` works; Safari works through `open -g -j` with the page sending its result by GET to a local server, and its tab closed afterwards. Read the spec section whole. Then fix whichever side golden rule 2 says is wrong, citing the probe: change the pin, or change the code. If the batch has no room, record the verdict and the fix in the handoff as the next item.

**Takeaway**: **A broken pin is a question, not a verdict: probe the browsers on the pinned value before reverting, and fix the side golden rule 2 says is wrong.**
