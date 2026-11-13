# Testing: Close a test's agent in the Browser's end order - releaseNodeWrappers, the last drain, then the agent

**Date**: 2026-11-09
**Lesson**: `engine.destroyAgent` ends every node wrapper but does not drain the host's deferred teardown queue, so trees whose release cascades - a host's teardown leaving its shadow root a garbage root - are queued after the last drain and outlive the test.

**Why**: Browser.deinit ends its agent in a fixed order: `engine.releaseNodeWrappers(agent)`, then `deferred_teardown.drainAll()` (asserted empty), then the sweeps, then `engine.destroyAgent`. A test page that only destroys its realm and its agent skips the drain between, and a shadow tree whose host's tree is freed late (`shadow_hosts.hostDestroyed` -> `refcount.hostGone` -> lowered -> queued) is never freed; the Crane test runner's state digest reports it as `runtime.standalone_objects: (absent) -> N: the test left it changed`.

**What Happened**: tests/v8/wrapper_walk_test.zig's scenario loops failed the state check in every mode - with the walk, without it, with no edges - so the walk was not the cause. Counting the standalone slab before and after each scenario named the two shadow-root scenarios (2 and 3 objects left). Closing the page in the Browser's order freed them.

**Fix**: A test page's `close`: `destroyWindowRealm`, `engine.releaseNodeWrappers(agent)`, `queue.drainAll()`, `engine.destroyAgent(agent)`.

**Takeaway**: **A test that makes an agent ends it the way the Browser does; when a state-check leak appears in every mode of a test, count objects per case before suspecting the code under test.**
