# Architecture: A script-created parser outlives each write

**Date**: 2026-10-07
**Lesson**: document.open owns one persistent parser; document.write pumps it, and document.close supplies its explicit EOF.

**Why**: HTML 8.4 makes tokenizer state, tree construction state, and the insertion point survive write boundaries. A write boundary is temporarily missing input, not end of file.

**What Happened**: Buffering script-created writes until close made completed elements invisible to script. Parsing or replaying each chunk independently would instead lose partial tokens, recreate nodes, and execute previously parsed scripts again. Multi-character tokenizer lookahead also resolved incomplete character references and declaration prefixes as if they were complete input; CRLF preprocessing could return EOF after consuming a final suppressed LF.

**Fix**: Keep the input stream, tokenizer, tree builder, DOM adapter, and script context at stable heap addresses owned by the document. Pump that parser synchronously through each insertion point. Mark the stream complete only at close, record consumed EOF once, and let the outermost pump finish a nested close. Retain the parser through restoration of nested insertion limits. Trace parser-held DOM nodes from their document, transfer wrapped nodes out of the adapter's uninserted-node ownership, and let those edges die with the document during collector teardown. Suspend lookahead while the readable input is an unresolved prefix.

An asynchronous parser-blocking script's wait survives the end-tag callback's zero-level pause reset. Aborting first discards input, then announces interactive readiness, then drains the open-element stack without EOF, and finally announces complete readiness. Ordinary detach runs no finished-element callbacks. A parser still on a script's stack can outlive its document association; use its saved realm and document generation before removing traced edges. The removal-and-GC probe did not reproduce a crash, so that final guard is preventive ownership hardening.

The design follows WebKit [HTMLDocumentParser::insert, finish, and shouldDelayEnd](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/parser/HTMLDocumentParser.cpp), and Blink [HTMLTreeBuilder::Trace and Detach](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/parser/html_tree_builder.cc).

**Takeaway**: **A write resumes existing parser state; only explicit EOF finishes it, and reentrant callers must keep its state alive until they unwind.**

Completion also belongs to that parser: `dw-stream-reopen-readiness` showed an interactive readiness listener reopening the same Document, after which the old `close()` incorrectly marked the new parser complete. A document-local parser epoch distinguishes successive parsers even when callbacks finish the replacement before returning. Check it after interactive readiness and deferred-script execution, as WebKit's `HTMLDocumentParser::prepareToStopParsing` checks `isDetached()` after `setReadyState`.

Integration with main keeps the adapter's transient strong-root default for standalone parses. A Document-owned parser explicitly selects Document-traced edges; inheriting the transient default would keep its unreachable Document/parser/node cycle alive. A native default test and an engine-backed suspended-parser test pin both ownership modes.
