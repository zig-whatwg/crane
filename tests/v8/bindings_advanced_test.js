// Advanced V8 Bindings Tests
// Categories: 2-Static Constants, 3-Mixins, 4-Function Metadata, 5-Symbol.toStringTag,
//             7-Property Enumeration, 8-Namespace Behavior, 9-Frozen/Sealed, 10-Iterables

// ============================================================================
// CATEGORY 2: STATIC CONSTANTS (~15 tests)
// ============================================================================

// Node type constants exist on constructor
Node.ELEMENT_NODE === 1
Node.ATTRIBUTE_NODE === 2
Node.TEXT_NODE === 3
Node.CDATA_SECTION_NODE === 4
Node.PROCESSING_INSTRUCTION_NODE === 7
Node.COMMENT_NODE === 8
Node.DOCUMENT_NODE === 9
Node.DOCUMENT_TYPE_NODE === 10
Node.DOCUMENT_FRAGMENT_NODE === 11

// Constants are NOT on prototype
typeof Node.prototype.ELEMENT_NODE === "undefined"
typeof Node.prototype.TEXT_NODE === "undefined"
typeof Node.prototype.DOCUMENT_NODE === "undefined"

// Constants are NOT on derived constructors (not inherited)
typeof Element.ELEMENT_NODE === "undefined"
typeof HTMLElement.ELEMENT_NODE === "undefined"

// Constants are on the base constructor only
Node.hasOwnProperty("ELEMENT_NODE") === true
Element.hasOwnProperty("ELEMENT_NODE") === false
HTMLElement.hasOwnProperty("ELEMENT_NODE") === false

// Constant descriptors (writable: false, enumerable: true, configurable: false)
(() => {
    const desc = Object.getOwnPropertyDescriptor(Node, "ELEMENT_NODE");
    return desc !== undefined && desc.writable === false && desc.enumerable === true && desc.configurable === false;
})()

(() => {
    const desc = Object.getOwnPropertyDescriptor(Node, "TEXT_NODE");
    return desc !== undefined && desc.writable === false && desc.enumerable === true && desc.configurable === false;
})()

(() => {
    const desc = Object.getOwnPropertyDescriptor(Node, "DOCUMENT_NODE");
    return desc !== undefined && desc.writable === false && desc.enumerable === true && desc.configurable === false;
})()

// ============================================================================
// CATEGORY 3: MIXINS (~10 tests)
// ============================================================================

// ParentNode mixin methods appear on Element
typeof Element.prototype.querySelector === "function"
typeof Element.prototype.querySelectorAll === "function"

// ChildNode mixin methods appear on Element
typeof Element.prototype.before === "function"
typeof Element.prototype.after === "function"
typeof Element.prototype.remove === "function"
typeof Element.prototype.replaceWith === "function"

// Mixin members are own properties (flattened, not inherited)
Element.prototype.hasOwnProperty("querySelector") === true
Element.prototype.hasOwnProperty("before") === true
Element.prototype.hasOwnProperty("remove") === true

// Mixin interfaces themselves are NOT exposed as globals
typeof ParentNode === "undefined"
typeof ChildNode === "undefined"
typeof NonDocumentTypeChildNode === "undefined"
typeof Slottable === "undefined"

// Mixin methods not on Node (ParentNode is only on Element/Document)
typeof Node.prototype.querySelector === "undefined"
typeof Node.prototype.querySelectorAll === "undefined"

// ============================================================================
// CATEGORY 4: FUNCTION METADATA (~10 tests)
// ============================================================================

// Method name property
Element.prototype.getAttribute.name === "getAttribute"
Element.prototype.setAttribute.name === "setAttribute"
Node.prototype.appendChild.name === "appendChild"
EventTarget.prototype.addEventListener.name === "addEventListener"

// Method length (arity) - number of required parameters
Element.prototype.getAttribute.length === 1  // getAttribute(qualifiedName)
Element.prototype.setAttribute.length === 2  // setAttribute(qualifiedName, value)
Element.prototype.hasAttribute.length === 1  // hasAttribute(qualifiedName)
Node.prototype.appendChild.length === 1  // appendChild(node)
EventTarget.prototype.addEventListener.length === 2  // addEventListener(type, listener)

// Constructor name
Element.name === "Element"
Node.name === "Node"
EventTarget.name === "EventTarget"
Event.name === "Event"
Document.name === "Document"

// Constructor length (arity)
Element.length === 0  // Non-constructible
Node.length === 0  // Non-constructible
EventTarget.length === 0  // Constructible with no required args

// Function.name descriptor (writable: false, enumerable: false, configurable: true)
(() => {
    const desc = Object.getOwnPropertyDescriptor(Element.prototype.getAttribute, "name");
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === true;
})()

// Function.length descriptor (writable: false, enumerable: false, configurable: true)
(() => {
    const desc = Object.getOwnPropertyDescriptor(Element.prototype.getAttribute, "length");
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === true;
})()

// ============================================================================
// CATEGORY 5: SYMBOL.TOSTRINGTAG (~5 tests)
// ============================================================================

// toString tag for prototypes
Element.prototype[Symbol.toStringTag] === "Element"
Node.prototype[Symbol.toStringTag] === "Node"
EventTarget.prototype[Symbol.toStringTag] === "EventTarget"
Event.prototype[Symbol.toStringTag] === "Event"
Document.prototype[Symbol.toStringTag] === "Document"

// toString output
Object.prototype.toString.call(Element.prototype) === "[object Element]"
Object.prototype.toString.call(Node.prototype) === "[object Node]"
Object.prototype.toString.call(EventTarget.prototype) === "[object EventTarget]"

