// Comprehensive DOM Tests (V8 Integration)
// Tests DOM Standard implementation via JavaScript

// ============================================================================
// DOCUMENT INTERFACE TESTS (DOM Standard Section 4.6)
// ============================================================================
assert.isFunction(Document, "Document should be a function")
assert.isDefined(Document.prototype, "Document.prototype should exist")
assert.strictEqual(Document.prototype.__proto__, Node.prototype, "Document should extend Node")

// Document creation methods
assert.isFunction(Document.prototype.createElement, "Document.prototype.createElement")
assert.isFunction(Document.prototype.createTextNode, "Document.prototype.createTextNode")
assert.isFunction(Document.prototype.createComment, "Document.prototype.createComment")
assert.isFunction(Document.prototype.createDocumentFragment, "Document.prototype.createDocumentFragment")
assert.isFunction(Document.prototype.createAttribute, "Document.prototype.createAttribute")
assert.isFunction(Document.prototype.createEvent, "Document.prototype.createEvent")
assert.isFunction(Document.prototype.createRange, "Document.prototype.createRange")
assert.isFunction(Document.prototype.createNodeIterator, "Document.prototype.createNodeIterator")
assert.isFunction(Document.prototype.createTreeWalker, "Document.prototype.createTreeWalker")

// Document query methods
assert.isFunction(Document.prototype.getElementById, "Document.prototype.getElementById")
assert.isFunction(Document.prototype.getElementsByTagName, "Document.prototype.getElementsByTagName")
assert.isFunction(Document.prototype.getElementsByClassName, "Document.prototype.getElementsByClassName")
assert.isFunction(Document.prototype.querySelector, "Document.prototype.querySelector")
assert.isFunction(Document.prototype.querySelectorAll, "Document.prototype.querySelectorAll")

// Document import/adopt methods
assert.isFunction(Document.prototype.importNode, "Document.prototype.importNode")
assert.isFunction(Document.prototype.adoptNode, "Document.prototype.adoptNode")

// ============================================================================
// NODE INTERFACE TESTS (DOM Standard Section 4.5)
// ============================================================================
assert.isFunction(Node, "Node should be a function")
assert.isDefined(Node.prototype, "Node.prototype should exist")
assert.strictEqual(Node.prototype.__proto__, EventTarget.prototype, "Node should extend EventTarget")

// Node type constants
assert.strictEqual(Node.ELEMENT_NODE, 1, "Node.ELEMENT_NODE")
assert.strictEqual(Node.ATTRIBUTE_NODE, 2, "Node.ATTRIBUTE_NODE")
assert.strictEqual(Node.TEXT_NODE, 3, "Node.TEXT_NODE")
assert.strictEqual(Node.CDATA_SECTION_NODE, 4, "Node.CDATA_SECTION_NODE")
assert.strictEqual(Node.PROCESSING_INSTRUCTION_NODE, 7, "Node.PROCESSING_INSTRUCTION_NODE")
assert.strictEqual(Node.COMMENT_NODE, 8, "Node.COMMENT_NODE")
assert.strictEqual(Node.DOCUMENT_NODE, 9, "Node.DOCUMENT_NODE")
assert.strictEqual(Node.DOCUMENT_TYPE_NODE, 10, "Node.DOCUMENT_TYPE_NODE")
assert.strictEqual(Node.DOCUMENT_FRAGMENT_NODE, 11, "Node.DOCUMENT_FRAGMENT_NODE")

// Node document position constants
assert.strictEqual(Node.DOCUMENT_POSITION_DISCONNECTED, 1, "Node.DOCUMENT_POSITION_DISCONNECTED")
assert.strictEqual(Node.DOCUMENT_POSITION_PRECEDING, 2, "Node.DOCUMENT_POSITION_PRECEDING")
assert.strictEqual(Node.DOCUMENT_POSITION_FOLLOWING, 4, "Node.DOCUMENT_POSITION_FOLLOWING")
assert.strictEqual(Node.DOCUMENT_POSITION_CONTAINS, 8, "Node.DOCUMENT_POSITION_CONTAINS")
assert.strictEqual(Node.DOCUMENT_POSITION_CONTAINED_BY, 16, "Node.DOCUMENT_POSITION_CONTAINED_BY")
assert.strictEqual(Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC, 32, "Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC")

// Node methods
assert.isFunction(Node.prototype.appendChild, "Node.prototype.appendChild")
assert.isFunction(Node.prototype.insertBefore, "Node.prototype.insertBefore")
assert.isFunction(Node.prototype.removeChild, "Node.prototype.removeChild")
assert.isFunction(Node.prototype.replaceChild, "Node.prototype.replaceChild")
assert.isFunction(Node.prototype.cloneNode, "Node.prototype.cloneNode")
assert.isFunction(Node.prototype.normalize, "Node.prototype.normalize")
assert.isFunction(Node.prototype.isEqualNode, "Node.prototype.isEqualNode")
assert.isFunction(Node.prototype.isSameNode, "Node.prototype.isSameNode")
assert.isFunction(Node.prototype.compareDocumentPosition, "Node.prototype.compareDocumentPosition")
assert.isFunction(Node.prototype.contains, "Node.prototype.contains")
assert.isFunction(Node.prototype.hasChildNodes, "Node.prototype.hasChildNodes")
assert.isFunction(Node.prototype.lookupPrefix, "Node.prototype.lookupPrefix")
assert.isFunction(Node.prototype.lookupNamespaceURI, "Node.prototype.lookupNamespaceURI")
assert.isFunction(Node.prototype.isDefaultNamespace, "Node.prototype.isDefaultNamespace")

// Node properties
assert.ok("nodeType" in Node.prototype, "nodeType in Node.prototype")
assert.ok("nodeName" in Node.prototype, "nodeName in Node.prototype")
assert.ok("nodeValue" in Node.prototype, "nodeValue in Node.prototype")
assert.ok("textContent" in Node.prototype, "textContent in Node.prototype")
assert.ok("parentNode" in Node.prototype, "parentNode in Node.prototype")
assert.ok("parentElement" in Node.prototype, "parentElement in Node.prototype")
assert.ok("childNodes" in Node.prototype, "childNodes in Node.prototype")
assert.ok("firstChild" in Node.prototype, "firstChild in Node.prototype")
assert.ok("lastChild" in Node.prototype, "lastChild in Node.prototype")
assert.ok("previousSibling" in Node.prototype, "previousSibling in Node.prototype")
assert.ok("nextSibling" in Node.prototype, "nextSibling in Node.prototype")
assert.ok("ownerDocument" in Node.prototype, "ownerDocument in Node.prototype")

