# Testing: A WPT root does not select a shared server's inputs

**Date**: 2026-10-28
**Lesson**: Verify the bytes served by the existing WPT server, not only the directory passed to the runner.

**Why**: The runner uses --wpt-root for discovery and to find a server lockfile. WptServer.checkExistingServer adopts a listener by probing its port. That does not make the listener serve the selected directory. A second root without a lockfile can start a server that fails to bind while the readiness probe succeeds against the original listener.

**What Happened**: While preparing the CSS parsing lane's final comparisons, a private immutable WPT copy looked like a way to isolate test inputs from main's syncs. The integrator's liaison checked the actual listener: all chat runs used one long-lived server whose cwd was the shared main WPT mirror. Passing a copy as --wpt-root would have named one set of inputs while serving another. The local fork had also advanced by three unrelated Crane fixtures, although every upstream blob still matched the frozen baseline pin.

**Fix**: Keep the shared served root explicit and leave its server, ports and configuration alone. Compare its upstream files against a manifest tied to the canonical Git blobs, and keep a separate manifest for the Crane pages and resources actually used. Record a newer local HEAD and its Crane-only additions without silently changing the baseline pin. Verify inputs before and after the comparison; a changed input invalidates the affected measurement. New files belonging to another lane are not changed inputs.

**Takeaway**: **A filesystem copy proves nothing about HTTP input isolation until the listener serving the test is identified.** Read tests/wpt_runner/wpt_server.zig's checkExistingServer and readiness path before treating --wpt-root as a server-selection option.
