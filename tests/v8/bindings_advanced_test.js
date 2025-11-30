// Advanced V8 Bindings Tests
// Categories: 2-Static Constants, 3-Mixins, 4-Function Metadata, 5-Symbol.toStringTag,
//             7-Property Enumeration, 8-Namespace Behavior, 9-Frozen/Sealed, 10-Iterables

// ============================================================================
// CATEGORY 2: STATIC CONSTANTS (~15 tests)
// ============================================================================

// Node type constants exist on constructor
assert.strictEqual(Node.ELEMENT_NODE, 1, "Node.ELEMENT_NODE should be 1")
assert.strictEqual(Node.ATTRIBUTE_NODE, 2, "Node.ATTRIBUTE_NODE should be 2")
assert.strictEqual(Node.TEXT_NODE, 3, "Node.TEXT_NODE should be 3")
assert.strictEqual(Node.CDATA_SECTION_NODE, 4, "Node.CDATA_SECTION_NODE should be 4")
assert.strictEqual(Node.PROCESSING_INSTRUCTION_NODE, 7, "Node.PROCESSING_INSTRUCTION_NODE should be 7")
assert.strictEqual(Node.COMMENT_NODE, 8, "Node.COMMENT_NODE should be 8")
assert.strictEqual(Node.DOCUMENT_NODE, 9, "Node.DOCUMENT_NODE should be 9")
assert.strictEqual(Node.DOCUMENT_TYPE_NODE, 10, "Node.DOCUMENT_TYPE_NODE should be 10")
assert.strictEqual(Node.DOCUMENT_FRAGMENT_NODE, 11, "Node.DOCUMENT_FRAGMENT_NODE should be 11")

// Per WebIDL spec, constants ARE on prototype (so instances can access them)
// https://webidl.spec.whatwg.org/#interface-prototype-object
assert.strictEqual(Node.prototype.ELEMENT_NODE, 1, "Node.prototype.ELEMENT_NODE should be 1")
assert.strictEqual(Node.prototype.TEXT_NODE, 3, "Node.prototype.TEXT_NODE should be 3")
assert.strictEqual(Node.prototype.DOCUMENT_NODE, 9, "Node.prototype.DOCUMENT_NODE should be 9")

// Constants ARE accessible on derived constructors (inherited via __proto__)
// Element.__proto__ === Node, so Element inherits Node's constants
assert.strictEqual(Element.ELEMENT_NODE, 1, "Element.ELEMENT_NODE should be 1 (inherited)")
assert.strictEqual(HTMLElement.ELEMENT_NODE, 1, "HTMLElement.ELEMENT_NODE should be 1 (inherited)")

// But constants are NOT own properties of derived constructors
assert.strictEqual(Node.hasOwnProperty("ELEMENT_NODE"), true, "ELEMENT_NODE should be own property of Node")
assert.strictEqual(Element.hasOwnProperty("ELEMENT_NODE"), false, "ELEMENT_NODE should not be own property of Element")
assert.strictEqual(HTMLElement.hasOwnProperty("ELEMENT_NODE"), false, "ELEMENT_NODE should not be own property of HTMLElement")

// Constant descriptors (writable: false, enumerable: true, configurable: false)
assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(Node, "ELEMENT_NODE");
    return desc !== undefined && desc.writable === false && desc.enumerable === true && desc.configurable === false;
})(), "Node.ELEMENT_NODE descriptor should have writable:false, enumerable:true, configurable:false")

assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(Node, "TEXT_NODE");
    return desc !== undefined && desc.writable === false && desc.enumerable === true && desc.configurable === false;
})(), "Node.TEXT_NODE descriptor should have writable:false, enumerable:true, configurable:false")

assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(Node, "DOCUMENT_NODE");
    return desc !== undefined && desc.writable === false && desc.enumerable === true && desc.configurable === false;
})(), "Node.DOCUMENT_NODE descriptor should have writable:false, enumerable:true, configurable:false")

// ============================================================================
// CATEGORY 3: MIXINS (~10 tests)
// ============================================================================

// ParentNode mixin methods appear on Element
assert.isFunction(Element.prototype.querySelector, "Element.prototype.querySelector should be a function")
assert.isFunction(Element.prototype.querySelectorAll, "Element.prototype.querySelectorAll should be a function")

