# Testing: Attribute a sweep-only difference with a side-by-side HEAD sweep

**Date**: 2026-09-22
**Lesson**: A result that appears only in a long `--from-file` sweep - a crash at
file 16, a file dropping from 222 passing subtests to 1 at file 150 - cannot be
attributed by rerunning the file alone, nor by replaying a prefix once. Build
the committed HEAD into a separate prefix (`-p /tmp/crane-head` from a
throwaway worktree) and run BOTH binaries over the same list AT THE SAME TIME,
so they share the load.

**What Happened**: three sweeps of the named-access change set crashed at
`custom-elements/connected-callbacks-template.html` (a garbage
`IFrameIntegration` reached from the NEXT page's `initializeIframeBrowsingContexts`),
and `valid-custom-element-names.html` fell from 222 to 1 passing. Both looked
like regressions. Side by side, HEAD crashed at the same file, and on the next
pair of runs the roles reversed: HEAD 6 passing and two crashes, the change set
222 and one. Both binaries carry a pre-existing, process-history-dependent
corruption; the change set added nothing to it.

**Takeaway**: **Run the control under the same conditions as the experiment.**
A sweep-only difference that flips between runs belongs to both binaries until
a side-by-side run says otherwise.
