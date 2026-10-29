# Testing: Equal pass counts can hide a regression

**Date**: 2026-10-28
**Lesson**: Compare the identities of passing subtests, including supplemental candidates, before accepting an unchanged or improved pass count.

**Why**: One newly passing case can conceal a different case that regressed. A per-file count, and even the file's gate status, cannot establish that every old pass survived.

**What Happened**: The slotted-popover focus WPT passed one of two subtests on both BASE and TIP. BASE passed backward Tab; TIP passed forward Tab. The initial count comparison reported no loss. Comparing the raw subtest streams exposed the backward regression, and three isolated alternating BASE/TIP pairs reproduced it. The loss was already present in the original focus change; a later main merge and word-navigation overlay were unrelated.

**Fix**: Compare PASS sets keyed by test URL, including its variant query, and exact subtest name. Audit supplemental candidates as well as the worklist. Reconcile those sets with journal counts and reject missing or duplicate stream records. Keep newly passing cases separate from lost cases; a gain never cancels a loss. Reproduce a loss with the required isolated pairs, then repair or route it before acceptance.

**Takeaway**: **Equal counts do not mean equal passes.** A no-regression claim needs subtest identities for every measured upstream file.
