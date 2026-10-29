# Spec Compliance: Early Returns Can Preserve State for the Next Interaction

**Date**: 2026-10-29
**Lesson**: Preserve an algorithm's early returns before moving cleanup across them; state that looks stale can govern a later interaction.

**Why**: An event algorithm's stored target is behavior, not just a resource. Clearing it more eagerly can change which object a later event acts on, even when the event that performs the cleanup has no visible effect.

**What Happened**: Review of dialog light dismiss found that Crane cleared the remembered dialog on every pointerup. HTML's step 3 instead returns before reading or writing that target when the open-dialog list is empty. The earlier browser probe kept a second dialog open, so it did not cover this branch. A previous press can remember A, close every dialog, and finish while the list is empty. A later press can begin with no open dialogs, then open A and B before releasing inside A. Preserving the old target makes the release close B; clearing it makes that comparison fail. The integrator corrected the earlier unconditional-cleanup instruction to follow the literal early return.

**Fix**: Check the empty list before finding the nearest clicked dialog, for both pointerdown and pointerup. Write the target only in the algorithm's stated steps. Pin the cross-press behavior and the empty-list pointerdown separately. Treat removal and document teardown as separate lifetime boundaries. Clearing to null on removal also changes behavior: an outside release falsely matches null and closes another dialog. The integrator probed that case in Chrome and Firefox, then required a removed marker that holds nothing and equals no node. It preserves the mismatch while releasing the detached subtree; any remaining identity limitation after reinsertion must be stated. A probe of one branch is not evidence about another branch that it never enters.

**Takeaway**: **An early return can preserve state that the next interaction observes; cleanup placement is part of the algorithm.**