// ============================================================================
// ELEMENT INTERFACE TESTS (DOM Standard Section 4.10)
// ============================================================================
assert.isFunction(Element, "Element should be a function")
assert.isDefined(Element.prototype, "Element.prototype should exist")
assert.strictEqual(Element.prototype.__proto__, Node.prototype, "Element should extend Node")

// Element attribute methods
assert.isFunction(Element.prototype.getAttribute, "Element.prototype.getAttribute")
assert.isFunction(Element.prototype.getAttributeNS, "Element.prototype.getAttributeNS")
assert.isFunction(Element.prototype.setAttribute, "Element.prototype.setAttribute")
assert.isFunction(Element.prototype.setAttributeNS, "Element.prototype.setAttributeNS")
assert.isFunction(Element.prototype.removeAttribute, "Element.prototype.removeAttribute")
assert.isFunction(Element.prototype.removeAttributeNS, "Element.prototype.removeAttributeNS")
assert.isFunction(Element.prototype.hasAttribute, "Element.prototype.hasAttribute")
assert.isFunction(Element.prototype.hasAttributeNS, "Element.prototype.hasAttributeNS")
assert.isFunction(Element.prototype.toggleAttribute, "Element.prototype.toggleAttribute")
assert.isFunction(Element.prototype.getAttributeNode, "Element.prototype.getAttributeNode")
assert.isFunction(Element.prototype.setAttributeNode, "Element.prototype.setAttributeNode")
assert.isFunction(Element.prototype.removeAttributeNode, "Element.prototype.removeAttributeNode")

// Element query methods
assert.isFunction(Element.prototype.getElementsByTagName, "Element.prototype.getElementsByTagName")
assert.isFunction(Element.prototype.getElementsByTagNameNS, "Element.prototype.getElementsByTagNameNS")
assert.isFunction(Element.prototype.getElementsByClassName, "Element.prototype.getElementsByClassName")
assert.isFunction(Element.prototype.querySelector, "Element.prototype.querySelector")
assert.isFunction(Element.prototype.querySelectorAll, "Element.prototype.querySelectorAll")
assert.isFunction(Element.prototype.closest, "Element.prototype.closest")
assert.isFunction(Element.prototype.matches, "Element.prototype.matches")

// Element insertion methods
assert.isFunction(Element.prototype.insertAdjacentElement, "Element.prototype.insertAdjacentElement")
assert.isFunction(Element.prototype.insertAdjacentText, "Element.prototype.insertAdjacentText")
assert.isFunction(Element.prototype.insertAdjacentHTML, "Element.prototype.insertAdjacentHTML")

// Element properties
assert.ok("tagName" in Element.prototype, "tagName in Element.prototype")
assert.ok("id" in Element.prototype, "id in Element.prototype")
assert.ok("className" in Element.prototype, "className in Element.prototype")
assert.ok("classList" in Element.prototype, "classList in Element.prototype")
assert.ok("slot" in Element.prototype, "slot in Element.prototype")
assert.ok("attributes" in Element.prototype, "attributes in Element.prototype")
assert.ok("namespaceURI" in Element.prototype, "namespaceURI in Element.prototype")
assert.ok("prefix" in Element.prototype, "prefix in Element.prototype")
assert.ok("localName" in Element.prototype, "localName in Element.prototype")

// ============================================================================
// TEXT INTERFACE TESTS (DOM Standard Section 4.12)
// ============================================================================
assert.isFunction(Text, "Text should be a function")
assert.isDefined(Text.prototype, "Text.prototype should exist")
assert.strictEqual(Text.prototype.__proto__, CharacterData.prototype, "Text should extend CharacterData")
assert.isFunction(Text.prototype.splitText, "Text.prototype.splitText")
assert.ok("wholeText" in Text.prototype, "wholeText in Text.prototype")

// ============================================================================
// CHARACTERDATA INTERFACE TESTS (DOM Standard Section 4.11)
// ============================================================================
assert.isFunction(CharacterData, "CharacterData should be a function")
assert.isDefined(CharacterData.prototype, "CharacterData.prototype should exist")
assert.strictEqual(CharacterData.prototype.__proto__, Node.prototype, "CharacterData should extend Node")
assert.isFunction(CharacterData.prototype.substringData, "CharacterData.prototype.substringData")
assert.isFunction(CharacterData.prototype.appendData, "CharacterData.prototype.appendData")
assert.isFunction(CharacterData.prototype.insertData, "CharacterData.prototype.insertData")
assert.isFunction(CharacterData.prototype.deleteData, "CharacterData.prototype.deleteData")
assert.isFunction(CharacterData.prototype.replaceData, "CharacterData.prototype.replaceData")
assert.ok("data" in CharacterData.prototype, "data in CharacterData.prototype")
assert.ok("length" in CharacterData.prototype, "length in CharacterData.prototype")

// ============================================================================
// COMMENT INTERFACE TESTS (DOM Standard Section 4.13)
// ============================================================================
assert.isFunction(Comment, "Comment should be a function")
assert.isDefined(Comment.prototype, "Comment.prototype should exist")
assert.strictEqual(Comment.prototype.__proto__, CharacterData.prototype, "Comment should extend CharacterData")

// ============================================================================
// CDATASECTION INTERFACE TESTS (DOM Standard Section 4.14)
// ============================================================================
assert.isFunction(CDATASection, "CDATASection should be a function")
assert.isDefined(CDATASection.prototype, "CDATASection.prototype should exist")
assert.strictEqual(CDATASection.prototype.__proto__, Text.prototype, "CDATASection should extend Text")

// ============================================================================
// PROCESSINGINSTRUCTION INTERFACE TESTS (DOM Standard Section 4.15)
// ============================================================================
assert.isFunction(ProcessingInstruction, "ProcessingInstruction should be a function")
assert.isDefined(ProcessingInstruction.prototype, "ProcessingInstruction.prototype should exist")
assert.strictEqual(ProcessingInstruction.prototype.__proto__, CharacterData.prototype, "ProcessingInstruction should extend CharacterData")
assert.ok("target" in ProcessingInstruction.prototype, "target in ProcessingInstruction.prototype")

// ============================================================================
// DOCUMENTFRAGMENT INTERFACE TESTS (DOM Standard Section 4.7)
// ============================================================================
assert.isFunction(DocumentFragment, "DocumentFragment should be a function")
assert.isDefined(DocumentFragment.prototype, "DocumentFragment.prototype should exist")
assert.strictEqual(DocumentFragment.prototype.__proto__, Node.prototype, "DocumentFragment should extend Node")

