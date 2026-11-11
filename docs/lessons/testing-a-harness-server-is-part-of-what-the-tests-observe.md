# Testing: A harness's own server is part of what the tests observe

**Date**: 2026-11-11
**Lesson**: When a harness serves a project's test pages itself, every header and status it sends is observed by some test; a missing one shows up as an engine failure.

**Why**: jQuery's "jQuery.ajax() - HEAD requests" asserts `/Date/i.test( xhr.getAllResponseHeaders() )`. Its own test server (Node's http module) sends Date, as RFC 9110 6.6.1 requires of an origin server with a clock. std.http.Server sends no Date unless told to.

**What Happened**: Lane fw1 b2's diagnosis run of jQuery's ajax module failed "HEAD requests" with "No Date in HEAD response" - a Crane failure on the face of it. The static server (tools/fw_matrix/server.zig) was the cause; with an IMF-fixdate Date header (pinned by a test against RFC 9110's own example) the test passed in both later runs.

**Fix**:
1. Make the harness's server a correct origin server (Date, content types, 404 for what it does not serve) and pin each by a test.
2. Before filing a failure on the engine, ask what the harness supplied to the assertion.

**Takeaway**: **Before a framework failure becomes an engine finding, check what the harness's own server sent: it is part of the test.**