// ChildNode mixin methods appear on Element
assert.isFunction(Element.prototype.before, "Element.prototype.before should be a function")
assert.isFunction(Element.prototype.after, "Element.prototype.after should be a function")
assert.isFunction(Element.prototype.remove, "Element.prototype.remove should be a function")
assert.isFunction(Element.prototype.replaceWith, "Element.prototype.replaceWith should be a function")

// Mixin members are own properties (flattened, not inherited)
assert.strictEqual(Element.prototype.hasOwnProperty("querySelector"), true, "querySelector should be own property of Element.prototype")
assert.strictEqual(Element.prototype.hasOwnProperty("before"), true, "before should be own property of Element.prototype")
assert.strictEqual(Element.prototype.hasOwnProperty("remove"), true, "remove should be own property of Element.prototype")

// Mixin interfaces themselves are NOT exposed as globals
assert.strictEqual(typeof ParentNode, "undefined", "ParentNode mixin should not be exposed globally")
assert.strictEqual(typeof ChildNode, "undefined", "ChildNode mixin should not be exposed globally")
assert.strictEqual(typeof NonDocumentTypeChildNode, "undefined", "NonDocumentTypeChildNode mixin should not be exposed globally")
assert.strictEqual(typeof Slottable, "undefined", "Slottable mixin should not be exposed globally")

// Mixin methods not on Node (ParentNode is only on Element/Document)
assert.strictEqual(typeof Node.prototype.querySelector, "undefined", "Node.prototype.querySelector should be undefined")
assert.strictEqual(typeof Node.prototype.querySelectorAll, "undefined", "Node.prototype.querySelectorAll should be undefined")

// ============================================================================
// CATEGORY 4: FUNCTION METADATA (~10 tests)
// ============================================================================

// Method name property
assert.strictEqual(Element.prototype.getAttribute.name, "getAttribute", "getAttribute.name should be 'getAttribute'")
assert.strictEqual(Element.prototype.setAttribute.name, "setAttribute", "setAttribute.name should be 'setAttribute'")
assert.strictEqual(Node.prototype.appendChild.name, "appendChild", "appendChild.name should be 'appendChild'")
assert.strictEqual(EventTarget.prototype.addEventListener.name, "addEventListener", "addEventListener.name should be 'addEventListener'")

// Method length (arity) - number of required parameters
assert.strictEqual(Element.prototype.getAttribute.length, 1, "getAttribute.length should be 1")
assert.strictEqual(Element.prototype.setAttribute.length, 2, "setAttribute.length should be 2")
assert.strictEqual(Element.prototype.hasAttribute.length, 1, "hasAttribute.length should be 1")
assert.strictEqual(Node.prototype.appendChild.length, 1, "appendChild.length should be 1")
assert.strictEqual(EventTarget.prototype.addEventListener.length, 2, "addEventListener.length should be 2")

// Constructor name
assert.strictEqual(Element.name, "Element", "Element.name should be 'Element'")
assert.strictEqual(Node.name, "Node", "Node.name should be 'Node'")
assert.strictEqual(EventTarget.name, "EventTarget", "EventTarget.name should be 'EventTarget'")
assert.strictEqual(Event.name, "Event", "Event.name should be 'Event'")
assert.strictEqual(Document.name, "Document", "Document.name should be 'Document'")

// Constructor length (arity)
assert.strictEqual(Element.length, 0, "Element.length should be 0 (non-constructible)")
assert.strictEqual(Node.length, 0, "Node.length should be 0 (non-constructible)")
assert.strictEqual(EventTarget.length, 0, "EventTarget.length should be 0")

// Function.name descriptor (writable: false, enumerable: false, configurable: true)
assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(Element.prototype.getAttribute, "name");
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === true;
})(), "getAttribute.name descriptor should have writable:false, enumerable:false, configurable:true")

// Function.length descriptor (writable: false, enumerable: false, configurable: true)
assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(Element.prototype.getAttribute, "length");
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === true;
})(), "getAttribute.length descriptor should have writable:false, enumerable:false, configurable:true")

// ============================================================================
// CATEGORY 5: SYMBOL.TOSTRINGTAG (~5 tests)
// ============================================================================

// toString tag for prototypes
assert.strictEqual(Element.prototype[Symbol.toStringTag], "Element", "Element.prototype[Symbol.toStringTag] should be 'Element'")
assert.strictEqual(Node.prototype[Symbol.toStringTag], "Node", "Node.prototype[Symbol.toStringTag] should be 'Node'")
assert.strictEqual(EventTarget.prototype[Symbol.toStringTag], "EventTarget", "EventTarget.prototype[Symbol.toStringTag] should be 'EventTarget'")
assert.strictEqual(Event.prototype[Symbol.toStringTag], "Event", "Event.prototype[Symbol.toStringTag] should be 'Event'")
assert.strictEqual(Document.prototype[Symbol.toStringTag], "Document", "Document.prototype[Symbol.toStringTag] should be 'Document'")

