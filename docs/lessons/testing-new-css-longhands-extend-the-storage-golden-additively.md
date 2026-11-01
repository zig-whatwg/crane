# Testing: New CSS longhands extend the storage golden additively

**Date**: 2026-10-31
**Lesson**: Registering a CSS longhand also extends the storage characterization fixture; preserve every existing expected line when adding the new values.

**Why**: `tests/css/cascadefast2_storage_cases.zig` renders every longhand's initial resolved value before rendering its cascade cases. The fixture characterizes the earlier flat storage implementation, so replacing it wholesale with current output could hide a regression in an existing property.

**What Happened**: The fragmentation property's focused native tests passed, but the full CSS suite failed at golden line 327: the renderer produced `break-before: auto` where the old fixture started its first case. Six newly registered longhands had extended the initial block. Their grammar and computation were not the cause of this mismatch.

**Fix**: Under liaison grant Q25 for row 131, add the six spec-defined initial entries at the renderer's position. Require a fixture diff with zero deleted lines, leave the renderer and equality test unchanged, and rerun the full native gate on that exact tree. Each subsequent property family adds only its own new entries. A changed expected value for an existing property requires diagnosis and a separate ruling.

**Takeaway**: **Extend the characterization for new properties without replacing the evidence for existing ones.**