// Tag descriptor (writable: false, enumerable: false, configurable: true)
(() => {
    const desc = Object.getOwnPropertyDescriptor(Element.prototype, Symbol.toStringTag);
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === true;
})()

(() => {
    const desc = Object.getOwnPropertyDescriptor(Node.prototype, Symbol.toStringTag);
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === true;
})()

// ============================================================================
// CATEGORY 7: PROPERTY ENUMERATION (~8 tests)
// ============================================================================

// Methods are non-enumerable
(() => {
    const keys = [];
    for (let key in EventTarget.prototype) {
        if (EventTarget.prototype.hasOwnProperty(key)) {
            keys.push(key);
        }
    }
    return !keys.includes("addEventListener");
})()

(() => {
    const keys = [];
    for (let key in Node.prototype) {
        if (Node.prototype.hasOwnProperty(key)) {
            keys.push(key);
        }
    }
    return !keys.includes("appendChild");
})()

// Object.keys should not include non-enumerable methods
Object.keys(EventTarget.prototype).includes("addEventListener") === false
Object.keys(Node.prototype).includes("appendChild") === false
Object.keys(Element.prototype).includes("getAttribute") === false

// Object.getOwnPropertyNames includes non-enumerable
Object.getOwnPropertyNames(EventTarget.prototype).includes("addEventListener") === true
Object.getOwnPropertyNames(Node.prototype).includes("appendChild") === true
Object.getOwnPropertyNames(Element.prototype).includes("getAttribute") === true

// Inherited methods not in Object.keys of derived prototypes
Object.keys(Element.prototype).includes("addEventListener") === false
Object.keys(Element.prototype).includes("appendChild") === false

// ============================================================================
// CATEGORY 8: NAMESPACE OBJECT BEHAVIOR (~10 tests)
// ============================================================================

// Namespaces are objects, not functions
typeof WebAssembly === "object"
!(WebAssembly instanceof Function)

// Namespaces inherit from Object.prototype
Object.getPrototypeOf(WebAssembly) === Object.prototype

// Namespace constructors are functions
typeof WebAssembly.Module === "function"
typeof WebAssembly.Instance === "function"
typeof WebAssembly.Memory === "function"
typeof WebAssembly.Table === "function"

// Namespace constructors inherit from Function.prototype
Object.getPrototypeOf(WebAssembly.Module) === Function.prototype
Object.getPrototypeOf(WebAssembly.Instance) === Function.prototype

// Namespaces are non-extensible (per spec)
Object.isExtensible(WebAssembly) === false

// Namespace properties are non-writable, non-enumerable, non-configurable
(() => {
    const desc = Object.getOwnPropertyDescriptor(WebAssembly, "Module");
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === false;
})()

(() => {
    const desc = Object.getOwnPropertyDescriptor(WebAssembly, "Instance");
    return desc !== undefined && desc.writable === false && desc.enumerable === false && desc.configurable === false;
})()

// LegacyNamespace doesn't pollute global (already tested, but reinforcing)
typeof Module === "undefined"
typeof Instance === "undefined"
typeof WebAssembly.Module === "function"
typeof WebAssembly.Instance === "function"

// ============================================================================
// CATEGORY 9: FROZEN/SEALED OBJECTS (~5 tests)
// ============================================================================

// Prototypes should NOT be frozen
Object.isFrozen(Element.prototype) === false
Object.isFrozen(Node.prototype) === false
Object.isFrozen(EventTarget.prototype) === false

// Prototypes should be extensible
Object.isExtensible(Element.prototype) === true
Object.isExtensible(Node.prototype) === true
Object.isExtensible(EventTarget.prototype) === true

// Prototypes should NOT be sealed
Object.isSealed(Element.prototype) === false
Object.isSealed(Node.prototype) === false

// Namespace objects ARE non-extensible (frozen)
Object.isExtensible(WebAssembly) === false

// Constructor.prototype property is non-writable (already tested, but important)
(() => {
    const desc = Object.getOwnPropertyDescriptor(Element, "prototype");
    return desc.writable === false;
})()

// ============================================================================
// CATEGORY 10: ITERABLES (~10 tests)
// ============================================================================

// NodeList should be iterable
typeof NodeList.prototype[Symbol.iterator] === "function"

// DOMTokenList should be iterable
typeof DOMTokenList.prototype[Symbol.iterator] === "function"

// NOTE: HTMLCollection is NOT iterable per WHATWG DOM spec
// (spec does not declare 'iterable' for HTMLCollection, only for NodeList and DOMTokenList)
// Modern browsers may add Symbol.iterator as a convenience, but it's not spec-required

// NodeList has forEach
typeof NodeList.prototype.forEach === "function"

// DOMTokenList has forEach
typeof DOMTokenList.prototype.forEach === "function"

// NodeList has item() method (indexed getter)
typeof NodeList.prototype.item === "function"

// HTMLCollection has item() method
typeof HTMLCollection.prototype.item === "function"

// DOMTokenList has item() method
typeof DOMTokenList.prototype.item === "function"

// Iterator methods are own properties
NodeList.prototype.hasOwnProperty(Symbol.iterator) === true
DOMTokenList.prototype.hasOwnProperty(Symbol.iterator) === true

// Array-like length property is an accessor
(() => {
    const desc = Object.getOwnPropertyDescriptor(NodeList.prototype, "length");
    return desc !== undefined && typeof desc.get === "function";
})()
