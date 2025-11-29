// V8 Bindings Test - WebIDL interface bindings verification
// Tests prototype chains, constructors, method inheritance

// ============================================================================
// Interface Constructors
// ============================================================================
assert.isFunction(Element, "Element should be a function")
assert.isFunction(Node, "Node should be a function")
assert.isFunction(EventTarget, "EventTarget should be a function")
assert.isFunction(Event, "Event should be a function")
assert.isFunction(Document, "Document should be a function")
assert.isFunction(HTMLElement, "HTMLElement should be a function")

// ============================================================================
// Prototypes Exist
// ============================================================================
assert.isObject(Element.prototype, "Element.prototype should be an object")
assert.isObject(Node.prototype, "Node.prototype should be an object")
assert.isObject(EventTarget.prototype, "EventTarget.prototype should be an object")

// ============================================================================
// Prototype Chain
// ============================================================================
assert.strictEqual(Element.prototype.__proto__, Node.prototype, "Element.prototype should inherit from Node.prototype")
assert.strictEqual(Node.prototype.__proto__, EventTarget.prototype, "Node.prototype should inherit from EventTarget.prototype")
assert.strictEqual(HTMLElement.prototype.__proto__, Element.prototype, "HTMLElement.prototype should inherit from Element.prototype")

// ============================================================================
// Constructor Properties
// ============================================================================
assert.strictEqual(Element.prototype.constructor, Element, "Element.prototype.constructor should be Element")
assert.strictEqual(Node.prototype.constructor, Node, "Node.prototype.constructor should be Node")
assert.strictEqual(EventTarget.prototype.constructor, EventTarget, "EventTarget.prototype.constructor should be EventTarget")

// ============================================================================
// Namespaces
// ============================================================================
assert.isObject(WebAssembly, "WebAssembly should be an object")
assert.isFunction(WebAssembly.Module, "WebAssembly.Module should be a function")
assert.isFunction(WebAssembly.Instance, "WebAssembly.Instance should be a function")
assert.isFunction(WebAssembly.Memory, "WebAssembly.Memory should be a function")
assert.isFunction(WebAssembly.Table, "WebAssembly.Table should be a function")

// ============================================================================
// LegacyNamespace - No Global Pollution
// ============================================================================
assert.isUndefined(globalThis.Module, "Module should not be in global scope")
assert.isUndefined(globalThis.Instance, "Instance should not be in global scope")
assert.isUndefined(globalThis.Memory, "Memory should not be in global scope")
assert.isUndefined(globalThis.Table, "Table should not be in global scope")

// ============================================================================
// instanceof Function
// ============================================================================
assert.instanceOf(Element, Function, "Element should be instanceof Function")
assert.instanceOf(Node, Function, "Node should be instanceof Function")
assert.instanceOf(Event, Function, "Event should be instanceof Function")
assert.instanceOf(WebAssembly.Module, Function, "WebAssembly.Module should be instanceof Function")

// ============================================================================
// Global Properties
// ============================================================================
assert.ok("Element" in globalThis, "Element should be in globalThis")
assert.ok("Node" in globalThis, "Node should be in globalThis")
assert.ok("WebAssembly" in globalThis, "WebAssembly should be in globalThis")

// ============================================================================
// Prototype Descriptors
// ============================================================================
var elemProtoDesc = Object.getOwnPropertyDescriptor(Element, "prototype")
assert.strictEqual(elemProtoDesc.writable, false, "Element.prototype should not be writable")
assert.strictEqual(elemProtoDesc.enumerable, false, "Element.prototype should not be enumerable")
assert.strictEqual(elemProtoDesc.configurable, false, "Element.prototype should not be configurable")

// ============================================================================
// Non-Constructible - Should throw
// ============================================================================
assert.throws(function() { new Element(); }, null, "new Element() should throw")
assert.throws(function() { new Node(); }, null, "new Node() should throw")

// ============================================================================
// Method Existence on Prototypes (Inheritance Chain)
// ============================================================================
assert.isFunction(Element.prototype.addEventListener, "Element.prototype.addEventListener should be a function")
assert.isFunction(Node.prototype.addEventListener, "Node.prototype.addEventListener should be a function")
assert.isFunction(EventTarget.prototype.addEventListener, "EventTarget.prototype.addEventListener should be a function")
assert.isFunction(Node.prototype.appendChild, "Node.prototype.appendChild should be a function")
assert.isFunction(Element.prototype.appendChild, "Element.prototype.appendChild should be a function")
assert.isUndefined(EventTarget.prototype.appendChild, "EventTarget.prototype.appendChild should be undefined")

