# Testing: A per-op cost that subtracts a control inherits the control's noise

**Date**: 2026-11-11
**Lesson**: "Instructions per resolution above the control page" divides (bench - control) by the operation count, so the control's run-to-run spread lands on every bench whole. Between two identical binaries the control's median moved 0.35%, which is 400 instructions per resolution, more than the 0.3% a 1.03 bar has to tell apart. Measure the control on every console, drop its cold first run, and subtract one common control (the mean of the consoles' medians) whenever the consoles run the control's code identically.

**Why**: The control (`b=none`: the page builds its rows and reads no style) is about 45% of a bench's instructions. Its first run per console is a cold outlier (2.295 G against 2.228 G for the next four), and even the medians of five vary by +-5 M between copies of one binary. Subtracting each console's own control turns that +-5 M into +-250 instructions per resolution at 20,000 resolutions per run, on a measured difference of 3-5 K.

**What Happened**: Lane style1 batch 4 measured base eb7ee8bd7ae, a byte-identical copy of it and the tip on chat2, five runs each. With each console's own control, base and copy differed by 570 / 505 / 443 instructions per resolution on gcsInline / gcsMiss / gcsFull (0.3-0.4%), and the tip read 1.029 against the base but 1.033 against the copy: one bench was on both sides of the 1.03 bar at once. With one common control (the mean of the three medians), base and copy differed by 0.06-0.21%, and the tip read 1.031 / 1.032 / 1.035. The benches themselves vary much less (sd 2-9 M on 5-7 G).

**Fix**:
1. Always run a base-versus-base copy (two directories, one binary) in the same series: its difference is the noise floor of that series.
2. Read the raw runs. Discard a first run that is a cold outlier, or run one warm-up.
3. When the control runs no code the change touched (here: no style is resolved), subtract one common control from every console. Report which control was used.
4. Raise the run count before reading a difference under twice the base-versus-copy spread.

**Takeaway**: **A per-operation number is only as quiet as the control it subtracts: put a copy of the base in every series, and subtract a common control when the control does not run the changed code.**
