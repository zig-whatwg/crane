# Spec Compliance: Shared null defaults can hide caller semantics

**Date**: 2026-10-08
**Lesson**: Correcting an optional argument's default requires checking callers that relied on the old behavior.

**Why**: An absent serialized state and a serialized JavaScript null are distinct. HTML's URL and history update algorithm preserves state when its optional argument is absent; document.open depends on that. An intercepted navigation without classic history state nevertheless clears it in current browsers and WPT.

**What Happened**: The document.write lane corrected the shared history helper to preserve absent state and the History object's cached value. Its full sweep then changed navigate-intercept-history-state.html from one pass to zero: the interception caller passed an absent value and retained the previous string. The helper's correction exposed the caller's dependence on its old blanket null behavior.

**Fix**: Keep the shared helper's preservation semantics and pass explicit serialized null from the interception caller when it has no classic state. Record this narrow deviation from HTML commit-a-navigate-event step 7.2: Blink NavigateEvent::CommitNow and DocumentLoader::UpdateForSameDocumentNavigation, WebKit Navigation::setupInterceptionState and FrameLoader::updateURLAndHistory, and Gecko Navigation::CommitNavigateEvent and nsDocShell::UpdateURLAndHistory all install null state. WPT expressly requires it. Add separate push, replace, and explicit-state controls, and retain document.open preservation tests.

Design sources: [Blink](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/loader/document_loader.cc), [WebKit](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/loader/FrameLoader.cpp), [Gecko](https://github.com/mozilla-firefox/firefox/blob/main/docshell/base/nsDocShell.cpp).

**Takeaway**: **Keep absence and a present null distinct, and fix the caller that needs the latter instead of undoing the shared algorithm's correct default.**
