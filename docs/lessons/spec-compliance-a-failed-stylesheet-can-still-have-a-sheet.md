# Spec Compliance: A failed stylesheet can still have a sheet

**Date**: 2026-10-18

**Lesson**: CSSOM association and permission to apply a response's CSS are separate outcomes.

**Why**: A link can fire `error` and retain an empty stylesheet. Returning before sheet creation loses an observable object even when rejecting the response body is correct.

**What Happened**: `content-security-policy/style-src/style-allowed.sub.html` requested a missing `resources/blue.css` and checked only that `document.styleSheets` contained a sheet. All three browsers passed, while Crane returned before delivering any sheet. A native loopback test confirmed that a successful response and a CSP block behaved correctly, but an allowed HTTP 404 fired `error` with `link.sheet === null`.

**Fix**: For a link's own non-OK HTTP response, deliver empty contents through the existing stylesheet hook, preserve the response's origin-clean flag, and retain the error event. Never parse the failed response's body. CSP blocks, network errors, integrity failures, and import processing keep their existing paths. Use a real 200 CSS resource as a control and a 404 response containing valid CSS to prove that the failed body is not applied.

This follows the browser rule for an old spec disagreement: HTML already gated sheet creation on success in [December 2019](https://github.com/whatwg/html/blob/5b42943aa88e5c79c8afd75c904eb99d1b061066/source). [Blink's LinkStyle::NotifyFinished](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/loader/link_style.cc) and [WebKit's HTMLLinkElement::setCSSStyleSheet](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLLinkElement.cpp) create the sheet before validating its contents. [Gecko's Loader::LoadStyleLink](https://github.com/mozilla/gecko-dev/blob/master/layout/style/Loader.cpp) likewise associates a sheet before its later HTTP-status check.

**Takeaway**: **Rejecting CSS bytes does not necessarily remove the CSSOM sheet.**
