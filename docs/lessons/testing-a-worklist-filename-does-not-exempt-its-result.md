# Testing: A Worklist Filename Does Not Exempt Its Result

**Date**: 2026-10-29
**Lesson**: Determine gate membership from the actual worklist and explicit exemptions, not a filename suffix.

**Why**: A test named optional can still be deliberately included in a project’s acceptance worklist. Its harness finishing successfully does not imply that any of its assertions passed.

**What Happened**: Two select tests were correctly routed to the navigation and input owners, but the routing answer also said their .optional suffix meant they never blocked. Both were literal entries in the frozen worklist and fixed comparison lists. The measured records were OK with zero passing subtests, so Crane’s gate classified both as NONE-PASSED. Neither had an explicit exemption. The liaison and integrator corrected the counting statement; their implementation owners stayed the same.

**Fix**: Check the exact frozen worklist, the gate-status implementation, the measured record and the exemption file. Keep every listed test in fixed comparisons and ordinary blocking counts unless an explicit authorized disposition says otherwise. Treat routing and acceptance status as separate questions, and preserve earlier raw results.

**Takeaway**: **An area’s owner and a test’s filename do not change whether its measured worklist result blocks.**
