# Spec Compliance: IDNA validity errors are fatal after normalization

**Date**: 2026-10-11
**Lesson**: UTS #46 output strings accompany status codes; an output string is not evidence of successful ToASCII processing.

**Why**: The Unicode conformance data always gives a best-effort output, including when processing recorded errors. URL's non-strict settings disable hyphen and DNS length checks, not validity, Bidi, or ContextJ checks.

**What Happened**: Crane treated validation statuses as non-fatal and accepted hosts with disallowed characters, leading marks, invalid joiners, and invalid Unicode decoded from Punycode. Its unit harness compared best-effort output while skipping error cases, and a green run did not establish conformance. An isolated WPT case, `a\u200Cb`, demonstrated the missing rejection.

**Fix**: Read both the output and statuses in Unicode tests. Use the pinned mapping data for status: older comments incorrectly called ignored fillers disallowed. Follow URL's domain-wide ASCII shortcut, and otherwise map, normalize, split, decode and validate before Punycode encoding. Leading marks use General_Category=Mark, not nonzero combining class; ContextJ uses Joining_Type on both sides, not script ranges. UTS #46 does not enable ContextO. Check the host's forbidden code points after normalization: `<` followed by U+0338 composes to the allowed U+226E.

**Takeaway**: **A non-strict URL host still requires complete Unicode validation; verify success/failure through WPT and browser evidence.**
