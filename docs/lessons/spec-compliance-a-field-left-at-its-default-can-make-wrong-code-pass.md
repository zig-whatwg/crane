# Spec Compliance: A field left at its default can make wrong code pass - setting it surfaces what read it

**Date**: 2026-10-17
**Lesson**: When a request field the spec sets was left at a placeholder ("client"), every check that reads it answered as for that placeholder; set the field and audit its readers, because some passes were accidents and some gaps were hidden.

**Why**: Frame navigations left the request's origin "client". InternalRequest reads "client" as same-origin (currentUrlIsSameOrigin), the TAO check reads it as "null" (so every navigation failed TAO), the Origin header was never sent, and the redirect-taint could never be computed.

**What Happened**: Lane sw1-b5 set the origin (HTML "create navigation params by fetching" step 3). navigation-headers.https.html went 24 -> 38/83 and the SameSite cookie files gained - but (1) the Request constructor's missing step 13.4 (origin "client" for a non-empty init) suddenly mattered: a service worker's fetch(new Request(event.request, {...})) carried the frame's origin in mode "same-origin" and hung the file for 60 s; and (2) resource-timing's iframe-failed-commit and SO-XO-SO-redirect-chain-tao lost 4 cases they had passed only because every navigation failed TAO.

**Fix**: Request.zig step 13.2-13.4; the TAO / navigation-timing cases recorded as a follow-up with the cause.

**Takeaway**: **Before setting a long-defaulted field, list every reader of it: run their areas in the A/B, and expect both hidden gaps and accidental passes.**
