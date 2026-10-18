# Spec Compliance: CSP checks belong to the state transition

**Date**: 2026-10-18

**Lesson**: Run a reporting CSP check at the algorithm step that changes state, not at a getter that exposes the result.

**Why**: A CSP check can enqueue an observable violation. Repeating it during reads changes event counts and can apply policies that did not exist when the state was created.

**What Happened**: Row 67 found that `Node.baseURI` recomputed the first base element's URL on every read. Adding `base-uri` enforcement there would have made reads report repeatedly and made a later meta policy retroactively change an accepted base. HTML instead invokes CSP inside “set the frozen base URL”, when a base mutation causes freezing. The base-state owner and the CSP owner were separate lanes.

**Fix**: Keep the policy algorithm in `csp.directives.base_uri` and document reporting in `dom.csp_violations`. Test report-only versus enforced policies, origin matching, every-policy reporting, and the document event independently. Give the base-state owner one call at the freezing step. A script regression must observe the report without reading `baseURI`, then read repeatedly and assert no additional reports.

**Takeaway**: **The location of a security check is part of its observable semantics. A correct matcher in the wrong lifecycle step is still incorrect.**
