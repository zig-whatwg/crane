# Testing: Render the Actual Plan Before Writing Launch Files

**Date**: 2026-10-29
**Lesson**: Exercise the actual prepared plan through its renderer before writing any launch files.

**Why**: A plan builder, launcher and renderer can each pass their own tests while disagreeing about a path invariant. A synthetic launcher fixture may bypass the dependency that rejects the real plan.

**What Happened**: Q185 moved only the new maps TIP controls into `controls-q185`, preserving the completed BASE controls. The new plan and launcher passed their offline checks, but the original script renderer required the controller's parent to be named `controls`. Preparation wrote five local control copies and the TIP plan before reaching that guard. It stopped before writing a launch script or receipt, with no remote action or TIP observation.

**Fix**: Preserve the partial preparation and its failure. Seal the files already written and enumerate the missing outputs. Under Q188, a new renderer accepted exactly `controls-q185` for maps TIP while keeping BASE and the final family unchanged. Tests sent the actual prepared BASE and TIP plans through the renderer and rejected cross-arm directories, wrong hashes, paths and attempts. A separate one-use completer checked all six preserved files, rejected extra files and existing targets, and created only the two missing outputs. For future preparation, validate and render the complete plan in memory before opening any output file.

**Takeaway**: **Test the real dependency chain before creating artifacts; recover a partial preparation by verifying preserved bytes and writing only explicitly missing files.**

Offline fixtures must use the live producer’s representation, not just its serialized JSON form: Python tuple keys become lists in JSON, so a mock built only from JSON can miss a real comparison failure.
