# Debugging: Profile the WPT Worker, Not Its Supervisor

**Date**: 2026-10-23
**Lesson**: A WPT runner started with `--parallel=1` is still a supervisor; profile its actual test worker.

**Why**: Capturing the PID that executes `wpt_runner` does not prove that the sampled process runs JavaScript. The supervisor waits for a child process even with a parallelism of one.

**What Happened**: Four initial cost-attribution profiles captured `main.supervise` and `wait4`. They contained no measured selector or form work and could not support a claim about cascade cost. These invalid captures were retained and explicitly excluded from the diagnosis.

**Fix**: Read `tests/wpt_runner/options.zig` and `main.zig`'s worker-spawn path. Capture the owned supervisor PID, find only its direct `wpt_runner` child, and record the child's PID, parent PID and command before sampling. The corrected profiles contained the intended selector and form calls. Combine sampling with the inspected call graph: missing or inlined frames limit what an absent sample proves. Keep attribution separate from timed acceptance, and never use it to waive a failed performance bar without the integrator's ruling.

**Takeaway**: **Verify that a profile contains the work being measured before interpreting absent frames.**