// ============================================================================
// DOCUMENTTYPE INTERFACE TESTS (DOM Standard Section 4.8)
// ============================================================================
assert.isFunction(DocumentType, "DocumentType should be a function")
assert.isDefined(DocumentType.prototype, "DocumentType.prototype should exist")
assert.strictEqual(DocumentType.prototype.__proto__, Node.prototype, "DocumentType should extend Node")
assert.ok("name" in DocumentType.prototype, "name in DocumentType.prototype")
assert.ok("publicId" in DocumentType.prototype, "publicId in DocumentType.prototype")
assert.ok("systemId" in DocumentType.prototype, "systemId in DocumentType.prototype")

// ============================================================================
// ATTR INTERFACE TESTS (DOM Standard Section 4.10.2)
// ============================================================================
assert.isFunction(Attr, "Attr should be a function")
assert.isDefined(Attr.prototype, "Attr.prototype should exist")
assert.strictEqual(Attr.prototype.__proto__, Node.prototype, "Attr should extend Node")
assert.ok("namespaceURI" in Attr.prototype, "namespaceURI in Attr.prototype")
assert.ok("prefix" in Attr.prototype, "prefix in Attr.prototype")
assert.ok("localName" in Attr.prototype, "localName in Attr.prototype")
assert.ok("name" in Attr.prototype, "name in Attr.prototype")
assert.ok("value" in Attr.prototype, "value in Attr.prototype")
assert.ok("ownerElement" in Attr.prototype, "ownerElement in Attr.prototype")

// ============================================================================
// NODELIST INTERFACE TESTS (DOM Standard Section 4.3.6)
// ============================================================================
assert.isFunction(NodeList, "NodeList should be a function")
assert.isDefined(NodeList.prototype, "NodeList.prototype should exist")
assert.isFunction(NodeList.prototype.item, "NodeList.prototype.item")
assert.ok("length" in NodeList.prototype, "length in NodeList.prototype")
assert.isFunction(NodeList.prototype[Symbol.iterator], "NodeList should be iterable")
assert.isFunction(NodeList.prototype.forEach, "NodeList.prototype.forEach")
assert.isFunction(NodeList.prototype.entries, "NodeList.prototype.entries")
assert.isFunction(NodeList.prototype.keys, "NodeList.prototype.keys")
assert.isFunction(NodeList.prototype.values, "NodeList.prototype.values")

// ============================================================================
// HTMLCOLLECTION INTERFACE TESTS (DOM Standard Section 4.3.7)
// ============================================================================
assert.isFunction(HTMLCollection, "HTMLCollection should be a function")
assert.isDefined(HTMLCollection.prototype, "HTMLCollection.prototype should exist")
assert.isFunction(HTMLCollection.prototype.item, "HTMLCollection.prototype.item")
assert.isFunction(HTMLCollection.prototype.namedItem, "HTMLCollection.prototype.namedItem")
assert.ok("length" in HTMLCollection.prototype, "length in HTMLCollection.prototype")

// ============================================================================
// NAMEDNODEMAP INTERFACE TESTS (DOM Standard Section 4.10.3)
// ============================================================================
assert.isFunction(NamedNodeMap, "NamedNodeMap should be a function")
assert.isDefined(NamedNodeMap.prototype, "NamedNodeMap.prototype should exist")
assert.isFunction(NamedNodeMap.prototype.item, "NamedNodeMap.prototype.item")
assert.isFunction(NamedNodeMap.prototype.getNamedItem, "NamedNodeMap.prototype.getNamedItem")
assert.isFunction(NamedNodeMap.prototype.getNamedItemNS, "NamedNodeMap.prototype.getNamedItemNS")
assert.isFunction(NamedNodeMap.prototype.setNamedItem, "NamedNodeMap.prototype.setNamedItem")
assert.isFunction(NamedNodeMap.prototype.setNamedItemNS, "NamedNodeMap.prototype.setNamedItemNS")
assert.isFunction(NamedNodeMap.prototype.removeNamedItem, "NamedNodeMap.prototype.removeNamedItem")
assert.isFunction(NamedNodeMap.prototype.removeNamedItemNS, "NamedNodeMap.prototype.removeNamedItemNS")
assert.ok("length" in NamedNodeMap.prototype, "length in NamedNodeMap.prototype")

// ============================================================================
// DOMTOKENLIST INTERFACE TESTS (DOM Standard Section 7.1)
// ============================================================================
assert.isFunction(DOMTokenList, "DOMTokenList should be a function")
assert.isDefined(DOMTokenList.prototype, "DOMTokenList.prototype should exist")
assert.isFunction(DOMTokenList.prototype.item, "DOMTokenList.prototype.item")
assert.isFunction(DOMTokenList.prototype.contains, "DOMTokenList.prototype.contains")
assert.isFunction(DOMTokenList.prototype.add, "DOMTokenList.prototype.add")
assert.isFunction(DOMTokenList.prototype.remove, "DOMTokenList.prototype.remove")
assert.isFunction(DOMTokenList.prototype.toggle, "DOMTokenList.prototype.toggle")
assert.isFunction(DOMTokenList.prototype.replace, "DOMTokenList.prototype.replace")
assert.isFunction(DOMTokenList.prototype.supports, "DOMTokenList.prototype.supports")
assert.ok("length" in DOMTokenList.prototype, "length in DOMTokenList.prototype")
assert.ok("value" in DOMTokenList.prototype, "value in DOMTokenList.prototype")

