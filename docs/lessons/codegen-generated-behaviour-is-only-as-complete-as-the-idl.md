# Codegen: Generated behaviour is only as complete as the IDL

**Date**: 2026-09-26
**Lesson**: `input.size` carries `[Reflect]` in the IDL, but HTML's prose makes it "limited to only positive numbers with fallback" with a default of 20 - which the extended attribute does not say.

**Why**: Some reflection rules still live only in prose, and generated reflection implements what the IDL states.

**What Happened**: Deleting the hand-written accessor in favour of generated reflection would have lost the default; the lane kept it (lane/reflection).

**Fix**: Before deleting a reflected accessor, grep the prose for "limited to" and "default value".

**Takeaway**: **Before trusting generated behaviour, read the prose the IDL summarises.**
