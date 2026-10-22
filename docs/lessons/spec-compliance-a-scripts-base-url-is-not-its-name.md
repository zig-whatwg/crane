# Spec Compliance: A script's base URL is not its name - a redirect changes one and not the other

**Date**: 2026-10-20
**Lesson**: An external classic script has two URLs that agree until a redirect: its base URL, the response's URL (HTML "fetch a classic script" step 5.6), and the name it is compiled under - what stack traces and error filenames show - which browsers keep as the URL the page requested. Storing one field for both made a fix to the first a leak in the second.

**Why**: ae51453ffe6 (2026-10-17) made the script element's `script_url` the response URL so that the base URL followed redirects, correctly. The run site named the script by the same field, so a function from a script fetched through a cross-origin redirect showed the redirect target's path, query and #fragment in `error.stack`: content-security-policy/reporting/post-redirect-stacktrace.https.html went from 2 to 0. Chrome 155 and Firefox 158 pass it (Blink names a classic script by Resource::Url(), its initial request URL); Safari 27 leaks the path.

**What Happened**: The user's subtest-loss audit flagged the file (best 2, now 0). Lane engine1 kept the request URL beside it (script_element.State.request_url, set at prepare's src parse, never replaced) and named external classic scripts by it; the base URL stays the response's. 0/4 -> 2/4 (the other two time out on a ReportingObserver the runner never delivers).

**Fix**: two fields for two URLs - the request URL for the script's resource name, the response URL for its base URL - and a comment at each use naming which one it is.

**Takeaway**: **When a fix moves a URL to "the right one", list every reader of the field first: a URL that is right for resolution can be a leak as a display name.**
