# Testing: A browser probe does not cover an extra mixed state

**Date**: 2026-10-31
**Lesson**: Keep a characterization assertion within the states actually covered by its browser evidence.

**Why**: A shared helper can add an apparently natural follow-up assertion whose behavior was never probed.

**What Happened**: The system-font probe covered four sequences in which all seven font-variant longhands remained pending. Its native test additionally set font-variant-caps and expected the shorthand to stay empty. That mixed state was outside the probe. CSS Fonts' `font-variant-serialization.html` instead checks a system font followed by an explicit numeric variant; Chrome, Firefox and Safari all serialize the explicit member. Row131's conforming mixed-state change consequently failed four copies of the unsupported characterization assertion.

**Fix**: Preserve the all-pending probe assertions and cssText checks. Correct only the mixed-state expectation, with its distinct browser evidence, and rerun both the old controls and the new case. A characterization's provenance is part of reviewing a changed expected value.

**Takeaway**: **A probe establishes the states it exercised; an additional state needs its own evidence.**