// ============================================================================
// Methods are Functions
// ============================================================================
assert.instanceOf(Element.prototype.addEventListener, Function, "addEventListener should be instanceof Function")
assert.instanceOf(Node.prototype.appendChild, Function, "appendChild should be instanceof Function")
assert.instanceOf(EventTarget.prototype.dispatchEvent, Function, "dispatchEvent should be instanceof Function")

// ============================================================================
// Method Descriptors (methods should be writable, non-enumerable, configurable)
// ============================================================================
var addEventDesc = Object.getOwnPropertyDescriptor(EventTarget.prototype, "addEventListener")
assert.strictEqual(addEventDesc.writable, true, "addEventListener should be writable")
assert.strictEqual(addEventDesc.enumerable, false, "addEventListener should not be enumerable")
assert.strictEqual(addEventDesc.configurable, true, "addEventListener should be configurable")

// ============================================================================
// Inherited Methods on Derived Prototypes
// ============================================================================
assert.isFunction(Element.prototype.addEventListener, "Element should inherit addEventListener")
assert.isFunction(Element.prototype.appendChild, "Element should inherit appendChild")
assert.isFunction(HTMLElement.prototype.addEventListener, "HTMLElement should inherit addEventListener")
assert.isFunction(HTMLElement.prototype.appendChild, "HTMLElement should inherit appendChild")

// ============================================================================
// hasOwnProperty for Methods
// ============================================================================
assert.ok(EventTarget.prototype.hasOwnProperty("addEventListener"), "EventTarget.prototype should own addEventListener")
assert.ok(Node.prototype.hasOwnProperty("appendChild"), "Node.prototype should own appendChild")
assert.ok(!Element.prototype.hasOwnProperty("addEventListener"), "Element.prototype should not own addEventListener")
assert.ok(!Element.prototype.hasOwnProperty("appendChild"), "Element.prototype should not own appendChild")

// ============================================================================
// Method Identity Through Inheritance Chain
// ============================================================================
assert.strictEqual(EventTarget.prototype.addEventListener, Node.prototype.addEventListener, "addEventListener should be same on EventTarget and Node")
assert.strictEqual(EventTarget.prototype.addEventListener, Element.prototype.addEventListener, "addEventListener should be same on EventTarget and Element")
assert.strictEqual(EventTarget.prototype.addEventListener, HTMLElement.prototype.addEventListener, "addEventListener should be same on EventTarget and HTMLElement")
assert.strictEqual(Node.prototype.appendChild, Element.prototype.appendChild, "appendChild should be same on Node and Element")
assert.strictEqual(Node.prototype.appendChild, HTMLElement.prototype.appendChild, "appendChild should be same on Node and HTMLElement")
assert.strictEqual(Element.prototype.getAttribute, HTMLElement.prototype.getAttribute, "getAttribute should be same on Element and HTMLElement")

// ============================================================================
// Method Location Verification
// ============================================================================
// EventTarget owns: addEventListener, removeEventListener, dispatchEvent
assert.ok(EventTarget.prototype.hasOwnProperty("addEventListener"), "EventTarget should own addEventListener")
assert.ok(EventTarget.prototype.hasOwnProperty("removeEventListener"), "EventTarget should own removeEventListener")
assert.ok(EventTarget.prototype.hasOwnProperty("dispatchEvent"), "EventTarget should own dispatchEvent")
assert.ok(!Node.prototype.hasOwnProperty("addEventListener"), "Node should not own addEventListener")
assert.ok(!Element.prototype.hasOwnProperty("addEventListener"), "Element should not own addEventListener")
assert.ok(!HTMLElement.prototype.hasOwnProperty("addEventListener"), "HTMLElement should not own addEventListener")

// Node owns: appendChild, removeChild, hasChildNodes
assert.ok(Node.prototype.hasOwnProperty("appendChild"), "Node should own appendChild")
assert.ok(Node.prototype.hasOwnProperty("removeChild"), "Node should own removeChild")
assert.ok(Node.prototype.hasOwnProperty("hasChildNodes"), "Node should own hasChildNodes")
assert.ok(!EventTarget.prototype.hasOwnProperty("appendChild"), "EventTarget should not own appendChild")
assert.ok(!Element.prototype.hasOwnProperty("appendChild"), "Element should not own appendChild")
assert.ok(!HTMLElement.prototype.hasOwnProperty("appendChild"), "HTMLElement should not own appendChild")

