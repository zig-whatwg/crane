# Workflow: A merge that adapts one reader of a changed type must find them all

**Date**: 2026-10-24
**Lesson**: When a merge resolution adapts code to a value whose shape another branch changed, list every reader of the old shape in that module, not only the one the failing test names.

**Why**: Two rows built on the same main without seeing each other. Codex row 117 added a CSS resource loader that read `background-image` only as a `.text` value. Codex row 119 made `background-image` a typed `.layers` / `.image` value that keeps its serialized text beside its components. Each row's own gates and A/B were green; only the merged tree had the clash.

**What Happened**: The integrator's merge check failed one native test: `style_resource_cache_test` unwrapped a null `sharedText()` and aborted, hiding the rest of tests-dom. The resolution, `resource_loading.backgroundImageText()` (90714cd44ee), fixed the fetch path the test pointed at, `selectStyleResources`. A second reader in the same file, `ruleMayHaveResources`, still switched only on `.text` and `.content`, so a sheet given typed background values through a CSSOM edit could miss resource-interest discovery. Row 119 found it by reading the code (Q181), after main had been pushed.

**Fix**: For a type-shape interaction, grep the consumer module (and its callers) for every switch arm or comparison on the old variant (`== .text`, `.text =>`, `sharedText()`) before declaring the merge resolved. Fix all of them in the resolution, or name each one left over in the merge commit and queue it. Prefer the type's own accessor (`Value.resourceUrls()`, `backgroundImageText()`) over per-variant arms, so the next variant does not reopen the gap.

**Takeaway**: **A failing test names one reader; a changed type has as many readers as the grep finds.**
