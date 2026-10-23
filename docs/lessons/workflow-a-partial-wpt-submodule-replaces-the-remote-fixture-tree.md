# Workflow: A Partial WPT Submodule Replaces the Remote Fixture Tree

**Date**: 2026-10-22
**Lesson**: Keep an uninitialized lane WPT submodule empty when crane-remote supplies the shared fixture tree.

**Why**: crane-remote chooses its WPT sync path from whether the local tests/wpt directory contains files. A single new Crane fixture makes that directory look like a checkout. Syncing it replaces the lane mirror's shared-WPT symlink with a partial directory, leaving native tests without media and image assets.

**What Happened**: Row 118 copied one new fixture into its empty lane submodule while preparing a commit. The next native gate reported 46 FileNotFound failures. The shared WPT checkout was intact; only the lane mirror had lost access to the full tree.

**Fix**: Verify the fixture matches the authorized copy in main, remove only the accidental lane copy, and leave the uninitialized local submodule empty. Restore only the affected mirror's tests/wpt symlink to its approved shared target. Let crane-remote's normal fixture synchronization carry new Crane tests. Rerun the full failed native gate; a mid-run repair does not make the original run green.

**Takeaway**: **A nonempty WPT directory is a sync decision, even when it contains only one test. Verify the complete fixture tree before diagnosing native FileNotFound failures.**
