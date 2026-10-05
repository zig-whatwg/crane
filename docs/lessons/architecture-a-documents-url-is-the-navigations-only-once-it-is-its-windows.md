# Architecture: A document's URL is the navigation's only once it is its window's document

**Date**: 2026-10-04
**Lesson**: The Refresh header's shared declarative refresh steps ran as the frame's new document was made - before Window.setDocument linked it - and silently did nothing: an unlinked document's URL is about:blank, so the header's relative URL ("./refreshed.txt") failed to parse, the steps returned before setting "will declaratively refresh", and the body's meta refresh won.

**Why**: Document.get_URL reads the navigation's URL from the realm's record only when the document has a default view; until then it answers about:blank (DOM's default for createHTMLDocument's documents). "Create and initialize a Document object" makes the document with its URL; Crane gives it the URL by linking it to its window. Anything in the commit that resolves a URL against the new document must run after the link.

**What Happened**: navigation batch 6 added step 17 (the Refresh header) beside giveReferrer and givePolicyContainer, which need no URL. refresh/navigate.window.js stayed a TIMEOUT; the Crane test nav6-refresh-header.html failed with the meta's URL. Reading get_URL found the default-view condition.

**Fix**: 8f0bc3e2eb - giveRefresh runs after the window link in parseHtmlForIframe, still before the parser.

**Takeaway**: **In a frame commit, steps that read the new document's URL (or its base URL) go after the document is its window's; the ones that only store state can go before.**
