# Testing: A Shared Service Can Restart Between Measurements

**Date**: 2026-10-29
**Lesson**: A source-identical build does not guarantee that a shared test service still has the same process identity.

**Why**: Host maintenance can replace a service while preserving its address, executable and working directory. A guard should reject the stale identity, and its recovery should establish why the replacement is legitimate.

**What Happened**: A CSS Typed OM comparison passed its source, input and frozen-runner checks, then stopped before executing any WPT because the pinned shared server PID had disappeared. Crane's remote build helper had restarted the server when another build released its slot: the server had exceeded 300 threads and no runner token was held. The host's crane-waits.log recorded the idle restart. Neither the lane nor another operator had manually changed the server.

**Fix**: Preserve the failed preflight and prove whether any runner observation occurred. Check the host's restart log before treating the identity change as unexplained. Under the integrator's standing rule, a matching idle-restart entry permits a fresh identity pin; an unexplained change still requires a question. Capture the full listener and process tables, parent chain, exact command, full start timestamp and working directory. Test wrong PID, parent, timestamp, command, directory and foreign ports. Use new guard copies and a fresh attempt directory, retaining the original rejected evidence. Keep every input, endpoint and observation rule unchanged.

**Takeaway**: **Re-establish a shared service's identity from evidence; never turn a stale identity failure into a broad allowlist or a fabricated resume.**
