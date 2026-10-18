# Debugging: An errdefer beside an explicit cleanup in a catch frees twice

**Date**: 2026-10-18
**Lesson**: "Determine navigation params policy container" gained `errdefer result.deinit()` (lane leaks4) while its UIR 3.3 inheritance kept `catch |err| { result.deinit(); return err; }` from an earlier change (Codex row 50): an out-of-memory copy of the parent's navigation-upgrade tuples deinit'd the container twice.

**Why**: Each change was right alone. The catch block was written for a function with no errdefer; the errdefer was added for the `try`s around it, and nobody re-read the catch blocks below it. PolicyContainer.deinit ends with `self.* = undefined`, so the second deinit read 0xaa bytes as pointers.

**What Happened**: Lane leaks5 gave the iframe OOM sweep's parent page `upgrade-insecure-requests`, so every navigation copies one tuple (an allocation that can fail). On lane/int4 the srcdoc sweep then crashed: "Segmentation fault at address 0xaaaaaaaaaaaaaaaa" in PolicyContainer.deinit, from navigationParamsPolicyContainer's errdefer. Without a UIR policy the copy allocated nothing, and no sweep could reach it.

**Fix**: `try result.inheritUpgradeInsecureNavigations(container);` - the errdefer releases the container once. When adding an errdefer, grep the function for explicit cleanups of the same value in catch blocks and remove them.

**Takeaway**: **Adding an errdefer changes every catch block below it: remove their explicit cleanups of the same value, or each error frees it twice. And give a sweep's fixture the inputs that make each copy allocate.**
