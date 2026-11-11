# Tools: Attribute a source line to the test whose own call holds it, not to the test above it

**Date**: 2026-11-11
**Lesson**: A scan that asks "which tests do X" (request a mock server, read layout) must bound each test by its own call's parentheses; bounding it by "until the next test definition" gives a loop's data, written between two tests, to the test above it.

**Why**: Test files define tests inside loops whose data precedes the definition (`jQuery.each( { "If-Modified-Since": { url: "mock.php?action=ims" } }, function( type, data ) { QUnit.test( ... ) } )`). By "next definition" boundaries the data line falls into the previous test's span.

**What Happened**: Lane fw1 b2's first scan of jQuery's tests for mock.php flagged "jQuery.ajax() - data - process string with GET" (it aborts in beforeSend and requests nothing) and missed the four If-Modified-Since/Etag tests the loop defines; the same shape gave "trac-11743 - script, throws exception" the echoData loop's request. A paren-matching scan found them and listed the three orphan lines to read by hand. A naive paren matcher in turn overran past a regex literal in manipulation.js, so its extra hits were checked by hand too.

**Fix**:
1. Bound each test by its call (match parentheses, skipping strings and comments).
2. Print every hit that falls in no test's call ("orphans") and read each: it belongs to the tests its loop defines.
3. Diff the two scans and read every difference.

**Takeaway**: **A source scan's boundaries are a claim: bound a test by its own call, list what falls outside every test, and read the differences by hand.**
