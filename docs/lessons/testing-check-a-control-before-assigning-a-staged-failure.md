# Testing: Check a control before assigning a staged failure

**Date**: 2026-10-23
**Lesson**: Unchanged failures in one feature fixture can depend on different missing integration layers.

**Why**: A script test may check a positive control before it reaches the new behavior. The fixture title does not identify the layer that failed.

**What Happened**: The SVG presentation parser passed its native gate while its script fixture kept eight failures on both frozen runners. Seven needed the presentation-hint consumer. The overflow case instead failed on a nested SVG element with no attribute: it expected hidden but read visible because Crane loaded only HTML UA rules.

**Fix**: Read each first failed assertion and its control, compare exact BASE/TIP outcomes, and trace the corresponding owner path. Q132 split the missing hint consumer from the missing SVG UA stylesheet and routed the latter separately. Both the control and the parser tests stayed unchanged.

**Takeaway**: **Attribute a failure from its first broken precondition, and keep independent prerequisites separate.**
