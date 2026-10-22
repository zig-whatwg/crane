# Testing: XML Runner Metadata Needs the XML Byte Stream

**Date**: 2026-10-21
**Lesson**: XML test metadata must use expanded XML names, the document's encoding, and its DTD entity rules.

**Why**: A file suffix selects a test format; the HTTP response's MIME type selects document parsing. An HTML substring search cannot recognize an XHTML-namespace meta element inside SVG, ignore fake markup inside CDATA, or decode a UTF-16 source.

**What Happened**: The WPT runner rejected every .xhtml/.xht/.svg/.xml input despite the browser already supporting XML navigation. An initial XML metadata reader handled the corpus's variants but missed legal UTF-16 and windows-1252 metadata, XHTML entities, and unsupported declarations. Allocation-failure testing also found a duplicated variant string leaked when its list append failed.

**Fix**: Recognize XML source formats in discovery and explicit-file arguments, then navigate the original HTTP response. Read metadata with the engine-free XML parser. Share the existing byte decoder and entity table through graph modules, without importing HTML core's DOM and fetch dependencies into harness tests. Assert variant-to-manifest equality over the corpus and test allocation failures independently of that corpus.

**Takeaway**: **Corpus parity proves today's files; encoded and namespace-aware fixtures prove the format. Keep response MIME routing separate from metadata extraction.**
