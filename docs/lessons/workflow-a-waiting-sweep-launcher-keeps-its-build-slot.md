# Workflow: A Waiting Sweep Launcher Keeps Its Build Slot

**Date**: 2026-10-18
**Lesson**: Detaching a WPT sweep into tmux does not release the build slot of a crane-remote wrapper that waits for it.

**Why**: crane-remote holds its build reservation until the wrapper exits. A command that starts tmux and then calls `tmux wait-for` keeps that wrapper alive for the entire sweep. Runner tokens acquired by crane-measure are a separate reservation; acquiring them correctly does not release the build slot.

**What Happened**: Row 71 ran valid cost pairs and timer/leak checks through the correct runner-token helpers, but enclosed them in a build wrapper. Its next wrapper launched a detached targeted sweep and waited for completion, again occupying a build slot. The liaison identified the waiting launcher. Stopping only that owned launcher released the slot while the detached sweep continued. The completed measurements remained valid.

**Fix**: Use crane-remote for builds and native suites. Launch WPT measurements over plain SSH, or in an owned tmux session, through crane-measure/crane-exclusive as applicable. Poll over plain SSH. If a waiting wrapper already holds a slot, first prove the sweep is independent of that wrapper, stop only the owned launcher, and verify both reservation release and sweep continuity. Compare the whole liaison questions file when checking for updates: a reply inserted beside an earlier question will not appear in a tail of the file.

**Takeaway**: **Runner tokens and build slots are separate reservations; a waiting launcher keeps its build slot.**