// toString output
assert.strictEqual(Object.prototype.toString.call(Element.prototype), "[object Element]", "toString.call(Element.prototype) should be '[object Element]'")
assert.strictEqual(Object.prototype.toString.call(Node.prototype), "[object Node]", "toString.call(Node.prototype) should be '[object Node]'")
assert.strictEqual(Object.prototype.toString.call(EventTarget.prototype), "[object EventTarget]", "toString.call(EventTarget.prototype) should be '[object EventTarget]'")

// Tag descriptor (writable: false, enumerable: false, configurable: true)
assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(Element.prototype, Symbol.toStringTag);
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === true;
})(), "Element.prototype[Symbol.toStringTag] descriptor should have writable:false, enumerable:false, configurable:true")

assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(Node.prototype, Symbol.toStringTag);
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === true;
})(), "Node.prototype[Symbol.toStringTag] descriptor should have writable:false, enumerable:false, configurable:true")

// ============================================================================
// CATEGORY 7: PROPERTY ENUMERATION (~8 tests)
// ============================================================================

// Methods are non-enumerable
assert.isTrue((() => {
    const keys = [];
    for (let key in EventTarget.prototype) {
        if (EventTarget.prototype.hasOwnProperty(key)) {
            keys.push(key);
        }
    }
    return !keys.includes("addEventListener");
})(), "addEventListener should not be enumerable")

assert.isTrue((() => {
    const keys = [];
    for (let key in Node.prototype) {
        if (Node.prototype.hasOwnProperty(key)) {
            keys.push(key);
        }
    }
    return !keys.includes("appendChild");
})(), "appendChild should not be enumerable")

// Object.keys should not include non-enumerable methods
assert.strictEqual(Object.keys(EventTarget.prototype).includes("addEventListener"), false, "Object.keys should not include addEventListener")
assert.strictEqual(Object.keys(Node.prototype).includes("appendChild"), false, "Object.keys should not include appendChild")
assert.strictEqual(Object.keys(Element.prototype).includes("getAttribute"), false, "Object.keys should not include getAttribute")

// Object.getOwnPropertyNames includes non-enumerable
assert.strictEqual(Object.getOwnPropertyNames(EventTarget.prototype).includes("addEventListener"), true, "getOwnPropertyNames should include addEventListener")
assert.strictEqual(Object.getOwnPropertyNames(Node.prototype).includes("appendChild"), true, "getOwnPropertyNames should include appendChild")
assert.strictEqual(Object.getOwnPropertyNames(Element.prototype).includes("getAttribute"), true, "getOwnPropertyNames should include getAttribute")

// Inherited methods not in Object.keys of derived prototypes
assert.strictEqual(Object.keys(Element.prototype).includes("addEventListener"), false, "Object.keys(Element.prototype) should not include addEventListener")
assert.strictEqual(Object.keys(Element.prototype).includes("appendChild"), false, "Object.keys(Element.prototype) should not include appendChild")

// ============================================================================
// CATEGORY 8: NAMESPACE OBJECT BEHAVIOR (~10 tests)
// ============================================================================

// Namespaces are objects, not functions
assert.strictEqual(typeof WebAssembly, "object", "WebAssembly should be an object")
assert.isFalse(WebAssembly instanceof Function, "WebAssembly should not be instanceof Function")

// Namespaces inherit from Object.prototype
assert.strictEqual(Object.getPrototypeOf(WebAssembly), Object.prototype, "WebAssembly should inherit from Object.prototype")

// Namespace constructors are functions
assert.isFunction(WebAssembly.Module, "WebAssembly.Module should be a function")
assert.isFunction(WebAssembly.Instance, "WebAssembly.Instance should be a function")
assert.isFunction(WebAssembly.Memory, "WebAssembly.Memory should be a function")
assert.isFunction(WebAssembly.Table, "WebAssembly.Table should be a function")

// Namespace constructors inherit from Function.prototype
assert.strictEqual(Object.getPrototypeOf(WebAssembly.Module), Function.prototype, "WebAssembly.Module should inherit from Function.prototype")
assert.strictEqual(Object.getPrototypeOf(WebAssembly.Instance), Function.prototype, "WebAssembly.Instance should inherit from Function.prototype")

