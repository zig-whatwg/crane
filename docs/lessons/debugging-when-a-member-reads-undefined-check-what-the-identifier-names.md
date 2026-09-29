# Debugging: When a member reads undefined, check what the identifier names

**Date**: 2026-09-29
**Lesson**: `i.contentWindow` read `undefined` because `i` was not the iframe: Window's named getter answered an element's id with the frame's WindowProxy.

**Why**: Tests reach elements through named access on the Window all the time: `<iframe id="i">`, then `i.contentWindow`. A getter that returns null answers `null`. `undefined` means the property is not there at all, so the object in hand is not the type the test thinks it is. HTML's named objects (7.2.2.3) are, in this order of precedence:
- the document-tree child navigables whose *target name* (an iframe's `name` attribute) is the name, which give their WindowProxy;
- embed, form, img and object elements by their `name` attribute;
- HTML elements by their `id`.

An id always gives the element.

**What Happened**: Four navigation-api and html/browsers files failed three different-looking ways:
- `Cannot read properties of undefined (reading 'postMessage')`, from `fetch_tests_from_window(i.contentWindow)` in the opaque-origin files;
- a cleanup that threw, in same-hash.html's `i.contentWindow.location.hash = ""`;
- `Cannot read properties of undefined (reading 'history')`, in history_back_cross_realm_method.

The first theories were about the frames: sandboxing, opaque origins, srcdoc. A probe printed `typeof i.contentWindow` for a *plain* iframe beside a sandboxed one. Both were `"undefined"` with `null=false`, and that pointed at `i` itself. `Window.findNamedElement` returned `get_contentWindow` for any iframe, frame or object matched by id or name, and it also took `<a name>`.

**Fix**: 05d1ee6c3. An id match returns the element. The name-attribute list is embed, form, img and object. A frame is reached as a WindowProxy only through its navigable's target name, which the getter checks first.

**Takeaway**: **`undefined` from a member the interface has means the receiver is something else. Print `typeof` and `null`-ness for a control case beside the failing one before theorising about the failing case's specifics.**
