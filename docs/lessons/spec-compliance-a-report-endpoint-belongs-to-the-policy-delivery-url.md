# Spec Compliance: A report endpoint belongs to the policy's delivery URL

**Date**: 2026-10-16
**Lesson**: An inherited CSP needs the URL against which its relative report endpoints were delivered, independently of the URL of the global reporting a violation.

**Why**: A blob worker can inherit a policy containing `report-uri /reports`.
Its violation's document URL is a `blob:` URL, against which that relative
endpoint cannot be parsed. Retaining the policy's origin alone also loses the
path needed for endpoints such as `../reports`.

**What Happened**: Row 46's BASE blocked the dedicated workers' requests but
uploaded none of the four expected blob-worker reports in
`dedicatedworker-connect-src.html` and `dedicatedworker-script-src.html`.
`queueViolationTask` used the worker's current URL as the report endpoint base.
The inherited policy retained its matching origin but no delivery URL.

**Fix**: Give each policy an owned delivery URL beside its matching origin,
preserve it through policy-container copies, and snapshot it when queuing a
legacy report. The violation's `documentURI` still names the reporting global.
Native tests check independent copies and cleanup at every allocation failure.

This is a stated browser deviation from CSP 5.5's violation-URL base.
Chromium's [`ParseReportDirective`](https://github.com/chromium/chromium/blob/main/services/network/public/cpp/content_security_policy/content_security_policy.cc)
resolves endpoints against the policy's base while parsing; WebKit's
[`ContentSecurityPolicy::reportViolation`](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/csp/ContentSecurityPolicy.cpp)
uses its protected URL. Chrome and Firefox pass the blob-worker script-src
reporting assertion in aligned stable WPT revision `cc74d2669f` (2026-10-06).
Crane keeps delivery provenance rather than copying either engine's code.

**Takeaway**: **A violation's document URL, its blocked resource URL, and its report endpoint base are separate inputs. Preserve each input through inheritance instead of deriving one from another.**
