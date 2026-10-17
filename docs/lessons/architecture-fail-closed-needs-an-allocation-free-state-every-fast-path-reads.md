# Architecture: Failing closed needs an allocation-free state that every fast path reads

**Date**: 2026-10-17
**Lesson**: A `<meta>` CSP that ran out of memory was dropped (`csp_list.append(policy) catch policy.deinit()`), so the document ran unprotected. Recording "a policy is missing" must not allocate, and every place that skips the checks for an empty list must ask the list, not its length.

**Why**: The insertion steps cannot throw, and the policy's own allocation is what failed, so there is nothing to append. A flag on the list (`CSPList.unenforceable`) is set without memory, and the decision entry points in src/csp return "Blocked" for it. But five hosts asked `policies.items.len == 0` to skip the checks - the inline check, the javascript: URL check, eval's, the plugin check and Document's inline-script check - and an OOM'd meta leaves exactly an empty list: those fast paths would have read "no policy, allow".

**What Happened**: Lane leaks2 listed the meta append among the fail-open sites. The integrator chose a complete fail-closed: the flag, every src/csp entry point, and the hosts' fast paths moved to `isEmpty()`, which is false for an unenforceable list. The flag is copied with the list, so a srcdoc frame or a data: worker that inherits a clone fails closed too.

**Fix**: csp.integration.enforceMetaPolicy runs HTML's steps 3-5 and marks the list on any allocation failure; tests/csp/meta_policy_fails_closed_test.zig sweeps every allocation failure (either the policy is in the list, or the list blocks every decision), and tests/html/meta_csp_fails_closed_test.zig checks inline script, event handlers, eval, Function, fetch and javascript: URLs in a page before and after.

**Takeaway**: **Fail-closed state must cost no allocation and must live where every reader already looks. Route "is there anything to check?" through the type's own method, never through a length a flag cannot change.**
