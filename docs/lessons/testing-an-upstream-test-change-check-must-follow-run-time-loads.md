# Testing: An upstream-test-change check must follow run-time loads, not only static references

**Date**: 2026-11-14
**Lesson**: To decide whether a WPT file "changed upstream", compare the file and every resource it loads, including the data it fetches at run time. A static `<script src>` and META scan calls such files byte-identical when they are not.

**Why**: Many WPT tests keep their cases in data files that they fetch at run time. url/url-constructor.any.js fetches resources/urltestdata.json. url/a-element.html does the same from its script, resources/a-element.js, which it loads through an unquoted `src=`. A check that follows only static references misses all of these. A loss in such a file would then be refused as "byte-identical, never an upstream change", although the cases really changed upstream.

**What Happened**: In the WPT update (lane wptup1, cutover step 11), the compatibility comparison flagged three files that the progress tool called byte-identical but whose counts moved against generation 223:
- url/url-constructor.any.js: 1,808 -> 1,824;
- url/a-element.html: 905 -> 913;
- resource-timing/content-type-minimization.html: 68 -> 73 (it fetches mimesniff's mime-types-minimized.json).
All three were gains, and upstream had extended the fetched data (urltestdata.json +113 lines). The tool's parser would have refused a genuine upstream-test-change entry for them.

**Fix** (tools/wpt_progress.py `wpt_loaded_files`, commit 020ad0d0e81):
1. Follow the literal URLs of `fetch("...")`, `new Worker("...")`, `new SharedWorker("...")` and `XMLHttpRequest.open("GET", "...")`. Skip a template literal that contains `${`, because its URL is computed.
2. Resolve a run-time URL against the file AND against the test's document. A classic script's `fetch()` resolves against the document, not against the script.
3. Accept unquoted `src=`/`href=` attribute values.
4. Pin each rule with a self-test case that fails without it (the fixtures f/, g/ and h/).
With these rules the compatibility check passed: 0 byte-identical files with a different result.

**Takeaway**: **A file's inputs include what it fetches at run time. Check the claim "byte-identical" against a real run before you trust it to refuse an explanation.**
