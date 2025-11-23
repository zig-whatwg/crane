// Simple V8 Bindings Test (REPL-compatible)
// Each line is a test that should evaluate to true

// Interface Constructors
typeof Element === "function"
typeof Node === "function"
typeof EventTarget === "function"
typeof Event === "function"
typeof Document === "function"
typeof HTMLElement === "function"

// Prototypes Exist
typeof Element.prototype === "object"
typeof Node.prototype === "object"
typeof EventTarget.prototype === "object"

// Prototype Chain
Element.prototype.__proto__ === Node.prototype
Node.prototype.__proto__ === EventTarget.prototype
HTMLElement.prototype.__proto__ === Element.prototype

// Constructor Properties
Element.prototype.constructor === Element
Node.prototype.constructor === Node
EventTarget.prototype.constructor === EventTarget

// Namespaces
typeof WebAssembly === "object"
typeof WebAssembly.Module === "function"
typeof WebAssembly.Instance === "function"
typeof WebAssembly.Memory === "function"
typeof WebAssembly.Table === "function"

// LegacyNamespace - No Global Pollution
typeof Module === "undefined"
typeof Instance === "undefined"
typeof Memory === "undefined"
typeof Table === "undefined"

// instanceof Function
Element instanceof Function
Node instanceof Function
Event instanceof Function
WebAssembly.Module instanceof Function

// Global Properties
"Element" in globalThis
"Node" in globalThis
"WebAssembly" in globalThis

// Prototype Descriptors
Object.getOwnPropertyDescriptor(Element, "prototype").writable === false
Object.getOwnPropertyDescriptor(Element, "prototype").enumerable === false
Object.getOwnPropertyDescriptor(Element, "prototype").configurable === false

// Non-Constructible - Should throw
(() => { try { new Element(); return false; } catch(e) { return e.message.indexOf("not constructible") >= 0 || e.message.indexOf("Illegal constructor") >= 0; } })()
(() => { try { new Node(); return false; } catch(e) { return e.message.indexOf("not constructible") >= 0 || e.message.indexOf("Illegal constructor") >= 0; } })()

// Method Existence on Prototypes (Inheritance Chain)
typeof Element.prototype.addEventListener === "function"
typeof Node.prototype.addEventListener === "function"
typeof EventTarget.prototype.addEventListener === "function"
typeof Node.prototype.appendChild === "function"
typeof Element.prototype.appendChild === "function"
typeof EventTarget.prototype.appendChild === "undefined"

// Methods are Functions
Element.prototype.addEventListener instanceof Function
Node.prototype.appendChild instanceof Function
EventTarget.prototype.dispatchEvent instanceof Function

// Method Descriptors (methods should be writable, non-enumerable, configurable)
Object.getOwnPropertyDescriptor(EventTarget.prototype, "addEventListener").writable === true
Object.getOwnPropertyDescriptor(EventTarget.prototype, "addEventListener").enumerable === false
Object.getOwnPropertyDescriptor(EventTarget.prototype, "addEventListener").configurable === true

// Inherited Methods on Derived Prototypes
typeof Element.prototype.addEventListener === "function"
typeof Element.prototype.appendChild === "function"
typeof HTMLElement.prototype.addEventListener === "function"
typeof HTMLElement.prototype.appendChild === "function"

// hasOwnProperty for Methods
EventTarget.prototype.hasOwnProperty("addEventListener") === true
Node.prototype.hasOwnProperty("appendChild") === true
Element.prototype.hasOwnProperty("addEventListener") === false
Element.prototype.hasOwnProperty("appendChild") === false

// ============================================================================
// COMPREHENSIVE PROTOTYPE CHAIN INHERITANCE TESTS
// ============================================================================

// Method Identity Through Inheritance Chain
// Methods should be the SAME function object when accessed through derived types
EventTarget.prototype.addEventListener === Node.prototype.addEventListener
EventTarget.prototype.addEventListener === Element.prototype.addEventListener
EventTarget.prototype.addEventListener === HTMLElement.prototype.addEventListener
Node.prototype.appendChild === Element.prototype.appendChild
Node.prototype.appendChild === HTMLElement.prototype.appendChild
Element.prototype.getAttribute === HTMLElement.prototype.getAttribute

