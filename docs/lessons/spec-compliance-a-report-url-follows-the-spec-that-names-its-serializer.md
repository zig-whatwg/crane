# Spec Compliance: A report's URL follows the serializer its own spec names

**Date**: 2026-11-07
**Lesson**: Crane's COEP reports serialized blockedURL with CSP's "strip URL for use in reports". That rule turns a non-HTTP(S) URL into its scheme. The COEP report steps name Fetch's "serialize a response URL for reporting" instead, which keeps every scheme's URL whole.

**Why**: CSP §5.4's strip rule is CSP's own: a violation report's blockedURL for a data: or blob: resource is just "data" or "blob". Fetch's "queue a cross-origin embedder policy CORP violation report" step 2 and HTML's "queue a cross-origin embedder policy inheritance violation" step 1 call Fetch's serializer: URL list[0], with username and password emptied and the fragment excluded. Both algorithms strip the fragment and the credentials alike for an http(s) URL. So reusing CSP's helper looked right on every HTTP report and was wrong only for local schemes.

**What Happened**: html/cross-origin-embedder-policy/block-local-documents-inheriting-none.https.html expects one "navigation" report each for data:, blob: and about:blank frames, with blockedURL set to those URLs. Once the about:blank was checked as well (lane coi2 batch 3), all three reports arrived and the file still failed: the blockedURLs were "data", "blob" and "about". Chrome passes the file 1/1. Firefox makes no COEP reports, and Safari makes 1 of the 3.

**Fix**: dom.coep_reporting.serializeResponseUrlForReporting(url_list) implements Fetch's numbered steps. Fetch's CORP report, HTML's "navigation" report and its "worker initialization" report all use it. A navigation's report passes its URL list[0], the URL it fetched first, not where its redirects ended. Every CSP and SRI report path keeps stripUrlForReports. A unit test covers data:, blob:, about:blank, https with userinfo and a fragment, and a redirected list.

**Takeaway**: **Before reusing one report type's URL helper for another, read which serializer the second report's own steps name. Two rules that agree on http(s) can still differ on data:, blob: and about:.**