// Element owns: getAttribute, setAttribute, hasAttribute
assert.ok(Element.prototype.hasOwnProperty("getAttribute"), "Element should own getAttribute")
assert.ok(Element.prototype.hasOwnProperty("setAttribute"), "Element should own setAttribute")
assert.ok(Element.prototype.hasOwnProperty("hasAttribute"), "Element should own hasAttribute")
assert.ok(!EventTarget.prototype.hasOwnProperty("getAttribute"), "EventTarget should not own getAttribute")
assert.ok(!Node.prototype.hasOwnProperty("getAttribute"), "Node should not own getAttribute")
assert.ok(!HTMLElement.prototype.hasOwnProperty("getAttribute"), "HTMLElement should not own getAttribute")

// ============================================================================
// Verify methods don't exist where they shouldn't
// ============================================================================
assert.isUndefined(EventTarget.prototype.appendChild, "EventTarget.prototype.appendChild should be undefined")
assert.isUndefined(EventTarget.prototype.getAttribute, "EventTarget.prototype.getAttribute should be undefined")
assert.isUndefined(Node.prototype.getAttribute, "Node.prototype.getAttribute should be undefined")

// ============================================================================
// Prototype Chain Walk
// ============================================================================
// HTMLElement should have access to all methods
assert.isFunction(HTMLElement.prototype.addEventListener, "HTMLElement should access addEventListener")
assert.isFunction(HTMLElement.prototype.appendChild, "HTMLElement should access appendChild")
assert.isFunction(HTMLElement.prototype.getAttribute, "HTMLElement should access getAttribute")

// Element should have access to Node and EventTarget methods
assert.isFunction(Element.prototype.addEventListener, "Element should access addEventListener")
assert.isFunction(Element.prototype.appendChild, "Element should access appendChild")
assert.isFunction(Element.prototype.getAttribute, "Element should access getAttribute")

// Node should have access to EventTarget methods
assert.isFunction(Node.prototype.addEventListener, "Node should access addEventListener")
assert.isFunction(Node.prototype.appendChild, "Node should access appendChild")
assert.isUndefined(Node.prototype.getAttribute, "Node should not have getAttribute")

// EventTarget should only have its own methods
assert.isFunction(EventTarget.prototype.addEventListener, "EventTarget should have addEventListener")
assert.isUndefined(EventTarget.prototype.appendChild, "EventTarget should not have appendChild")
assert.isUndefined(EventTarget.prototype.getAttribute, "EventTarget should not have getAttribute")

// ============================================================================
// Method Descriptor Consistency
// ============================================================================
var etDesc = Object.getOwnPropertyDescriptor(EventTarget.prototype, "addEventListener")
assert.strictEqual(etDesc.writable, true, "addEventListener descriptor should be writable")
assert.strictEqual(etDesc.enumerable, false, "addEventListener descriptor should not be enumerable")
assert.strictEqual(etDesc.configurable, true, "addEventListener descriptor should be configurable")

// Verify derived prototypes don't redefine inherited methods
assert.isUndefined(Object.getOwnPropertyDescriptor(Node.prototype, "addEventListener"), "Node should not redefine addEventListener")
assert.isUndefined(Object.getOwnPropertyDescriptor(Element.prototype, "addEventListener"), "Element should not redefine addEventListener")

// ============================================================================
// 'in' operator for inherited methods
// ============================================================================
assert.ok("addEventListener" in EventTarget.prototype, "addEventListener in EventTarget.prototype")
assert.ok("addEventListener" in Node.prototype, "addEventListener in Node.prototype")
assert.ok("addEventListener" in Element.prototype, "addEventListener in Element.prototype")
assert.ok("addEventListener" in HTMLElement.prototype, "addEventListener in HTMLElement.prototype")
assert.ok("appendChild" in Node.prototype, "appendChild in Node.prototype")
assert.ok("appendChild" in Element.prototype, "appendChild in Element.prototype")
assert.ok("appendChild" in HTMLElement.prototype, "appendChild in HTMLElement.prototype")
assert.ok(!("appendChild" in EventTarget.prototype), "appendChild should not be in EventTarget.prototype")

// ============================================================================
// Prototype chain integrity
// ============================================================================
assert.strictEqual(Object.getPrototypeOf(HTMLElement.prototype), Element.prototype, "HTMLElement.__proto__ should be Element.prototype")
assert.strictEqual(Object.getPrototypeOf(Element.prototype), Node.prototype, "Element.__proto__ should be Node.prototype")
assert.strictEqual(Object.getPrototypeOf(Node.prototype), EventTarget.prototype, "Node.__proto__ should be EventTarget.prototype")
assert.strictEqual(Object.getPrototypeOf(EventTarget.prototype), Object.prototype, "EventTarget.__proto__ should be Object.prototype")
assert.strictEqual(Object.getPrototypeOf(Object.prototype), null, "Object.prototype.__proto__ should be null")
