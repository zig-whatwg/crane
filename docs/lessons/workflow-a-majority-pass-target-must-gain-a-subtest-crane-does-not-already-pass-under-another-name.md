# Workflow: A majority-pass target must gain a subtest Crane does not already pass, or pass trivially in the browsers

**Date**: 2026-11-20
**Lesson**: Before ranking a "majority of Chrome, Firefox and Safari pass, Crane fails" subtest as a target, check that it is not a name-only miss and that the browsers' passes are not the trivial result of not shipping the feature.

**Why**: The target list is a join on subtest NAMES. A subtest whose name embeds a value Crane prints differently is "missing" in Crane while Crane passes the same check under its own name, so fixing the name gains nothing: the old name's pass is lost as the new one appears. And an "invalid value" test passes in every browser that does not ship the property's grammar at all, so its majority says nothing about the feature (golden rule 2: a browser that does not ship the feature does not count).

**What Happened**: Lane maj5 re-ranked generation 233's 2,675 majority-pass subtests. 42 of them were name-only: IndexedDB/structured-clone's Date subtests carry `Date.prototype.toString()` ("GMT+0000 (Coordinated Universal Time)" in the browsers, "(UTC)" in Crane, whose Intl is its own), and dom/events/passive-by-default's carry `target.constructor.name` ("HTMLDocument" vs "Document") - Crane passes 20/20 and 100/100 of those files under its names. And css-images' `image()` invalid-value rows, and caret-color's two-value rows, pass in all three browsers because none ships `image()` or the two-value caret-color (their valid-value rows FAIL in all three).

**Fix**: For each target file, compare Crane's own subtests in the generation's wptreport (same file, same status counts) before calling a `None` row a failure; for an invalid-value grammar row, read the same browsers' results for the matching valid-value file. Drop name-only rows; treat a grammar row as spec work (the spec decides, the browsers do not count), and say so in the ranking.

**Takeaway**: **A `None` (absent) Crane status is a name mismatch until Crane's own subtests for that file say otherwise, and a browser that rejects every form of a grammar is no vote on which forms are invalid.**