// ============================================================================
// EVENT INTERFACE TESTS (DOM Standard Section 2)
// ============================================================================
assert.isFunction(Event, "Event should be a function")
assert.isDefined(Event.prototype, "Event.prototype should exist")
assert.strictEqual(Event.NONE, 0, "Event.NONE")
assert.strictEqual(Event.CAPTURING_PHASE, 1, "Event.CAPTURING_PHASE")
assert.strictEqual(Event.AT_TARGET, 2, "Event.AT_TARGET")
assert.strictEqual(Event.BUBBLING_PHASE, 3, "Event.BUBBLING_PHASE")
assert.isFunction(Event.prototype.stopPropagation, "Event.prototype.stopPropagation")
assert.isFunction(Event.prototype.stopImmediatePropagation, "Event.prototype.stopImmediatePropagation")
assert.isFunction(Event.prototype.preventDefault, "Event.prototype.preventDefault")
assert.isFunction(Event.prototype.composedPath, "Event.prototype.composedPath")
assert.ok("type" in Event.prototype, "type in Event.prototype")
assert.ok("target" in Event.prototype, "target in Event.prototype")
assert.ok("currentTarget" in Event.prototype, "currentTarget in Event.prototype")
assert.ok("eventPhase" in Event.prototype, "eventPhase in Event.prototype")
assert.ok("bubbles" in Event.prototype, "bubbles in Event.prototype")
assert.ok("cancelable" in Event.prototype, "cancelable in Event.prototype")
assert.ok("defaultPrevented" in Event.prototype, "defaultPrevented in Event.prototype")
assert.ok("composed" in Event.prototype, "composed in Event.prototype")
assert.ok("isTrusted" in Event.prototype, "isTrusted in Event.prototype")
assert.ok("timeStamp" in Event.prototype, "timeStamp in Event.prototype")

// ============================================================================
// CUSTOMEVENT INTERFACE TESTS (DOM Standard Section 2.3)
// ============================================================================
assert.isFunction(CustomEvent, "CustomEvent should be a function")
assert.isDefined(CustomEvent.prototype, "CustomEvent.prototype should exist")
assert.strictEqual(CustomEvent.prototype.__proto__, Event.prototype, "CustomEvent should extend Event")
assert.ok("detail" in CustomEvent.prototype, "detail in CustomEvent.prototype")

// ============================================================================
// EVENTTARGET INTERFACE TESTS (DOM Standard Section 2.8)
// ============================================================================
assert.isFunction(EventTarget, "EventTarget should be a function")
assert.isDefined(EventTarget.prototype, "EventTarget.prototype should exist")
assert.isFunction(EventTarget.prototype.addEventListener, "EventTarget.prototype.addEventListener")
assert.isFunction(EventTarget.prototype.removeEventListener, "EventTarget.prototype.removeEventListener")
assert.isFunction(EventTarget.prototype.dispatchEvent, "EventTarget.prototype.dispatchEvent")

// ============================================================================
// ABORTSIGNAL INTERFACE TESTS (DOM Standard Section 3.1)
// ============================================================================
assert.isFunction(AbortSignal, "AbortSignal should be a function")
assert.isDefined(AbortSignal.prototype, "AbortSignal.prototype should exist")
assert.strictEqual(AbortSignal.prototype.__proto__, EventTarget.prototype, "AbortSignal should extend EventTarget")
assert.isFunction(AbortSignal.abort, "AbortSignal.abort static method")
assert.isFunction(AbortSignal.timeout, "AbortSignal.timeout static method")
assert.ok("aborted" in AbortSignal.prototype, "aborted in AbortSignal.prototype")
assert.ok("reason" in AbortSignal.prototype, "reason in AbortSignal.prototype")
assert.isFunction(AbortSignal.prototype.throwIfAborted, "AbortSignal.prototype.throwIfAborted")

// ============================================================================
// ABORTCONTROLLER INTERFACE TESTS (DOM Standard Section 3.2)
// ============================================================================
assert.isFunction(AbortController, "AbortController should be a function")
assert.isDefined(AbortController.prototype, "AbortController.prototype should exist")
assert.ok("signal" in AbortController.prototype, "signal in AbortController.prototype")
assert.isFunction(AbortController.prototype.abort, "AbortController.prototype.abort")

// ============================================================================
// RANGE INTERFACE TESTS (DOM Standard Section 5)
// ============================================================================
assert.isFunction(Range, "Range should be a function")
assert.isDefined(Range.prototype, "Range.prototype should exist")
assert.strictEqual(Range.START_TO_START, 0, "Range.START_TO_START")
assert.strictEqual(Range.START_TO_END, 1, "Range.START_TO_END")
assert.strictEqual(Range.END_TO_END, 2, "Range.END_TO_END")
assert.strictEqual(Range.END_TO_START, 3, "Range.END_TO_START")
assert.isFunction(Range.prototype.setStart, "Range.prototype.setStart")
assert.isFunction(Range.prototype.setEnd, "Range.prototype.setEnd")
assert.isFunction(Range.prototype.setStartBefore, "Range.prototype.setStartBefore")
assert.isFunction(Range.prototype.setStartAfter, "Range.prototype.setStartAfter")
assert.isFunction(Range.prototype.setEndBefore, "Range.prototype.setEndBefore")
assert.isFunction(Range.prototype.setEndAfter, "Range.prototype.setEndAfter")
assert.isFunction(Range.prototype.collapse, "Range.prototype.collapse")
assert.isFunction(Range.prototype.selectNode, "Range.prototype.selectNode")
assert.isFunction(Range.prototype.selectNodeContents, "Range.prototype.selectNodeContents")
assert.isFunction(Range.prototype.compareBoundaryPoints, "Range.prototype.compareBoundaryPoints")
assert.isFunction(Range.prototype.comparePoint, "Range.prototype.comparePoint")
assert.isFunction(Range.prototype.intersectsNode, "Range.prototype.intersectsNode")
assert.isFunction(Range.prototype.isPointInRange, "Range.prototype.isPointInRange")
assert.isFunction(Range.prototype.deleteContents, "Range.prototype.deleteContents")
assert.isFunction(Range.prototype.extractContents, "Range.prototype.extractContents")
assert.isFunction(Range.prototype.cloneContents, "Range.prototype.cloneContents")
assert.isFunction(Range.prototype.insertNode, "Range.prototype.insertNode")
assert.isFunction(Range.prototype.surroundContents, "Range.prototype.surroundContents")
assert.isFunction(Range.prototype.cloneRange, "Range.prototype.cloneRange")
assert.isFunction(Range.prototype.detach, "Range.prototype.detach")
assert.isFunction(Range.prototype.toString, "Range.prototype.toString")
assert.ok("startContainer" in Range.prototype, "startContainer in Range.prototype")
assert.ok("startOffset" in Range.prototype, "startOffset in Range.prototype")
assert.ok("endContainer" in Range.prototype, "endContainer in Range.prototype")
assert.ok("endOffset" in Range.prototype, "endOffset in Range.prototype")
assert.ok("collapsed" in Range.prototype, "collapsed in Range.prototype")
assert.ok("commonAncestorContainer" in Range.prototype, "commonAncestorContainer in Range.prototype")

