# Workflow: A test file under tests/ joins every run the moment it exists

**Date**: 2026-09-30
**Lesson**: `build.zig` compiles every `*_test.zig` under tests/<area>/, tracked or not, and `crane-remote.sh` syncs the working tree. So a test written ahead for the next step runs in this step's chat job, and fails its build if the next step's code is not there yet.

**Why**: `addTestFilesFromDir` walks the directory, so a file is part of `zig build test` because it exists, not because it is committed or referenced. `crane-remote.sh` rsyncs the whole worktree except /tmp, including untracked files. A test that names a module the current step does not yet export fails to compile, and that turns the step's run red for a reason that has nothing to do with the step.

**What Happened**: The scriptimpls lane wrote tests/dom/document_script_hooks_test.zig, which uses `dom.document_scripts`, while step 1's green run was about to start. The hook module was not exported until step 2. The run was already synced and waiting for a slot when this was noticed. It had to be killed on chat and started again with the file parked in tmp/. The same thing happened a second time when step 2's test also tested the browsing-context hook that step 4 was meant to add. That hook was folded into step 2.

**Fix**:
1. Before starting a chat run, `git status --short tests/` and check that every untracked test belongs to the step being tested.
2. Park the others in tmp/ (which rsync skips) until their step.
3. A test file that covers several hooks lands with the last of them, or the hooks land together.

**Takeaway**: **Under tests/, existing is enough to run. Park the next step's test in tmp/ until its code is in the tree you sync.**
