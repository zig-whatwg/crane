# Spec Compliance: Share HTTP date parsing with source metadata

**Date**: 2026-10-18
**Lesson**: Document source timestamps should use Fetch's shared HTTP-date parser, with signed epoch arithmetic and checked conversion to the platform timestamp.

**Why**: HTTP recipients must accept IMF-fixdate, rfc850-date and asctime-date (RFC 9110 §5.6.7). A parser tested only with a modern IMF-fixdate can silently mishandle older dates and leave a second caller tempted to add its own parser.

**What Happened**: Crane's cache parser counted years forward from 1970, so `Wed, 31 Dec 1969 23:59:59 GMT` became 31,535,999 seconds instead of -1. It also accepted invalid calendar fields and omitted the two obsolete formats. Wiring it directly to XHR's lastModified would have preserved the WPT defect. Native regressions reproduced these failures, including CacheEntry creation and revalidation.

**Fix**: Repair the parser in its Fetch owner and retain the cache's epoch-seconds API. Supply the current UTC time to a pure entry point for deterministic RFC850 fifty-year boundary tests, including century crossings. Validate real calendar dates and clock fields, then use signed Gregorian arithmetic. A checked WallTime conversion returns null for out-of-range dates; the HTML getter follows its unknown-source rule. Browser weekday tolerance is explicit: WebKit ignores weekday consistency, and Blink and Gecko normalize it through PR_ParseTimeString. The tests still reject unknown weekday names.

**Takeaway**: **Reuse the protocol parser and test its existing callers; make narrower timestamp conversions explicit and checked.**
