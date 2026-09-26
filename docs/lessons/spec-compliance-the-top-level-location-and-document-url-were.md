# Spec Compliance: The top-level `Location` and `document.URL` were never set

**Date**: 2026-09-22
**Lesson**: In every top-level test page `location.href` read `"about:blank"`,
`location.pathname` `"blank"`, `location.search` `""`, and `document.URL` `""`.

**Why**: `Context.zig` creates the window's Location at context init, and
`Location.init` parses `about:blank` into it; nothing ever updated it on
navigation (`Context.setUrl` ends in `_ = self.location_instance;`). Only
iframes called `Location.setURLFromString`. `document.URL` read
`Document.InternalState.url`, which the parser never set; the navigation
recorded its URL in the context entry (`context_manager.setDocumentUrl`) and
that is where it stayed - XHR read it from there, the DOM did not.

**What Happened**: it hid in plain sight because nothing threw. Two costs
were measured before anyone looked at the value: (1) every
`<meta name="variant">` file ran ALL of its tests on every variant, because
`/common/subset-tests.js` reads `location.search` to pick its slice - a
24-variant encoding file reported 554,328 subtests for 23,097 declared and
cost 2,615s of wall clock; (2) the progress report's "subtests passing" was
inflated 12x by the same fan-out. Every test deriving a URL from
`location.href` was running against nothing.

**Fix**: spec-shaped, no new impls-boundary calls. HTML §7.10.1: a Location's
url is its relevant Document's URL - so `Location.getURL` refreshes from
`interfaces.Window.get_document` -> `interfaces.Document.get_URL` (re-parsing
only when the string changes; the getter clones into the DOCUMENT's context
allocator, free it with that). HTML "create and initialize a Document object":
the document's URL is the navigation's, so a document that HAS a default view
takes the URL the context recorded (`instance.ctx.getEngineContextAs` -
its own context, not the current one, so `iframe.contentDocument.URL` is the
iframe's). A document with no view (createHTMLDocument, DOMParser) keeps its
own. Probe `tests/wpt/crane/location-probe.html?probe=1`: 0/4 -> 4/4.

**Takeaway**: **Probe the values a whole class of tests depends on before
reading their failures.** One four-line test page answered what a 2,000-file
scoreboard could not: the tests were not failing, they were never asked the
question.
