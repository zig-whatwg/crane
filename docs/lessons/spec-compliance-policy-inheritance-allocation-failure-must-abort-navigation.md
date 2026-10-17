# Spec Compliance: Policy inheritance allocation failure must abort navigation

**Date**: 2026-10-17

**Lesson**: Adding an owned security-policy snapshot requires checking what every allocation-failure return means at its caller.

**Why**: An optional policy container can mean either that no policy exists or that a policy could not be copied. Treating those meanings alike can commit a document with weaker restrictions than its creator intended.

**What Happened**: Upgrade Insecure Requests 3.3 requires inherited navigation opt-ins. Storing their owned host/port tuples adds a possible allocation failure to HTMLIFrameElement's policy-container inheritance. The private builder already returned null on allocation failure, but runCommit interpreted null as empty CSP sandbox flags and passed it onward. The document then received a fresh empty container. Reusing that error path without reading the caller would have made the new inheritance fail open.

**Fix**: Abandon the navigation immediately when the policy-container builder returns null, before unloading the old document, changing realms or committing history. Keep the existing record cleanup and load-delay completion. On a failed tuple union, destroy the partially constructed container before returning null. Document the null return as allocation failure, not absence of policy.

For snapshot data itself, own the copied host strings, release partial copies on error, and test allocation failures with std.testing.allocator beneath a FailingAllocator. An empty inherited set must allocate nothing. Keep separate follow-ups for other callers that suppress clone errors; a correct new abort guard does not repair those paths.

**Takeaway**: **Trace an allocation failure through its caller before adding security state to an existing optional snapshot.**