// ============================================================================
// NODEITERATOR INTERFACE TESTS (DOM Standard Section 6)
// ============================================================================
assert.isFunction(NodeIterator, "NodeIterator should be a function")
assert.isDefined(NodeIterator.prototype, "NodeIterator.prototype should exist")
assert.isFunction(NodeIterator.prototype.nextNode, "NodeIterator.prototype.nextNode")
assert.isFunction(NodeIterator.prototype.previousNode, "NodeIterator.prototype.previousNode")
assert.isFunction(NodeIterator.prototype.detach, "NodeIterator.prototype.detach")
assert.ok("root" in NodeIterator.prototype, "root in NodeIterator.prototype")
assert.ok("referenceNode" in NodeIterator.prototype, "referenceNode in NodeIterator.prototype")
assert.ok("pointerBeforeReferenceNode" in NodeIterator.prototype, "pointerBeforeReferenceNode in NodeIterator.prototype")
assert.ok("whatToShow" in NodeIterator.prototype, "whatToShow in NodeIterator.prototype")
assert.ok("filter" in NodeIterator.prototype, "filter in NodeIterator.prototype")

// ============================================================================
// TREEWALKER INTERFACE TESTS (DOM Standard Section 6)
// ============================================================================
assert.isFunction(TreeWalker, "TreeWalker should be a function")
assert.isDefined(TreeWalker.prototype, "TreeWalker.prototype should exist")
assert.isFunction(TreeWalker.prototype.parentNode, "TreeWalker.prototype.parentNode")
assert.isFunction(TreeWalker.prototype.firstChild, "TreeWalker.prototype.firstChild")
assert.isFunction(TreeWalker.prototype.lastChild, "TreeWalker.prototype.lastChild")
assert.isFunction(TreeWalker.prototype.previousSibling, "TreeWalker.prototype.previousSibling")
assert.isFunction(TreeWalker.prototype.nextSibling, "TreeWalker.prototype.nextSibling")
assert.isFunction(TreeWalker.prototype.previousNode, "TreeWalker.prototype.previousNode")
assert.isFunction(TreeWalker.prototype.nextNode, "TreeWalker.prototype.nextNode")
assert.ok("root" in TreeWalker.prototype, "root in TreeWalker.prototype")
assert.ok("whatToShow" in TreeWalker.prototype, "whatToShow in TreeWalker.prototype")
assert.ok("filter" in TreeWalker.prototype, "filter in TreeWalker.prototype")
assert.ok("currentNode" in TreeWalker.prototype, "currentNode in TreeWalker.prototype")

// ============================================================================
// NODEFILTER INTERFACE TESTS (DOM Standard Section 6.1)
// ============================================================================
assert.ok(typeof NodeFilter === "object" || typeof NodeFilter === "function", "NodeFilter should exist")
assert.strictEqual(NodeFilter.FILTER_ACCEPT, 1, "NodeFilter.FILTER_ACCEPT")
assert.strictEqual(NodeFilter.FILTER_REJECT, 2, "NodeFilter.FILTER_REJECT")
assert.strictEqual(NodeFilter.FILTER_SKIP, 3, "NodeFilter.FILTER_SKIP")
assert.strictEqual(NodeFilter.SHOW_ALL, 0xFFFFFFFF, "NodeFilter.SHOW_ALL")
assert.strictEqual(NodeFilter.SHOW_ELEMENT, 0x1, "NodeFilter.SHOW_ELEMENT")
assert.strictEqual(NodeFilter.SHOW_ATTRIBUTE, 0x2, "NodeFilter.SHOW_ATTRIBUTE")
assert.strictEqual(NodeFilter.SHOW_TEXT, 0x4, "NodeFilter.SHOW_TEXT")
assert.strictEqual(NodeFilter.SHOW_CDATA_SECTION, 0x8, "NodeFilter.SHOW_CDATA_SECTION")
assert.strictEqual(NodeFilter.SHOW_PROCESSING_INSTRUCTION, 0x40, "NodeFilter.SHOW_PROCESSING_INSTRUCTION")
assert.strictEqual(NodeFilter.SHOW_COMMENT, 0x80, "NodeFilter.SHOW_COMMENT")
assert.strictEqual(NodeFilter.SHOW_DOCUMENT, 0x100, "NodeFilter.SHOW_DOCUMENT")
assert.strictEqual(NodeFilter.SHOW_DOCUMENT_TYPE, 0x200, "NodeFilter.SHOW_DOCUMENT_TYPE")
assert.strictEqual(NodeFilter.SHOW_DOCUMENT_FRAGMENT, 0x400, "NodeFilter.SHOW_DOCUMENT_FRAGMENT")

// ============================================================================
// MUTATIONOBSERVER INTERFACE TESTS (DOM Standard Section 4.4)
// ============================================================================
assert.isFunction(MutationObserver, "MutationObserver should be a function")
assert.isDefined(MutationObserver.prototype, "MutationObserver.prototype should exist")
assert.isFunction(MutationObserver.prototype.observe, "MutationObserver.prototype.observe")
assert.isFunction(MutationObserver.prototype.disconnect, "MutationObserver.prototype.disconnect")
assert.isFunction(MutationObserver.prototype.takeRecords, "MutationObserver.prototype.takeRecords")

// ============================================================================
// MUTATIONRECORD INTERFACE TESTS (DOM Standard Section 4.4.2)
// ============================================================================
assert.isFunction(MutationRecord, "MutationRecord should be a function")
assert.isDefined(MutationRecord.prototype, "MutationRecord.prototype should exist")
assert.ok("type" in MutationRecord.prototype, "type in MutationRecord.prototype")
assert.ok("target" in MutationRecord.prototype, "target in MutationRecord.prototype")
assert.ok("addedNodes" in MutationRecord.prototype, "addedNodes in MutationRecord.prototype")
assert.ok("removedNodes" in MutationRecord.prototype, "removedNodes in MutationRecord.prototype")
assert.ok("previousSibling" in MutationRecord.prototype, "previousSibling in MutationRecord.prototype")
assert.ok("nextSibling" in MutationRecord.prototype, "nextSibling in MutationRecord.prototype")
assert.ok("attributeName" in MutationRecord.prototype, "attributeName in MutationRecord.prototype")
assert.ok("attributeNamespace" in MutationRecord.prototype, "attributeNamespace in MutationRecord.prototype")
assert.ok("oldValue" in MutationRecord.prototype, "oldValue in MutationRecord.prototype")

