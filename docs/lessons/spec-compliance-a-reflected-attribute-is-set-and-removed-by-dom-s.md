# Spec Compliance: A reflected attribute is set and removed by DOM's algorithms, not by setAttribute

**Date**: 2026-10-12
**Lesson**: HTML's reflection sets a content attribute with DOM "set an attribute value" and deletes it with "remove an attribute by namespace and local name" given null; calling the `setAttribute` / `removeAttribute` IDL members instead is a different algorithm and nests a [CEReactions] scope.

**Why**: HTML 2.6.1 defines a reflected target's "set the content attribute" as "Set an attribute value given element, the reflected content attribute name, and value", and "delete the content attribute" as "Remove an attribute by namespace and local name given null, the reflected content attribute name, and element". `removeAttribute(name)` is DOM "remove an attribute by NAME": the first attribute whose QUALIFIED name is `name`, and an attribute set with `setAttributeNS("urn:x", "download", ...)` has the qualified name "download" too - so it can remove the namespaced attribute and leave the one reflection names. And the generated `interfaces.Element.call_setAttribute` / `call_removeAttribute` are [CEReactions]: each opens and closes its own reaction scope (interfaces/Element.zig), so reactions run inside the outer setter's algorithm instead of when its own scope ends. Blink opens the scope only in the bindings (`CEReactionsScope` in the V8 callback); its internal `setAttribute(QualifiedName)` / `removeAttribute(QualifiedName)` open none.

**What Happened**: Impls boundary B4 moved Element's attribute storage into `dom.element_data` and its writes behind `dom.element_attributes`. The anchor's and area's reflect setters called `interfaces.Element.call_setAttribute` and `ElementImpl.call_removeAttribute`, and the details element's exclusivity step called `ElementImpl.call_removeAttributeNS` - all IDL members reached from inside another algorithm. HTMLElement's and the script elements' helpers already used the DOM algorithms. They now all call `dom.element_attributes.set` ("set an attribute value") and `dom.element_attributes.remove` ("remove an attribute by namespace and local name"). About 27 `interfaces.Element.call_setAttribute` and 3 `call_removeAttribute` calls remain inside other impls' algorithms (`grep -rn 'interfaces.Element.call_setAttribute(' src/webidl/impls`), outside this batch.

**Fix**:
1. A reflected setter: `try dom.element_attributes.set(element, name, value, .{})`.
2. A boolean's false branch, or "delete the content attribute": `dom.element_attributes.remove(element, null, name)`.
3. A read: `dom.element_data.getAttributeByNamespaceAndLocalName(data, null, name)` on `dom.element_data.of(element)`, borrowing the value.
4. Never the [CEReactions] IDL member from inside another algorithm (tmp/plans/impls-boundary-design.md 3.1).

**Takeaway**: **"Set / delete the content attribute" are DOM's set-an-attribute-value and remove-by-namespace-and-local-name: an algorithm calls the algorithm, never setAttribute or removeAttribute.**
