# Debugging: Read which term of a max(floor, x) bound is in force before you vary x

**Date**: 2026-11-22
**Lesson**: Before an experiment that moves one term of a bound shaped like `max(floor, coefficient * live)`, read which term applies in the measured run. When the floor is the larger term, changing the coefficient tests nothing, and a result of "no change" says nothing about the bound.

**Why**: In lane mem1, the deferred teardown queue's byte bound frees a slice once `dying > max(dying_floor, live)`, with `dying_floor` at 2 MB. A test of 3,000 delete-joins in one timer callback peaked at 1.9x the same joins spread over callbacks. I said the bound caused it, and the integrator ruled on that. The data run that was meant to confirm it halved the live term. The peak came out identical (24,225 objects, 2,560 nodes freed inside callbacks), so I reported the explanation as disproved. Only a census settled it: live was 638,928 bytes, which put the 2 MB floor in force, and dying was 2,025,600 bytes, just under it.

**What Happened**: The first explanation was right about the bound and wrong about the term. I had assumed `live` was large (the undo history's 1,000 steps) without reading it. The experiment I chose (`live / 2`) could not move a bound that `live` did not set. The census was a developer-console host that walked the slab by vtable name at the callback's last statement, read the queue's pending nodes and the DOM figure's live and dying bytes, and compared one long callback with the largest spread callback. It showed 11,060 of the 11,210 extra objects were queued trees: 14,440 nodes against 800.

**Fix**: Print every input of the bound at the moment that matters: live, dying, the floor, and pending nodes. Do it at the peak (inside the callback), not after it. Then pick the experiment that moves the term in force. A census by interface at that same moment tells you what the excess actually is before you theorise about why.

**Takeaway**: **A bound is `max(a, b)`: measure both terms where the peak is, then vary the one that is larger. "Changing b did nothing" is only evidence when b was in force.** Corollary: report a disproof to whoever ruled on the explanation as soon as you have it, and correct the comments and commit messages that repeat it before they merge.