// ============================================================================
// SHADOWROOT INTERFACE TESTS (DOM Standard Section 4.9)
// ============================================================================
assert.isFunction(ShadowRoot, "ShadowRoot should be a function")
assert.isDefined(ShadowRoot.prototype, "ShadowRoot.prototype should exist")
assert.strictEqual(ShadowRoot.prototype.__proto__, DocumentFragment.prototype, "ShadowRoot should extend DocumentFragment")
assert.ok("mode" in ShadowRoot.prototype, "mode in ShadowRoot.prototype")
assert.ok("host" in ShadowRoot.prototype, "host in ShadowRoot.prototype")
assert.ok("delegatesFocus" in ShadowRoot.prototype, "delegatesFocus in ShadowRoot.prototype")
assert.ok("slotAssignment" in ShadowRoot.prototype, "slotAssignment in ShadowRoot.prototype")
assert.isFunction(Element.prototype.attachShadow, "Element.prototype.attachShadow")
assert.ok("shadowRoot" in Element.prototype, "shadowRoot in Element.prototype")

// ============================================================================
// HTMLSLOTELEMENT INTERFACE TESTS (DOM Standard Slots)
// ============================================================================
assert.isFunction(HTMLSlotElement, "HTMLSlotElement should be a function")
assert.isDefined(HTMLSlotElement.prototype, "HTMLSlotElement.prototype should exist")
assert.strictEqual(HTMLSlotElement.prototype.__proto__, HTMLElement.prototype, "HTMLSlotElement should extend HTMLElement")
assert.isFunction(HTMLSlotElement.prototype.assignedNodes, "HTMLSlotElement.prototype.assignedNodes")
assert.isFunction(HTMLSlotElement.prototype.assignedElements, "HTMLSlotElement.prototype.assignedElements")
assert.isFunction(HTMLSlotElement.prototype.assign, "HTMLSlotElement.prototype.assign")
assert.ok("name" in HTMLSlotElement.prototype, "name in HTMLSlotElement.prototype")

// ============================================================================
// DOMIMPLEMENTATION INTERFACE TESTS (DOM Standard Section 4.6.2)
// ============================================================================
assert.isFunction(DOMImplementation, "DOMImplementation should be a function")
assert.isDefined(DOMImplementation.prototype, "DOMImplementation.prototype should exist")
assert.isFunction(DOMImplementation.prototype.createDocumentType, "DOMImplementation.prototype.createDocumentType")
assert.isFunction(DOMImplementation.prototype.createDocument, "DOMImplementation.prototype.createDocument")
assert.isFunction(DOMImplementation.prototype.createHTMLDocument, "DOMImplementation.prototype.createHTMLDocument")
assert.isFunction(DOMImplementation.prototype.hasFeature, "DOMImplementation.prototype.hasFeature")

// ============================================================================
// PARENTNODE MIXIN TESTS (DOM Standard Section 4.3.3)
// ============================================================================
assert.isFunction(Element.prototype.prepend, "Element.prototype.prepend")
assert.isFunction(Element.prototype.append, "Element.prototype.append")
assert.isFunction(Element.prototype.replaceChildren, "Element.prototype.replaceChildren")
assert.ok("children" in Element.prototype, "children in Element.prototype")
assert.ok("firstElementChild" in Element.prototype, "firstElementChild in Element.prototype")
assert.ok("lastElementChild" in Element.prototype, "lastElementChild in Element.prototype")
assert.ok("childElementCount" in Element.prototype, "childElementCount in Element.prototype")
assert.isFunction(Document.prototype.prepend, "Document.prototype.prepend")
assert.isFunction(Document.prototype.append, "Document.prototype.append")
assert.isFunction(Document.prototype.replaceChildren, "Document.prototype.replaceChildren")
assert.isFunction(DocumentFragment.prototype.prepend, "DocumentFragment.prototype.prepend")
assert.isFunction(DocumentFragment.prototype.append, "DocumentFragment.prototype.append")
assert.isFunction(DocumentFragment.prototype.replaceChildren, "DocumentFragment.prototype.replaceChildren")

// ============================================================================
// CHILDNODE MIXIN TESTS (DOM Standard Section 4.3.4)
// ============================================================================
assert.isFunction(Element.prototype.before, "Element.prototype.before")
assert.isFunction(Element.prototype.after, "Element.prototype.after")
assert.isFunction(Element.prototype.replaceWith, "Element.prototype.replaceWith")
assert.isFunction(Element.prototype.remove, "Element.prototype.remove")
assert.isFunction(CharacterData.prototype.before, "CharacterData.prototype.before")
assert.isFunction(CharacterData.prototype.after, "CharacterData.prototype.after")
assert.isFunction(CharacterData.prototype.replaceWith, "CharacterData.prototype.replaceWith")
assert.isFunction(CharacterData.prototype.remove, "CharacterData.prototype.remove")
assert.isFunction(DocumentType.prototype.before, "DocumentType.prototype.before")
assert.isFunction(DocumentType.prototype.after, "DocumentType.prototype.after")
assert.isFunction(DocumentType.prototype.replaceWith, "DocumentType.prototype.replaceWith")
assert.isFunction(DocumentType.prototype.remove, "DocumentType.prototype.remove")

// ============================================================================
// NONDOCUMENTTYPECHILDNODE MIXIN TESTS (DOM Standard Section 4.3.5)
// ============================================================================
assert.ok("previousElementSibling" in Element.prototype, "previousElementSibling in Element.prototype")
assert.ok("nextElementSibling" in Element.prototype, "nextElementSibling in Element.prototype")
assert.ok("previousElementSibling" in CharacterData.prototype, "previousElementSibling in CharacterData.prototype")
assert.ok("nextElementSibling" in CharacterData.prototype, "nextElementSibling in CharacterData.prototype")

// ============================================================================
// SLOTTABLE MIXIN TESTS (DOM Standard Slots)
// ============================================================================
assert.ok("assignedSlot" in Element.prototype, "assignedSlot in Element.prototype")
assert.ok("assignedSlot" in Text.prototype, "assignedSlot in Text.prototype")

