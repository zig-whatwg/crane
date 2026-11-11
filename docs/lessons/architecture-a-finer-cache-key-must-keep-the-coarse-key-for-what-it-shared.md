# Architecture: A finer cache key must keep the coarse key for what the coarse key shared

**Date**: 2026-11-11
**Lesson**: When a cache's key is refined so that it serves more hits, everything else the old, coarser key grouped together loses its group: keep the old key for those operations, and run them before the new key's work.

**Why**: Crane's matched-properties cache does two jobs with one bucket. `find` hands out a kept style when the key and the full correspondence match. On a miss, `add` adopts equal groups and records from the other entries of the same bucket, so elements whose values are equal hold one object, and their children, keyed on the parent's groups by address, find one key (lane style1 b3). Before lane style1 b5 a style attribute was never looked up, and its key named only the property names it declared. Rows with `margin-top: 0px`, `1px` and `2px` therefore shared a bucket and converged by adoption.

**What Happened**: Lane style1 b5 keyed a style attribute by its content hash, as Blink keys inline style, so that equal attributes hit. The first green run of the existing tests failed `style1b3_convergence_test`: 100 rows now held 3 custom-property records, 3 font groups and 3 text groups, where before they held 1 of each. Each distinct content had its own bucket, so the first row of each content found nothing to adopt from. On a page whose rows carry unique style attributes (`transform: translateY(Npx)`), no row would have shared anything, and the rows' children would have missed on parent addresses. The hits the new key bought would have cost the convergence the old key gave.

**Fix**:
1. List every operation that reads the bucket, not only the lookup. Here that is `find`, plus `add`'s adoption scan and its adoption-only entries.
2. Give the lookup a second key holding the old coarse identity (`Lookup.shape`: the declared names, or a hint's address). The engine computes it only for resolutions that have an own block.
3. In `add`, run the old path under the coarse key first (adoption, then an adoption-only entry while that bucket has room). Then adopt and keep the style under the fine key. The order matters: the entry a later hit hands out must already hold the converged groups.
4. Keep a test that counts distinct shared objects across elements whose fine keys differ (here, the b3 convergence test).

**Takeaway**: **A more precise key splits the groups the old key formed: before refining it, list what else used those groups, and keep the old key for them.**
