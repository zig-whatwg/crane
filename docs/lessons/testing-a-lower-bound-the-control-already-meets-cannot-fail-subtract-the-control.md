# Testing: A lower bound the control already meets cannot fail - subtract the control first

**Date**: 2026-11-17
**Lesson**: An assertion "this adds at least N to the figure" proves nothing when the objects that carry the new thing add more than N by themselves; measure the same objects without the new thing and assert on the difference.

**Why**: A test of an accounting change usually makes objects (elements) to carry what is newly counted (their attribute values). The objects were counted before the change. A lower bound on the whole increase is then met by the old accounting alone, and the test passes on a tree without the change.

**What Happened**: Lane vm1 made the DOM memory figure count attribute values. One of its tests made 1,000 elements with a `title` and a class value and asserted the figure rose by at least 1,000 x 64 bytes. With the source change reversed, three of the file's five tests failed with their own messages ("expected 112000 B in the figure, found 0 B") and this one passed: 1,000 divs add more than 64,000 bytes by themselves (144,000: a div's slot and State block are 144 bytes, as the corrected test's own red run printed - "1,000 elements with a title and a class value add 160000 B to the figure, 1,000 plain ones 144000 B"). The commit that added it, with three others, said all of them fail on main. The red run was read test by test, which is the only reason it was seen; the job's status and the count "3 failed" both looked like a red run.

A second test of the five also passed on the unfixed tree, for a different and legitimate reason: it is a balance check (blocks made, shared across three documents and freed must leave the figure where it began), and a tree that counts nothing is balanced. A balance check is proved by mutants instead: one build for each subtraction, with that subtraction removed, each of which must fail the test with the test's own message.

**Fix**:
1. Add a control row of the same objects without the new thing and assert on `measured - control`. Read the control's red numbers too: here the valued elements were already 16 bytes over the plain ones on the unfixed tree (their class read makes a rare block, counted before the change), so the bound has to be more than what the old accounting gives the difference - 64 bytes an element against 16.
2. After a red run, list the tests of the new file that PASSED on the unfixed tree. Each one is either a bad test (fix it and run it red again) or a balance check (give it mutants). Do not write "all fail on main" before reading that list.
3. When a script judges a red or a mutant run, count the test-failure lines (`^error: '.*' failed:`) and the compile-error lines separately: a build that does not compile also ends non-zero and proves nothing.

**Takeaway**: **Read a red run per test, not per file: the tests that pass on the unfixed tree are the ones that need attention.**