// ============================================================================
// HTMLELEMENT INTERFACE TESTS (HTML Standard)
// ============================================================================
assert.isFunction(HTMLElement, "HTMLElement should be a function")
assert.isDefined(HTMLElement.prototype, "HTMLElement.prototype should exist")
assert.strictEqual(HTMLElement.prototype.__proto__, Element.prototype, "HTMLElement should extend Element")
assert.ok("title" in HTMLElement.prototype, "title in HTMLElement.prototype")
assert.ok("lang" in HTMLElement.prototype, "lang in HTMLElement.prototype")
assert.ok("translate" in HTMLElement.prototype, "translate in HTMLElement.prototype")
assert.ok("dir" in HTMLElement.prototype, "dir in HTMLElement.prototype")
assert.ok("hidden" in HTMLElement.prototype, "hidden in HTMLElement.prototype")
assert.ok("tabIndex" in HTMLElement.prototype, "tabIndex in HTMLElement.prototype")
assert.ok("draggable" in HTMLElement.prototype, "draggable in HTMLElement.prototype")
assert.ok("contentEditable" in HTMLElement.prototype, "contentEditable in HTMLElement.prototype")
assert.ok("isContentEditable" in HTMLElement.prototype, "isContentEditable in HTMLElement.prototype")
assert.ok("spellcheck" in HTMLElement.prototype, "spellcheck in HTMLElement.prototype")
assert.isFunction(HTMLElement.prototype.click, "HTMLElement.prototype.click")
assert.isFunction(HTMLElement.prototype.focus, "HTMLElement.prototype.focus")
assert.isFunction(HTMLElement.prototype.blur, "HTMLElement.prototype.blur")

// ============================================================================
// XPATH TESTS (DOM Standard XPath)
// ============================================================================
assert.ok(typeof XPathResult === "function" || typeof XPathResult === "object", "XPathResult should exist")
assert.strictEqual(XPathResult.ANY_TYPE, 0, "XPathResult.ANY_TYPE")
assert.strictEqual(XPathResult.NUMBER_TYPE, 1, "XPathResult.NUMBER_TYPE")
assert.strictEqual(XPathResult.STRING_TYPE, 2, "XPathResult.STRING_TYPE")
assert.strictEqual(XPathResult.BOOLEAN_TYPE, 3, "XPathResult.BOOLEAN_TYPE")
assert.strictEqual(XPathResult.UNORDERED_NODE_ITERATOR_TYPE, 4, "XPathResult.UNORDERED_NODE_ITERATOR_TYPE")
assert.strictEqual(XPathResult.ORDERED_NODE_ITERATOR_TYPE, 5, "XPathResult.ORDERED_NODE_ITERATOR_TYPE")
assert.strictEqual(XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE, 6, "XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE")
assert.strictEqual(XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, 7, "XPathResult.ORDERED_NODE_SNAPSHOT_TYPE")
assert.strictEqual(XPathResult.ANY_UNORDERED_NODE_TYPE, 8, "XPathResult.ANY_UNORDERED_NODE_TYPE")
assert.strictEqual(XPathResult.FIRST_ORDERED_NODE_TYPE, 9, "XPathResult.FIRST_ORDERED_NODE_TYPE")
assert.isFunction(XPathEvaluator, "XPathEvaluator should be a function")
assert.isFunction(Document.prototype.evaluate, "Document.prototype.evaluate")
assert.isFunction(Document.prototype.createExpression, "Document.prototype.createExpression")
assert.isFunction(Document.prototype.createNSResolver, "Document.prototype.createNSResolver")

// ============================================================================
// INHERITANCE CHAIN VERIFICATION
// ============================================================================
assert.strictEqual(HTMLElement.prototype.__proto__, Element.prototype, "HTMLElement extends Element")
assert.strictEqual(Element.prototype.__proto__, Node.prototype, "Element extends Node")
assert.strictEqual(Node.prototype.__proto__, EventTarget.prototype, "Node extends EventTarget")
assert.strictEqual(EventTarget.prototype.__proto__, Object.prototype, "EventTarget extends Object")
assert.strictEqual(Text.prototype.__proto__, CharacterData.prototype, "Text extends CharacterData")
assert.strictEqual(CharacterData.prototype.__proto__, Node.prototype, "CharacterData extends Node")
assert.strictEqual(Comment.prototype.__proto__, CharacterData.prototype, "Comment extends CharacterData")
assert.strictEqual(CDATASection.prototype.__proto__, Text.prototype, "CDATASection extends Text")
assert.strictEqual(ProcessingInstruction.prototype.__proto__, CharacterData.prototype, "ProcessingInstruction extends CharacterData")
assert.strictEqual(Document.prototype.__proto__, Node.prototype, "Document extends Node")
assert.strictEqual(DocumentFragment.prototype.__proto__, Node.prototype, "DocumentFragment extends Node")
assert.strictEqual(DocumentType.prototype.__proto__, Node.prototype, "DocumentType extends Node")
assert.strictEqual(Attr.prototype.__proto__, Node.prototype, "Attr extends Node")
assert.strictEqual(ShadowRoot.prototype.__proto__, DocumentFragment.prototype, "ShadowRoot extends DocumentFragment")
assert.strictEqual(CustomEvent.prototype.__proto__, Event.prototype, "CustomEvent extends Event")
assert.strictEqual(AbortSignal.prototype.__proto__, EventTarget.prototype, "AbortSignal extends EventTarget")

// ============================================================================
// NON-CONSTRUCTIBLE INTERFACE TESTS
// ============================================================================
assert.throws(function() { new Node(); }, null, "new Node() should throw")
assert.throws(function() { new Element(); }, null, "new Element() should throw")
assert.throws(function() { new CharacterData(); }, null, "new CharacterData() should throw")
assert.throws(function() { new NodeList(); }, null, "new NodeList() should throw")
assert.throws(function() { new HTMLCollection(); }, null, "new HTMLCollection() should throw")
assert.throws(function() { new NamedNodeMap(); }, null, "new NamedNodeMap() should throw")
assert.throws(function() { new MutationRecord(); }, null, "new MutationRecord() should throw")
assert.throws(function() { new ShadowRoot(); }, null, "new ShadowRoot() should throw")

// ============================================================================
// CONSTRUCTIBLE INTERFACE TESTS
// ============================================================================
assert.doesNotThrow(function() { new Event("test"); }, "new Event() should work")
assert.doesNotThrow(function() { new CustomEvent("test"); }, "new CustomEvent() should work")
assert.doesNotThrow(function() { new EventTarget(); }, "new EventTarget() should work")
assert.doesNotThrow(function() { new AbortController(); }, "new AbortController() should work")
assert.doesNotThrow(function() { new MutationObserver(function() {}); }, "new MutationObserver() should work")
assert.doesNotThrow(function() { new Range(); }, "new Range() should work")
assert.doesNotThrow(function() { new Text(); }, "new Text() should work")
assert.doesNotThrow(function() { new Text("hello"); }, "new Text('hello') should work")
assert.doesNotThrow(function() { new Comment(); }, "new Comment() should work")
assert.doesNotThrow(function() { new Comment("comment"); }, "new Comment('comment') should work")
assert.doesNotThrow(function() { new DocumentFragment(); }, "new DocumentFragment() should work")

