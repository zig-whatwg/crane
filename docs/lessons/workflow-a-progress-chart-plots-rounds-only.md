# Workflow: A progress chart plots rounds only, against the subject's own first round

**Date**: 2026-11-07
**Lesson**: To show whether something is getting better, draw one line per measure - its figure as a share of its own first round, one point per measurement round, each labelled with its value - and put the comparison with others in a table (one column per round, coloured by the change) and any methodology control in a footnote.

**Why**: A reader comes to a progress chart with one question ("is Crane getting faster?"). Every extra line is another answer to read; a ratio against someone else (Crane's time as a % of Chrome's) hides the direction (lower is better, and nothing says so); and a control drawn as a point (a rebuild of an old source for a new CPU target, measured to show the target alone changed nothing) reads as a round that happened.

**What Happened**: Lane perfr1 published /performance/'s Progress section (2026-11-06) as one line per browser - Crane's time as a percentage of that browser's on a log axis (800%, 400%) - over three points: "Round 0 (native)", "Round 0's source (apple_m1)" (hollow, reached by a dashed "CPU target" step, with a vertical dashed mark) and "Round 1", plus a table. The user, 2026-11-07 02:11 UTC: "this graph is confusing for tracking Crane's progress". Lane perfpage replaced it (tools/perf_bench report.zig `progress`, `writeProgress`; chart.zig `trendChart`):
- "Crane over time" first: two small charts, time and memory, ONE line each, Crane's geometric mean as a share of its round 0 on a linear axis from 0 (100% the reference line), x labels round/date/commit, every point labelled (100%, 81%), "lower is better" in each title;
- the CPU target as one sentence: re-measuring round 0's source for it changed time by 0.991x and memory by 1.010x, within noise;
- "The gap to the browsers" as a table: "5.97x" per browser per round beside the round before, green lower, red higher, uncoloured inside the drift control's 5% limit (a first draft also wrote "(was 7.36x)" in each cell; the integrator cut it: the previous column sits beside it);
- per-workload sparklines over rounds only, their scale at least the 10% noise band either side, so a 1% move no longer draws as a full swing.
The user, shown the candidate (02:41 UTC): "keep it" - charts Crane-only, the browsers in the table, no browser lines.

**Fix**:
1. One question per chart; one line per measure. The subject against its own first round answers "getting better?"; the gap to others is a second question, and a table answers it.
2. Points are measurement rounds. A control (drift control, a rebuild for a new target) is a sentence beside the chart, with its numbers and whether they are within noise.
3. Say the direction in the title ("lower is better") and label the values; the HTML carries every number too.
4. A change smaller than the noise the method accepts is not coloured, and a sparkline's scale spans at least that noise.

**Takeaway**: **A progress chart answers one question: one line per measure against its own first round, rounds only; comparisons go in a table and controls in a footnote.**
