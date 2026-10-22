# Testing: New Formats Need a Runner-Only Comparison

**Date**: 2026-10-21
**Lesson**: When enabling a test format, preserve a runner-only build before changing the engine behavior it exposes.

**Why**: An unsupported format gives the original baseline zero passing subtests. Comparing only against that baseline cannot reveal a pass lost during implementation.

**What Happened**: Enabling XML-format WPT files first produced 4,576 passes. Subsequent SVG interface selection gained 32 but lost two: assigning `use.style` reached an unimplemented accessor, and evaluating `createSVGRect()` threw before a null-argument check. The original baseline rejected both files, so a comparison with it alone showed no loss.

**Fix**: Keep the original baseline for the required full comparison and a frozen runner-only intermediate for the newly executable formats. Compare individual subtests against both, audit detail counts against each journal, and investigate every lost pass before handoff.

**Takeaway**: **A baseline that cannot execute a test cannot detect regressions within that test.**
