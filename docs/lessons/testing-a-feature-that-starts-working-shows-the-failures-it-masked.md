# Testing: A feature that starts working shows the failures it masked

**Date**: 2026-10-12
**Lesson**: When a missing feature starts working, re-read the failure messages of its files before scoping out what still fails. A bug outside the feature may now account for most of the remainder, and it may be a one-line fix.

**Why**: A sizing pass attributes failures by their message. dom/nodes/Document-createElementNS.html runs every case in an HTML document, an XML iframe and an XHTML iframe. With no XML parser, the two iframes' cases failed at "Dummy XML document didn't load" (390). Those were counted as the parser's. The HTML-document cases failed at `element.nodeValue === null` (83), and those were counted as someone else's.

**What Happened**: Lane xmlparse loaded the iframes and the file went from 117 to 335 passing out of 596. The remaining failures were not the parser's. 249 of them were one assertion, "expected (object) null but got (string) """: Node.nodeValue returned "" for elements and documents. Once the iframes loaded, the XML and XHTML documents' cases reached the same assertion, so it now failed in all three variants. DOMImplementation-createDocument.html failed 110 times on it as well. tagName had a similar bug: it uppercased elements in no namespace and elements in XML documents. That bug surfaced only once XML documents existed. Both were fixed in a few lines each.

**Fix**: After the first A/B, group each top file's remaining failures by message (the result streams, journal.shard*.wptreport.jsonl). For each large group, ask whether it is the feature's own failure or one the feature had kept hidden.

**Takeaway**: **Unblocking moves a file's failures onto the next bug in its path. Count them again before calling the rest out of scope.**
