# Spec Compliance: A policy nothing delivered hid every defect behind it

**Date**: 2026-10-02
**Lesson**: Crane had a CSP library, script CSP checks and a Document CSP list for months, and no document ever had a policy in it - so every check passed, and three defects in code that looked finished stayed invisible until policies were delivered.

**Why**: Documents carried no policy container: no response's Content-Security-Policy header and no `<meta http-equiv>` ever reached `Document.csp_list` (nothing called its setter), so `isExternalScriptAllowedByCSP`, the inline check and the source matcher all ran over an empty list. The same was true of the referrer policy: a `Referrer-Policy` header and `<meta name=referrer>` changed nothing, so the 52 no-referrer/never files of referrer-policy/gen failed while the rest "passed" by tolerating a stronger referrer.

**What Happened**: Phase 2 of the secfeatures lane delivered CSP lists into policy containers. The first A/B chunk unblocked 38 content-security-policy files and broke three that had passed vacuously:
1. `parseSourceExpression` took any token with a colon not followed by `/` for a scheme-source, so `www1.web-platform.test:8000` became the scheme `www1.web-platform.test:` and matched nothing.
2. The script element's own pre-fetch check split URLs at `://`, so `blob:http://h/uuid` had the scheme `blob:http` and `blob:` in script-src never matched.
3. That pre-check never saw the integrity attribute, so hash-sources could not allow an external script (CSP 6.7.2.4).
Behind 2 and 3 was a fourth: the pre-check was a second CSP implementation. Once main fetch step 7 enforced CSP, a nonce'd script passed the pre-check and was then blocked by fetch, because no script request carried its fetch options' nonce.

**Fix**: fix the parser (a scheme-source is scheme-part ":" and nothing after); implement 6.7.2.4; put the script fetch options (nonce, integrity, parser metadata, referrer policy) on classic and module requests as HTML's "set up the classic/module script request" says, and delete the element's pre-check - "prepare the script element" checks only inline scripts; CSP 4.1.2 decides at fetch time.

**Takeaway**: **A check whose inputs are never set is not tested by the suite that passes through it. When you finally deliver the policy, budget for the defects it was hiding, and look for a second implementation of the same algorithm that the first never had to agree with.**
