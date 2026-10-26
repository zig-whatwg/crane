# Testing: Bind WPT Evidence to the Served Source Hashes

**Date**: 2026-10-26
**Lesson**: Identify a local BASE/TIP comparison by the actual test and support files served to its frozen binaries; retain the fork revision as context.

**Why**: Crane's remote mirror excludes WPT's `.git`, and the main WPT checkout can contain uncommitted Crane fixtures. A Git revision alone cannot identify those served bytes. The fixture tree is also shared by concurrent lanes.

**What Happened**: Row 125's width comparison stopped before any runner because its preflight tried to read a Git revision from the served tree. The replacement receipt matched local and remote source hashes. A later preflight saw the local fork revision move while all 6,529 selected source and support-file hashes remained identical. That supported the explicitly approved reuse of the accepted preceding TIP as the next BASE.

**Fix**:

1. Record the local fork revision and dirty-file count as context, and state whether a remote revision was actually observed.
2. Hash the selected sources, harness scripts and their enumerable support files locally and on the server before and after the comparison. Record the dependency-selection method and its limits; a scan of literal URLs does not enumerate every computed URL.
3. Verify frozen runner and snapshot hashes alongside the exact source list. Validate the after-observation before accepting the comparison.
4. When evidence reuse is authorized, retain the original receipts and timestamps and label it as reuse. Changed inputs require matched reruns on both endpoints. A lost PASS still requires contemporaneous isolated controls under the applicable acceptance rules.

**Takeaway**: **Identical served inputs and frozen artifacts make a matched comparison reviewable.**
