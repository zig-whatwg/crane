# Testing: A self-check that compares through the predicate it checks proves nothing about it

**Date**: 2026-11-11
**Lesson**: A Debug self-check that verifies a sharing decision by comparing the shared object with a freshly computed one through the same equality the sharing used can never fail on that equality's blind spots. Make the check observe what a reader observes, by code that does not call the predicate, and prove it bites: revert the fix, keep the new check, and watch the bug-finding run panic on the failing test.

**Why**: Equality functions are written for a purpose, and their documented scope is narrower than "no reader can tell these apart". Crane's `Value.eql` "deliberately remains a value/text comparison": a url() keeps its authored text, and `Value.resourcesEql` is the documented pair for resolved URLs and request data. Lane style1 batch 3 shared a group between two elements when every value was `identical` or, for an allocated payload, `Value.eql`. Its self-check, run on every cache hit and miss in Debug builds and in the bug-finding WPT runner, compared the result with a fresh cascade through `firstDifference`, which also used `Value.eql`. The check and the code shared one blind spot.

**What Happened**: Batch 4's FULL A/B lost one subtest: css/cssom/css-style-attr-decl-block.html, "Changes to CSS declaration block after a base URL change". The element's `background-image: url(./)` was set again after a `<base>` was added, and getComputedStyle still answered the old base's URL. The miss path had adopted the previous resolution's background group, because `url(./)` under both bases is one value to `Value.eql`. The bug-finding sweep over 13,117 files reported "panics 0", since its self-check agreed with the adoption.

The integrator ruled a three-part fix:
1. One predicate, `computed_style.interchangeable` (`eql` and `resourcesEql` for a Value, the record's eql for custom properties), with an audit of what `Value.eql` folds in its doc comment.
2. A self-check that observes: `firstObservableDifference` compares each non-identical longhand's serialized resolved value and its fetch identity (resolved URL, flags, and the source's base, referrer, referrer policy and origin-clean flag), written out field by field rather than through `ResourceUrl.eql`.
3. A proof: with the old predicate patched back in and the new check kept, the unit tests fail and the bug-finding runner aborts on the WPT file with "matched-properties cache adoption changed background_image".

**Fix**:
1. Name the sharing predicate for what it promises ("interchangeable"), and list in its doc what the underlying equality ignores. Pair every documented companion such as `resourcesEql`.
2. Give the self-check an independent observation: what the public API serializes, and what other layers (fetch, layout) read. Do not reuse the predicate or its helpers.
3. Prove the check bites: revert the fix in a scratch patch, keep the check, and run the failing WPT file on a bug-finding build. State that RED with the fix.
4. Test each aspect the equality ignores with two values that are equal but not interchangeable. Here: a url under another base, and the same URL under another referrer policy.

**Takeaway**: **A check that shares the predicate it checks inherits its blind spots: verify a sharing decision by observing what readers see, and prove the check fails with the fix reverted.**
