# Testing: A partition test needs a cross-site top level

**Date**: 2026-10-16
**Lesson**: A test that checks state is not shared across top-level SITES must put the other top level on a different site, not just a different origin.

**Why**: Partitioned state (the CORS-preflight cache, HTTP authentication entries, the HTTP cache, cookies) is keyed by the top-level SITE: scheme plus registrable domain. `www1.web-platform.test` and `web-platform.test` are cross-origin but the same site, because `test` is not a public suffix and both share the registrable domain `web-platform.test`.

**What Happened**: Codex row 44's `crane/xh-preflight-partition.html` opened its "other top-level site" on `HTTP_REMOTE_ORIGIN` (www1.web-platform.test) and expected a fresh preflight there. It passed only because no request carried a top-level site yet, so the preflight cache was bypassed for every request. Once the integrator's capture gave requests their real partition key, the same-site page would have reused the cached preflight and the test would have failed on correct behaviour (row 44 review M1).

**Fix**: Use `get_host_info().HTTP_NOTSAMESITE_ORIGIN` (`{{hosts[alt][]}}`, not-web-platform.test) for the other top level. The test then passes for the right reason: 2/2 with the capture.

**Takeaway**: **Partitioning is by site: a cross-site test needs HTTP_NOTSAMESITE_ORIGIN; a www1 subdomain is the same site and only passes while partitioning is off.**
