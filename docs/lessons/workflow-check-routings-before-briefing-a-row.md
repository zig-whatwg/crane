# Workflow: Check the queue's routings before briefing a row

**Date**: 2026-10-19
**Lesson**: A target list built from the blocking-files list alone hands a row files that earlier rows already routed to another owner; grep the feature queue and the earlier rows' reports for every target before writing the brief.

**Why**: The blocking list says what fails, not why or who owns it. Earlier rows and lanes record their routings (NOT-MINE with evidence, "waits on the X item") in tmp/plans/feature-queue.md and their reports, and those routings stand unless the blocker has landed.

**What Happened**: On 2026-10-19 the integrator briefed Codex rows 81-84 from generation 164's blocking list. Row 82's brief targeted blockeduri-ws-wss (held by the gr2audit ruling until w3c/webappsec-csp#735 resolves) and the four securitypolicyviolation-block-image files (SCRIPT POSITIONS, rows 67 and 78). Row 81's brief targeted ElementInternals-role and AriaMixin-element-attributes (computed accessibility and the ELEMENT-REFERENCE REFLECTION item, row 69) and customized built-ins (an engine/binding item). The liaison caught both before the rows built anything; each row's real scope was about half the brief.

**Fix**: For each target file or area in a draft brief: `grep -n '<file or area>' tmp/plans/feature-queue.md` and the reports of the earlier rows in that area; move every routed file to the brief's NOT-this-row list with its owner; and if the remainder is small, say a short row is a valid outcome.

**Takeaway**: **The blocking list says what fails; the queue says who owns it - read both before handing a row its targets.**