// Namespaces are non-extensible (per spec)
assert.strictEqual(Object.isExtensible(WebAssembly), false, "WebAssembly should be non-extensible")

// Namespace properties are non-writable, non-enumerable, non-configurable
assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(WebAssembly, "Module");
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === false;
})(), "WebAssembly.Module descriptor should have writable:false, enumerable:false, configurable:false")

assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(WebAssembly, "Instance");
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === false;
})(), "WebAssembly.Instance descriptor should have writable:false, enumerable:false, configurable:false")

// LegacyNamespace doesn't pollute global (already tested, but reinforcing)
assert.strictEqual(typeof Module, "undefined", "Module should not be in global scope")
assert.strictEqual(typeof Instance, "undefined", "Instance should not be in global scope")
assert.isFunction(WebAssembly.Module, "WebAssembly.Module should still be a function")
assert.isFunction(WebAssembly.Instance, "WebAssembly.Instance should still be a function")

// ============================================================================
// CATEGORY 9: FROZEN/SEALED OBJECTS (~5 tests)
// ============================================================================

// Prototypes should NOT be frozen
assert.strictEqual(Object.isFrozen(Element.prototype), false, "Element.prototype should not be frozen")
assert.strictEqual(Object.isFrozen(Node.prototype), false, "Node.prototype should not be frozen")
assert.strictEqual(Object.isFrozen(EventTarget.prototype), false, "EventTarget.prototype should not be frozen")

// Prototypes should be extensible
assert.strictEqual(Object.isExtensible(Element.prototype), true, "Element.prototype should be extensible")
assert.strictEqual(Object.isExtensible(Node.prototype), true, "Node.prototype should be extensible")
assert.strictEqual(Object.isExtensible(EventTarget.prototype), true, "EventTarget.prototype should be extensible")

// Prototypes should NOT be sealed
assert.strictEqual(Object.isSealed(Element.prototype), false, "Element.prototype should not be sealed")
assert.strictEqual(Object.isSealed(Node.prototype), false, "Node.prototype should not be sealed")

// Namespace objects ARE non-extensible (frozen)
assert.strictEqual(Object.isExtensible(WebAssembly), false, "WebAssembly should be non-extensible")

// Constructor.prototype property is non-writable (already tested, but important)
assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(Element, "prototype");
    return desc.writable === false;
})(), "Element.prototype property should be non-writable")

// ============================================================================
// CATEGORY 10: ITERABLES (~10 tests)
// ============================================================================

// NodeList should be iterable
assert.isFunction(NodeList.prototype[Symbol.iterator], "NodeList.prototype[Symbol.iterator] should be a function")

// DOMTokenList should be iterable
assert.isFunction(DOMTokenList.prototype[Symbol.iterator], "DOMTokenList.prototype[Symbol.iterator] should be a function")

// NOTE: HTMLCollection is NOT iterable per WHATWG DOM spec
// (spec does not declare 'iterable' for HTMLCollection, only for NodeList and DOMTokenList)
// Modern browsers may add Symbol.iterator as a convenience, but it's not spec-required

// NodeList has forEach
assert.isFunction(NodeList.prototype.forEach, "NodeList.prototype.forEach should be a function")

// DOMTokenList has forEach
assert.isFunction(DOMTokenList.prototype.forEach, "DOMTokenList.prototype.forEach should be a function")

// NodeList has item() method (indexed getter)
assert.isFunction(NodeList.prototype.item, "NodeList.prototype.item should be a function")

// HTMLCollection has item() method
assert.isFunction(HTMLCollection.prototype.item, "HTMLCollection.prototype.item should be a function")

// DOMTokenList has item() method
assert.isFunction(DOMTokenList.prototype.item, "DOMTokenList.prototype.item should be a function")

// Iterator methods are own properties
assert.strictEqual(NodeList.prototype.hasOwnProperty(Symbol.iterator), true, "Symbol.iterator should be own property of NodeList.prototype")
assert.strictEqual(DOMTokenList.prototype.hasOwnProperty(Symbol.iterator), true, "Symbol.iterator should be own property of DOMTokenList.prototype")

// Array-like length property is an accessor
assert.isTrue((() => {
    const desc = Object.getOwnPropertyDescriptor(NodeList.prototype, "length");
    return desc !== undefined && typeof desc.get === "function";
})(), "NodeList.prototype.length should be an accessor property")
