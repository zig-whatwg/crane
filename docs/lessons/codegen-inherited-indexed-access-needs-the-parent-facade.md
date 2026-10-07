# Codegen: Inherited indexed access needs the parent facade

**Date**: 2026-10-06
**Lesson**: An inherited JavaScript method does not by itself give a derived legacy platform object its indexed property behavior.

**Why**: Prototype inheritance and a legacy platform object's exotic property access are separate WebIDL mechanisms. The binding discovers indexed access through generated facade declarations.

**What Happened**: HTMLFormControlsCollection inherited HTMLCollection's `item()` on its JavaScript prototype, but its generated Zig interface did not expose `call_item`. Form-associated custom elements appeared in `form.elements.item(0)` while `form.elements[0]` was undefined. RadioNodeList had the same problem with its NodeList parent.

**Fix**: Preserve the ordinary own-member binding tables and emit aliases for inherited indexed getters and their length getter to the parent interface. Test both an inheriting collection and an overriding collection, then test brackets and live updates through script.

**Takeaway**: **Generate the facade metadata needed for exotic access even when the ordinary methods come from a prototype.**
