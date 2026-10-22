# Testing: Compare the test before repairing a pass-count drop

**Date**: 2026-10-20
**Lesson**: A lower WPT pass count can reflect a changed assertion rather than changed engine behavior; compare the test revisions before choosing a code fix.

**Why**: Sweep history identifies when a count changed, but an upstream WPT update can change which output a subtest accepts without changing its name or the total number of subtests.

**What Happened**: Row 88 investigated `dom/lists/DOMTokenList-coverage-for-attributes.html`, which fell from 174 passes to 173 across main's WPT snapshot update `a9795beef`. Comparing the old gitlink `1d94d93ecc21683991af2110e5e20f4b748c61d3` with `c4fd9b53e4184f769003966a807e39d4d4939c22` showed that the test newly expected `relList` on a MathML `a`. The engine's DOMTokenList implementation had not changed in that interval. Aligned Chrome, Firefox and Safari runs at revision `0f26972422` all failed that new assertion with `undefined`. The separate SVG `a.relList` failure already existed before the snapshot update.

**Fix**: Compare both engine history and the WPT gitlinks around the first changed count. Match individual failing assertions against aligned browser runs by run ID, then inspect their messages. Keep an upstream expectation change separate from a pre-existing missing implementation. Resolve any spec/browser disagreement under the project's golden rule before changing behavior.

Browser evidence: [DOMTokenList coverage at revision 0f26972422](https://wpt.fyi/results/dom/lists/DOMTokenList-coverage-for-attributes.html?sha=0f26972422&label=master&label=stable). Run IDs: Chrome `6244794098778112`, Firefox `5917475882663936`, Safari `5156841570172928`.

**Takeaway**: **A historical count is a lead, not a behavioral contract. Establish which assertion changed before treating the decrease as an engine regression.**
