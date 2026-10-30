# Workflow: A module that re-exports impls hides its users from lint-impls

**Date**: 2026-10-30
**Lesson**: `src/html/full.zig` had `pub const impls = @import("impls");`. The lint counted that line once, as `impls.@import`. The test that used it, `const impls = html.impls;` followed by `impls.Node.getInternalState`, `getParent` and `deinitNodeByType`, was invisible to the lint.

**Why**: lint-impls counts references that start at `@import("impls")` or at a relative `@import("X.zig")` inside src/webidl/impls. A reference reached through another module's re-export starts at that module's name (`html.impls.Node`), which the lint does not follow. The design's section 1.2 lists two other blind spots of the same kind: helper files in impls/, and `impls.<lower-case>`.

**What Happened**: Impls batch 7 deleted the re-export as one listed site, and the html test module then failed to name `html.impls`. Converting that test was part of the site:
- the node-state probe became `dom.instance_bridge.getNodeBaseUnaudited(node) != null`;
- the parent read became `interfaces.Node.get_parentNode`;
- freeing an uninserted root became `dom.node_creation.destroyUninserted`.

**Fix**: Before deleting a re-export, grep for `<module>.impls` across src/, tests/ and tools/ - not only for `@import("impls")` - and convert every user in the same commit.

**Takeaway**: **A re-export is a door the lint counts once and never walks through: find what goes through it before you close it.**