// ============================================================================
// PROPERTY DESCRIPTOR TESTS
// ============================================================================
var nodeProtoDesc = Object.getOwnPropertyDescriptor(Node, "prototype")
assert.strictEqual(nodeProtoDesc.writable, false, "Node.prototype should not be writable")
assert.strictEqual(nodeProtoDesc.enumerable, false, "Node.prototype should not be enumerable")
assert.strictEqual(nodeProtoDesc.configurable, false, "Node.prototype should not be configurable")

var appendChildDesc = Object.getOwnPropertyDescriptor(Node.prototype, "appendChild")
assert.strictEqual(appendChildDesc.writable, true, "appendChild should be writable")
assert.strictEqual(appendChildDesc.enumerable, false, "appendChild should not be enumerable")
assert.strictEqual(appendChildDesc.configurable, true, "appendChild should be configurable")

// ============================================================================
// METHOD IDENTITY THROUGH INHERITANCE
// ============================================================================
assert.strictEqual(EventTarget.prototype.addEventListener, Node.prototype.addEventListener, "addEventListener same on EventTarget and Node")
assert.strictEqual(EventTarget.prototype.addEventListener, Element.prototype.addEventListener, "addEventListener same on EventTarget and Element")
assert.strictEqual(EventTarget.prototype.addEventListener, HTMLElement.prototype.addEventListener, "addEventListener same on EventTarget and HTMLElement")
assert.strictEqual(Node.prototype.appendChild, Element.prototype.appendChild, "appendChild same on Node and Element")
assert.strictEqual(Node.prototype.appendChild, HTMLElement.prototype.appendChild, "appendChild same on Node and HTMLElement")
assert.strictEqual(CharacterData.prototype.appendData, Text.prototype.appendData, "appendData same on CharacterData and Text")
assert.strictEqual(CharacterData.prototype.appendData, Comment.prototype.appendData, "appendData same on CharacterData and Comment")

// ============================================================================
// HASOWNPROPERTY TESTS
// ============================================================================
assert.ok(EventTarget.prototype.hasOwnProperty("addEventListener"), "EventTarget owns addEventListener")
assert.ok(!Node.prototype.hasOwnProperty("addEventListener"), "Node does not own addEventListener")
assert.ok(!Element.prototype.hasOwnProperty("addEventListener"), "Element does not own addEventListener")
assert.ok(Node.prototype.hasOwnProperty("appendChild"), "Node owns appendChild")
assert.ok(!Element.prototype.hasOwnProperty("appendChild"), "Element does not own appendChild")
assert.ok(CharacterData.prototype.hasOwnProperty("appendData"), "CharacterData owns appendData")
assert.ok(!Text.prototype.hasOwnProperty("appendData"), "Text does not own appendData")
assert.ok(Text.prototype.hasOwnProperty("splitText"), "Text owns splitText")
assert.ok(!CharacterData.prototype.hasOwnProperty("splitText"), "CharacterData does not own splitText")

// ============================================================================
// DOCUMENT CONSTRUCTOR TESTS
// ============================================================================
assert.doesNotThrow(function() { new Document(); }, "new Document() should work")

var testDoc = new Document()
assert.isFunction(testDoc.createElement, "Document instance has createElement")
assert.isFunction(testDoc.createTextNode, "Document instance has createTextNode")
assert.isFunction(testDoc.createComment, "Document instance has createComment")
assert.isFunction(testDoc.createDocumentFragment, "Document instance has createDocumentFragment")
assert.isFunction(testDoc.querySelector, "Document instance has querySelector")
assert.isFunction(testDoc.querySelectorAll, "Document instance has querySelectorAll")
assert.isFunction(testDoc.getElementById, "Document instance has getElementById")
assert.isFunction(testDoc.getElementsByTagName, "Document instance has getElementsByTagName")
assert.isFunction(testDoc.getElementsByClassName, "Document instance has getElementsByClassName")

assert.ok("URL" in testDoc, "URL in Document instance")
assert.ok("documentURI" in testDoc, "documentURI in Document instance")
assert.ok("compatMode" in testDoc, "compatMode in Document instance")
assert.ok("characterSet" in testDoc, "characterSet in Document instance")
assert.ok("contentType" in testDoc, "contentType in Document instance")
assert.ok("doctype" in testDoc, "doctype in Document instance")
assert.ok("documentElement" in testDoc, "documentElement in Document instance")
assert.ok("body" in testDoc, "body in Document instance")
assert.ok("head" in testDoc, "head in Document instance")
assert.ok("title" in testDoc, "title in Document instance")
assert.ok("readyState" in testDoc, "readyState in Document instance")

// ============================================================================
// QUERYSELECTOR TESTS
// ============================================================================
assert.isFunction(Document.prototype.querySelector, "Document.prototype.querySelector")
assert.isFunction(Document.prototype.querySelectorAll, "Document.prototype.querySelectorAll")
assert.isFunction(Element.prototype.querySelector, "Element.prototype.querySelector")
assert.isFunction(Element.prototype.querySelectorAll, "Element.prototype.querySelectorAll")
assert.isFunction(DocumentFragment.prototype.querySelector, "DocumentFragment.prototype.querySelector")
assert.isFunction(DocumentFragment.prototype.querySelectorAll, "DocumentFragment.prototype.querySelectorAll")
assert.ok("querySelector" in Document.prototype, "querySelector in Document.prototype")
assert.ok("querySelectorAll" in Document.prototype, "querySelectorAll in Document.prototype")
assert.ok("querySelector" in Element.prototype, "querySelector in Element.prototype")
assert.ok("querySelectorAll" in Element.prototype, "querySelectorAll in Element.prototype")
assert.ok("querySelector" in DocumentFragment.prototype, "querySelector in DocumentFragment.prototype")
assert.ok("querySelectorAll" in DocumentFragment.prototype, "querySelectorAll in DocumentFragment.prototype")

// ============================================================================
// QUERYSELECTOR FUNCTIONAL TESTS
// ============================================================================
var funcDoc = new Document()
var funcDiv = funcDoc.createElement("div")
assert.isNotNull(funcDiv, "createElement should return non-null")
assert.ok(funcDiv.tagName === "DIV" || funcDiv.tagName === "div", "tagName should be DIV or div")

// Invalid selector throws error
assert.throws(function() { funcDoc.querySelector("[[[invalid"); }, null, "Invalid selector should throw")
