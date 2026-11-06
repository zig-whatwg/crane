# Spec Compliance: A COOP report belongs to its policy's document

**Date**: 2026-11-05
**Lesson**: An opener policy report is resolved against the endpoint list of the document the policy came from, and it is made with that document's URL. For a popup's initial about:blank document, that document is its opener, not about:blank.

**Why**: HTML 7.1.3.3's report steps end with "queue body as "coop" for coop's reporting endpoint with coopURL". That form of Reporting's queue does not exist. Reporting renamed "queue a report" to "generate and queue a report" in 2022 (w3c/reporting 334a96b9) and removed generate-a-report's optional URL on 2026-01-02 (57e73b58). The text names no endpoint list and no settings object. It also says the current enforcement result's URL is the active document's, which for a popup's initial document is about:blank.

**What Happened**: Lane coi2's first navigation reports reached the right endpoints, but `previousResponseURL` read "about:blank", and three navigation-reporting files lost a subtest each (report-only-same-origin went 1 to 0). The tests expect the opener's `location.href`, both as previousResponseURL and as the report's url. In those cases the opener's own opener policy had no endpoint, so lane coi2 had skipped the creator snapshot it otherwise takes.

**Fix**: Follow the two engines that ship the reports:
- Chromium's CrossOriginOpenerPolicyStatus reports with the opener's current URL for an initial navigation in a popup (`current_url_`, checked same origin). RenderFrameHostImpl::CreateNewWindow gives the popup's initial empty document a COOP reporter made from its creator's URL and reporting source.
- WebKit's CrossOriginOpenerPolicyEnforcementResult::from takes `openerURL`.
- Both resolve the endpoint name against the policy's document's endpoints: Chromium NetworkContext::QueueReport with a reporting source, WebKit Document::sendReportToEndpoints.

In Crane:
- dom.reporting.queueForEndpoint takes the endpoint list explicitly, and CSP's response-policy reports share it.
- An inherited opener policy carries a PolicyContainer.OpenerPolicyReporter (the creator top-level document's URL and Reporting-Endpoints).
- The navigation uses the opener's URL for a popup's initial about:blank whenever the opener's document is still same origin with it.

**Takeaway**: **A report's endpoint list and URL are the policy's document's, never the global the report is queued from, and an inherited policy keeps them from the document it came from. Check the tests' expected url before trusting a spec step whose Reporting call no longer exists.**
