# Spec Compliance: Browsers find a meta charset with the tokenizer, not the spec's byte prescan

**Date**: 2026-11-19
**Lesson**: Chrome, Firefox and Safari decide a document's encoding with a tokenizer-based meta scan that reads past 1024 bytes while the head lasts, never sees a meta in a script's text, decodes character references - and no later meta changes the encoding.

**Why**: HTML §13.2.3.2's "prescan a byte stream" skips tags byte by byte and stops at 1024 bytes, and the tree builder's "change the encoding" honours a meta found later. Blink and WebKit instead run HTMLMetaCharsetParser::CheckForMetaCharset - the HTML tokenizer over the bytes read as windows-1252, switching to raw text after script/style/title, going on while only head-ish tags (script, noscript, style, link, meta, object, title, base, and html/head start tags) were seen or until 1024 characters are consumed - and have no late path. Firefox implements whatwg/html#6962 (open), which agrees on every html/syntax/charset/ case. XHR document responses use the same scan.

**What Happened**: Crane ran the spec's byte prescan and switched encodings in place for a late meta: html/syntax/charset with-inheritance, without-inheritance and xhr.html failed 21 majority-pass subtests (in-script, in-title, after-head-after-1kb ... read as windows-1251; after-1kb, ncr read as UTF-8 by XHR), and xmldecl-2's declarations whose ">" is the 1025th byte were ignored (Blink's CheckForXMLCharset waits for the ">" however far). The first scanner also hung a unit test: Crane's tokenizer emits an end-of-file token in every state but data, and again at each call after it, so a token loop that waits for null never ends on a cut-off tag.

**Fix**: src/html/parser/meta_charset_scan.zig (html_core: it needs the tokenizer) - an incremental Scanner over an InputStreamManager that suspends at the end of what arrived; encoding_sniffing.sniff takes its result as `Inputs.prescanned`; the navigation parser waits for the scan to decide instead of for 1024 bytes; the tree builder's change-the-encoding hook is gone (a stated deviation in the "in head" meta step).

**Takeaway**: **For encoding sniffing, model HTMLMetaCharsetParser (tokenizer, head section or 1024 characters, no late change), not the spec's byte prescan - and any loop over Crane's tokenizer must stop at `.eof` as well as at null.**
