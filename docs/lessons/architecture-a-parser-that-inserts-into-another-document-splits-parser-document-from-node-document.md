# Architecture: A parser that inserts into another document splits "parser document" from "node document" - every script step that conflated them breaks

**Date**: 2026-11-18
**Lesson**: Streaming HTML parses with a private Document but inserts into the live one, so every script-processing step that read the node document where the spec says the parser document (or the reverse) silently misroutes a streamed script.

**Why**: For every document parser Crane had, a parser-inserted script's parser document WAS its node document, so `prepare the script element`, its scheduling (37.4's deferred list, 38.2's blocking-style-sheet check) and `markReadyNow`'s parser resume used whichever was at hand. HTML's streaming methods (8.5.3) give streamed scripts the stream's own Document as parser document and the live document as node document and - new - intended document.

**What Happened**: Lane blk1 built `streamHTMLUnsafe({runScripts: true})` on the existing script-created DocumentParser with a private Document. Inline scripts ran; but deferred scripts ran at once (37.4 appended them to the live document's list, which had long finished parsing), live-document style sheets blocked streamed inline scripts (38.2 asked the node document), parser-blocking scripts never resumed their parser (markReadyNow only resumed the preparation-time document's parser), and the old "parser document != preparation-time document" check refused every streamed script. Five WPT files timed out.

**Fix**:
1. Adopt the spec's intended document (prepare steps 4-5 and 19) instead of comparing the parser document with the preparation-time document.
2. Read the parser document exactly where the spec says so (37.4, 38.2), and in markReadyNow resume the script's parser document's parser when it differs.
3. Keep the parser document a raw back link (lint-refcount forbids counted references in node state), and make the owner of a Document that can die first reset it: the streaming parser holds its scripts counted and clears their link before its Document goes.

**Takeaway**: **When a new caller makes two documents that were always equal differ, grep every place either is read and check each against the spec's exact word - "parser document", "node document", "intended document", "preparation-time document" are four different things.**
