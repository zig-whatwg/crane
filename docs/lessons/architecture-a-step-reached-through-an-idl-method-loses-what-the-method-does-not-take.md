# Architecture: A step reached through an IDL method loses what the method does not take

**Date**: 2026-10-05
**Lesson**: Hyperlinks and forms whose target named no frame reached "a new top-level traversable" by calling `window.open(url, name, features)` through the interface. That made the navigation window.open's own: a form's POST body, the link's referrer policy, its source element and user involvement were all dropped.

**Why**: HTML "the rules for choosing a navigable" makes (or finds) the navigable; "navigate" then runs with everything the hyperlink or form passes. `window.open` is a different algorithm that happens to contain both steps. Its IDL signature has no place for a POST resource or a source element, so calling it as a shortcut silently narrows the navigation to what a script's `open()` can express.

**What Happened**: form-submission-target/form-target-request-header.html timed out. A form posted to "_blank" arrived at the server as a GET with no Content-Type, and the helper never answered. The same path also skipped popups found by name whenever noopener was set: the link's `rel=noreferrer` became the "noopener" feature string.

**Fix**: Window, which keeps the popups a page opened, installs `dom.auxiliary_navigables.chooseTopLevel`. It picks an open popup of the page's browsing context group by name, or makes a new top-level traversable the way window.open does. HTMLIFrameElement then calls `navigate()` on the chosen navigable with the full request (10766ef0f8).

**Takeaway**: **Do not reach a spec step by calling the public API that happens to wrap it: the API's signature is a filter. Expose the step itself (a hook), and keep the caller's full set of inputs.**
