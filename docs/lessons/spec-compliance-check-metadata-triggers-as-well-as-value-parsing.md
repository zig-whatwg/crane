# Spec Compliance: Check metadata triggers as well as value parsing

**Date**: 2026-10-18
**Lesson**: Browser evidence for a metadata value must include the events that update it.

**Why**: Matching a browser's language-string storage does not establish when that string changes. Insertion, attribute mutation and removal can have different rules.

**What Happened**: HTML's content-language pragma text has long described insertion processing and whitespace-token extraction. Blink and WebKit store the raw value and also reprocess connected content/http-equiv mutations. Gecko's HTMLMetaElement::BindToTree invokes ProcessMETATag, while AfterSetAttr handles other metadata and does not rerun that pragma. The insertion-only wording was already present in the 2021 HTML source, so this was a long-standing browser split, not a newer specification awaiting implementation.

**Fix**: Follow the approved majority using the existing per-meta attribute callback, after namespace/name and brand checks. Process only content-language, retain the Document-owned value after removal, and ignore detached attribute changes until reinsertion. Keep source-only behavior evidence in native tests until browser-run or WPT evidence supports a Crane fixture. Preserve explicit lang precedence and test the unset default.

**Takeaway**: **Check both the metadata algorithm and its update triggers against the relevant specification history and engine mechanisms.**

Sources: [Blink HTMLMetaElement](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/html_meta_element.cc), [WebKit HTMLMetaElement](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLMetaElement.cpp), [Gecko HTMLMetaElement](https://github.com/mozilla-firefox/firefox/blob/main/dom/html/HTMLMetaElement.cpp), [HTML in 2021](https://github.com/whatwg/html/blob/53bc3803433e1c817918b83e8a84f3db900031dd/source).
