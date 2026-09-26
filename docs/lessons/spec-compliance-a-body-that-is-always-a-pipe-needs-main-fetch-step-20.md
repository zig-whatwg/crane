# Spec Compliance: A body that is always a pipe needs main fetch step 20

**Date**: 2026-09-25
**Lesson**: Collecting the whole body hid the null-body rule, because an empty body read the same as no body.

**What Happened**: once every response body became a pipe (streamed bodies, the networking lane), `response-null-body.any.js` fell from 16/22 to 2/22.

**Fix**: main fetch step 20 - a null body for HEAD, CONNECT and null-body statuses, releasing the pipe (which cancels the transfer). The file went to 22/22.

**Takeaway**: **When bytes become a stream, "no body" and "empty body" become different states. Apply the spec's rule that tells them apart.**
