# Spec Compliance: An iframe name only initializes the target

**Date**: 2026-10-17
**Lesson**: Reflecting an iframe's name content attribute does not synchronize an existing navigable's target name.

**Why**: HTML 4.8.5 defines ordinary DOMString reflection for `iframe.name`. Creating a new child navigable, steps 4–6, reads that attribute to initialize its target name. Later changes to the attribute have no corresponding target-name update step.

**What Happened**: Crane's iframe name getter read a separate cached value. Its setter wrote that cache and changed the child Window's target name, but did not set the content attribute. The 38 iframe.name cases in `html/dom/reflection-embedded.html` passed only four. A new Crane case also showed `iframe.name = ...` overwriting an independently assigned `iframe.contentWindow.name`.

**Fix**: Use the existing DOMString reflection helper in both accessors. Remove the old setter's target-name synchronization and keep the creation-time initialization. Test direct attribute writes, IDL writes, removal, namespace filtering, mutation after creation and reinsertion.

`html/browsers/windows/nested-browsing-contexts/name-attribute.window.js` is the browser guard: aligned stable Chrome 155 and Safari 27 pass 24/24, Firefox 158 passes 12/24. Gecko's `nsGenericHTMLFrameElement::AfterMaybeChangeAttr` synchronizes the target name on name changes; WebKit uses a reflected name and no such update. Follow the Chrome/Safari majority, which also matches the spec. Crane already passed the attribute-mutation guard before this fix; an IDL-setter case is needed to catch the separate setter path.

**Takeaway**: **Reflection changes the attribute; only a specified lifecycle step copies that value into another object.**
