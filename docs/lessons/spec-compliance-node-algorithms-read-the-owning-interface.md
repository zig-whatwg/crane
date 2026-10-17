# Spec Compliance: Node algorithms read the owning interface's fields

**Date**: 2026-10-17
**Lesson**: A Node algorithm that compares or looks up an interface-specific field must read that field from its owning interface or borrowed DOM hook.

**Why**: The generated inheritance chain does not duplicate an Element's namespace, an Attr's value, a DocumentType's name, or a ProcessingInstruction's target into Node's legacy name fields. Reading the generic fields can silently compare two absent values or return an empty string.

**What Happened**: At 740f3c1b910, Node.isEqualNode omitted attribute comparison and read names from Node. Doctype nodeName was empty, causing most createDocumentType assertions to fail even though its identifiers were stored correctly. Namespace lookup selected a Document's first child rather than its document element; a preceding comment sent the lookup back to the Document and overflowed the stack in dm2-namespace-lookup.html.

**Fix**: Route by the node's interface. Document uses documentElement, Attr uses ownerElement, other eligible nodes use parentElement, and fragments/doctypes return null. Read immutable Element names through dom.node_creation.elementNames and attributes through dom.element_attributes. Use the generated interface for other IDL fields, freeing owned DOMString results. Compare an Element's attributes by namespace, local name and value, independent of order and attribute prefix. WebKit's Node::lookupNamespaceURI and Node::isEqualNode use the same interface-specific routing (Source/WebCore/dom/Node.cpp).

**Takeaway**: **Inheritance shares algorithms, not duplicate copies of every subclass's data.**
