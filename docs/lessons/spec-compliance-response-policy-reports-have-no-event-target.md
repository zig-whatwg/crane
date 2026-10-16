# Spec Compliance: A response-policy report has no document event target

**Date**: 2026-10-16
**Lesson**: Report a blocked navigation using the response's metadata and endpoints, without treating the embedding document as the violation's global.

**Why**: A frame-ancestors check happens before the child document exists. The parent can provide transport, but its URL, reporting endpoints, and event listeners describe a different policy context.

**What Happened**: Crane already blocked frame-ancestors violations, while both upstream reporting files and the new report-uri/report-to fixtures passed no subtests. Reusing the ordinary parent reporter would send the wrong document URL and dispatch a parent securitypolicyviolation event.

**Fix**: CSP §4.2.5 makes a violation with no global or element. Under §5.5 it has no EventTarget. Capture the response's URL, referrer, status, policy, and endpoints in an owned task; use the container global only to carry delivery, guarded by its slab generation. Copy Reporting-Endpoints through the navigation response header filter. Chromium's AncestorThrottle::EvaluateFrameAncestors and network::ReportViolation show this separation.

Modern client-null requests still need the Browser's network configuration and cookie jar. Omitting those transport assignments caused the HTTPS regression to fail certificate validation even though the response endpoint was parsed correctly.

**Takeaway**: **A transport context is not the policy context. Capture the report's data before freeing the blocked response.**