// Method Location Verification (where methods are actually defined)
// EventTarget owns: addEventListener, removeEventListener, dispatchEvent
EventTarget.prototype.hasOwnProperty("addEventListener") === true
EventTarget.prototype.hasOwnProperty("removeEventListener") === true
EventTarget.prototype.hasOwnProperty("dispatchEvent") === true
Node.prototype.hasOwnProperty("addEventListener") === false
Element.prototype.hasOwnProperty("addEventListener") === false
HTMLElement.prototype.hasOwnProperty("addEventListener") === false

// Node owns: appendChild, removeChild, hasChildNodes, etc.
Node.prototype.hasOwnProperty("appendChild") === true
Node.prototype.hasOwnProperty("removeChild") === true
Node.prototype.hasOwnProperty("hasChildNodes") === true
EventTarget.prototype.hasOwnProperty("appendChild") === false
Element.prototype.hasOwnProperty("appendChild") === false
HTMLElement.prototype.hasOwnProperty("appendChild") === false

// Element owns: getAttribute, setAttribute, hasAttribute, etc.
Element.prototype.hasOwnProperty("getAttribute") === true
Element.prototype.hasOwnProperty("setAttribute") === true
Element.prototype.hasOwnProperty("hasAttribute") === true
EventTarget.prototype.hasOwnProperty("getAttribute") === false
Node.prototype.hasOwnProperty("getAttribute") === false
HTMLElement.prototype.hasOwnProperty("getAttribute") === false

// Verify methods don't exist where they shouldn't
typeof EventTarget.prototype.appendChild === "undefined"
typeof EventTarget.prototype.getAttribute === "undefined"
typeof Node.prototype.getAttribute === "undefined"

// Prototype Chain Walk - verify each level can access inherited methods
// HTMLElement should have access to all methods from Element, Node, EventTarget
typeof HTMLElement.prototype.addEventListener === "function"
typeof HTMLElement.prototype.appendChild === "function"
typeof HTMLElement.prototype.getAttribute === "function"

// Element should have access to Node and EventTarget methods
typeof Element.prototype.addEventListener === "function"
typeof Element.prototype.appendChild === "function"
typeof Element.prototype.getAttribute === "function"

// Node should have access to EventTarget methods
typeof Node.prototype.addEventListener === "function"
typeof Node.prototype.appendChild === "function"
typeof Node.prototype.getAttribute === "undefined"

// EventTarget should only have its own methods
typeof EventTarget.prototype.addEventListener === "function"
typeof EventTarget.prototype.appendChild === "undefined"
typeof EventTarget.prototype.getAttribute === "undefined"

// Method Descriptor Consistency Across Chain
// Methods defined at base should have same descriptor attributes when accessed through derived
(() => {
    const etDesc = Object.getOwnPropertyDescriptor(EventTarget.prototype, "addEventListener");
    return etDesc.writable === true && etDesc.enumerable === false && etDesc.configurable === true;
})()

// Verify derived prototypes don't redefine inherited methods
(() => {
    const nodeDesc = Object.getOwnPropertyDescriptor(Node.prototype, "addEventListener");
    return nodeDesc === undefined; // Should not be redefined on Node
})()
(() => {
    const elemDesc = Object.getOwnPropertyDescriptor(Element.prototype, "addEventListener");
    return elemDesc === undefined; // Should not be redefined on Element
})()

// in operator should find inherited methods
"addEventListener" in EventTarget.prototype
"addEventListener" in Node.prototype
"addEventListener" in Element.prototype
"addEventListener" in HTMLElement.prototype
"appendChild" in Node.prototype
"appendChild" in Element.prototype
"appendChild" in HTMLElement.prototype
!("appendChild" in EventTarget.prototype)

// Prototype chain integrity for all levels
Object.getPrototypeOf(HTMLElement.prototype) === Element.prototype
Object.getPrototypeOf(Element.prototype) === Node.prototype
Object.getPrototypeOf(Node.prototype) === EventTarget.prototype
Object.getPrototypeOf(EventTarget.prototype) === Object.prototype
Object.getPrototypeOf(Object.prototype) === null
