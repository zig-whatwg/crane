# Testing: A failing-subtest count is not a target list - compare with the browsers first

**Date**: 2026-11-19
**Lesson**: Before a lane is briefed on a block of failing subtests, compare that block with the aligned wpt.fyi runs subtest by subtest: a large block can be failures that Chrome, Firefox and Safari all share, where Crane is already right.

**Why**: Some WPT files test a change to a spec that has not been made yet. Their expectations are the proposal, so every browser fails them, and so does an engine that follows the spec as it stands. The size of the block says nothing about whether it can be won.

**What Happened**: Lane mime1 was briefed on mimesniff/mime-types/parsing.any.js: 1,734 failing subtests at generation 231 (867 in each of the window and worker variants), the second-largest failing block in the worklist. Against the aligned runs at Crane's WPT revision 2358bd4835 (Chrome 157 4786307730243584, Firefox 160 4877168468033536, Safari 27.2 6479119966273536), all 867 failing subtests fail in all three browsers, in both variants. Crane's failure message is Firefox's, character for character, on every one of them:
- 602 "(Blob/File)" subtests expect `new Blob([], {type})` to parse and serialize the type as a MIME type. The File API still says to blank a type that has a character outside U+0020-U+007E and to ASCII-lowercase the rest (Blob constructor step 3; the `type` attribute is "an ASCII-encoded string in lower case"). Parsing is the proposal in w3c/FileAPI#43, open since 2016 ("What is still needed here is that we update the specification", 2018). By TPAC 2026 the discussion had moved to keeping `type` as the raw input, ASCII-lowercased, and adding a separate parsed getter, and that design is still only a proposal.
- 265 "(Request/Response)" subtests expect `Response.blob().type` to keep a parameter value's case and its non-ASCII bytes. All three browsers lowercase the value or blank it, which is what the File API's `type` attribute says. Five of the 265 are comma cases (`x/x;,=x;bonus=x`): Fetch's "extract a MIME type" gets, decodes and splits the header at the comma, which gives `x/x`. Crane, Firefox and Safari return `x/x`; the test's expectation comes from parsing the whole string.
The other file, media/media-sniff.window.js (36 failing), passes in all three browsers but needs MP3, FLAC, Ogg, MP4 and WebM decoders, and Crane's decoders come from the host.

**Fix**: There was nothing to fix in Crane. The lane sent "main" the subtest-by-subtest evidence (tmp/plans/mime1-evidence/) and ended its batch with no code change.

**Takeaway**: **Count only the subtests that two or more browsers pass and Crane fails before you size or brief a block. A failing count that every browser shares is a spec or test-bug question, not work for a lane.**
