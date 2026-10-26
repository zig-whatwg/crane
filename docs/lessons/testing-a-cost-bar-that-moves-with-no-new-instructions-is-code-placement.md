# Testing: A cost bar that moves with no new instructions is code placement

**Date**: 2026-10-25
**Lesson**: When a per-operation page metric fails a time bar and its call path reaches no changed code, count instructions retired (the page minus a zero-iteration control) before profiling or redesigning: within 0.5% means no new work.

**Why**: The WPT runner is one whole-program ReleaseSafe compilation (AGENTS.md, "The WPT runner is built optimized"). Any edit anywhere can move the hot loop of an unrelated operation to a different address and alignment. A loop costing about 250 ns per iteration then gains or loses several percent with no new code executed. The multi-page cost series also runs each page after others in the same process, so heap and JIT state shift with the order as well. A time bar alone cannot tell this apart from real work.

**What Happened**: Lane vars1's timed series (pooled 14, BASE main b6b92efd3de vs TIP 540dcbc4e8c) passed 16 of 17 page metrics and failed one, form_input_value: +5.63% ratio / +5.65% paired, 25.75 -> 27.20 ms per 100,000 `input.value` writes, in both series. The read-only call path showed the setter (HTMLInputElement.set_value -> valueIn, sanitize, setValue, font_loading.controlValueChanged returning at its first line because the page reads no style) touching none of the lane's changed files. Its neighbours on the same page (textarea_value, input_range, textarea_range) all passed. Then 7 alternating pairs under `/usr/bin/time -l` around the in-process runner:
- a 1,000,000-write page: instructions -0.11% ratio / -0.29% paired;
- the loop alone, that page minus a 0-write control: 7,852 -> 7,830 instructions per write (-0.28%);
- the unchanged cr1-form-value-cost page: instructions +0.045% / +0.49%, and its CR1_FORM_INPUT_VALUE_MS was 28.3 -> 27.6 ms (-2.47%) when it ran alone.

The same two binaries gave +5.6% in the series and -2.5% alone. BASE's cr1-form-value-cost total (37.55e9 instructions) sits within 0.2% of what row 118's Q131 measured on its own BASE (37.49e9). The integrator's rule accepted the result as placement. input.value had moved without explanation before (rows 117 and 118, 2026-10-23).

**Fix**:
1. Read the failing metric's call path first. If it reaches no changed function, say so with the path.
2. Write a scratch page with the operation alone, many iterations (here 1,000,000), plus a control page with the same setup and zero iterations.
3. Run BASE and TIP in-process (no `--parallel`) under `/usr/bin/time -l`, 7 alternating pairs per page. Compare the median instructions retired of page minus control.
4. Within 0.5%: no new work, so record the time movement as placement. Above 0.5%: profile both sides (`sample`) and attribute the extra.

**Takeaway**: **A sub-microsecond per-operation metric in a whole-program optimized runner moves with code placement. When its path reaches no changed code, instructions retired (page minus a zero-iteration control) decide, not time.**
