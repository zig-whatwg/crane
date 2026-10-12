# Spec Compliance: An XML error document is the browsers', not the spec's

**Date**: 2026-10-12
**Lesson**: Where WPT asserts the spec's shape and two of the three browsers fail that assertion the same way, implement the majority's shape and list the subtests it costs as expected failures. Do not count them as work left.

**Why**: HTML's DOMParser.parseFromString step 4 says a well-formedness error yields a document holding only `<parsererror xmlns="http://www.mozilla.org/newlayout/xml/parsererror.xml">`, and step 3 says the result is "a new Document". Firefox does the first. Chrome and Safari keep the tree built up to the error and insert an XHTML block (`<parsererror style=...><h3>This page contains the following errors:</h3><div>error on line L at column C: ...</div><h3>Below is a rendering of the page up to the first error.</h3></parsererror>`) as the document element's first child. Both engines do this in XMLErrors::insertErrorMessageBlock. All three browsers make an XMLDocument. WPT's domparsing/DOMParser-parseFromString-xml.html and DOMParser-xml-character-entities.html assert the spec's shape and interface.

**What Happened**: Lane xmlparse (2026-10-12) wrote the XML parser. wpt.fyi (cc74d2669f) showed the following:
- Chrome and Safari fail the 8 "Should return an error document ..." subtests; Firefox passes them.
- All three browsers fail the 8 "XMLDocument interface for ... parsed document" subtests.
- All three pass DOMParser-parseFromString-xml-parsererror.html. It only counts `getElementsByTagName("parsererror")`, so either shape passes it.

Golden rule 2 decided both questions (the integrator confirmed the 2-1 split): Crane builds the majority's error block and makes XMLDocuments. That leaves 16 subtests failing on purpose. Implementing the spec's shape would have passed 8 more subtests and broken pages written for Chrome and Safari, which read the partial tree.

**Fix**: Check wpt.fyi for every WPT assertion that shapes an observable result before writing to it (tmp scratch: per-test JSON at storage.googleapis.com/wptd/<sha>/<run>/<path>). Put the shape in one function (`xml_document_parser.insertErrorMessageBlock`), with a comment that cites the engines' functions and the subtests it costs. Name those subtests in the lane handoff as expected failures.

**Takeaway**: **A WPT subtest that the browsers fail together tests the spec, not the web. Follow the browsers, and record what that costs.**
