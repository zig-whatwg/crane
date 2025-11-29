// V8 Prototype Chain Inheritance Test
// Tests that inherited members are found via prototype chain, not duplicated

// ============================================================================
// Test 1: Prototype Chain is Correctly Set Up
// ============================================================================
assert.strictEqual(Element.prototype.__proto__, Node.prototype, "Element.prototype should inherit from Node.prototype")
assert.strictEqual(Node.prototype.__proto__, EventTarget.prototype, "Node.prototype should inherit from EventTarget.prototype")
assert.strictEqual(HTMLElement.prototype.__proto__, Element.prototype, "HTMLElement.prototype should inherit from Element.prototype")

// ============================================================================
// Test 2: addEventListener is ONLY on EventTarget.prototype
// ============================================================================
assert.isDefined(Object.getOwnPropertyDescriptor(EventTarget.prototype, "addEventListener"), "EventTarget.prototype should own addEventListener")
assert.isUndefined(Object.getOwnPropertyDescriptor(Node.prototype, "addEventListener"), "Node.prototype should not own addEventListener")
assert.isUndefined(Object.getOwnPropertyDescriptor(Element.prototype, "addEventListener"), "Element.prototype should not own addEventListener")
assert.isUndefined(Object.getOwnPropertyDescriptor(HTMLElement.prototype, "addEventListener"), "HTMLElement.prototype should not own addEventListener")

// But it should be accessible via prototype chain
assert.isFunction(Element.prototype.addEventListener, "Element.prototype.addEventListener should be accessible")
assert.isFunction(Node.prototype.addEventListener, "Node.prototype.addEventListener should be accessible")
assert.isFunction(HTMLElement.prototype.addEventListener, "HTMLElement.prototype.addEventListener should be accessible")

// ============================================================================
// Test 3: appendChild is ONLY on Node.prototype
// ============================================================================
assert.isDefined(Object.getOwnPropertyDescriptor(Node.prototype, "appendChild"), "Node.prototype should own appendChild")
assert.isUndefined(Object.getOwnPropertyDescriptor(Element.prototype, "appendChild"), "Element.prototype should not own appendChild")
assert.isUndefined(Object.getOwnPropertyDescriptor(HTMLElement.prototype, "appendChild"), "HTMLElement.prototype should not own appendChild")

// But it should be accessible via prototype chain
assert.isFunction(Element.prototype.appendChild, "Element.prototype.appendChild should be accessible")
assert.isFunction(HTMLElement.prototype.appendChild, "HTMLElement.prototype.appendChild should be accessible")

// appendChild should NOT exist on EventTarget.prototype
assert.isUndefined(EventTarget.prototype.appendChild, "EventTarget.prototype.appendChild should be undefined")

// ============================================================================
// Test 4: nodeType getter is ONLY on Node.prototype
// ============================================================================
assert.isDefined(Object.getOwnPropertyDescriptor(Node.prototype, "nodeType"), "Node.prototype should own nodeType")
assert.isDefined(Object.getOwnPropertyDescriptor(Node.prototype, "nodeType").get, "nodeType should be a getter")
assert.isUndefined(Object.getOwnPropertyDescriptor(Element.prototype, "nodeType"), "Element.prototype should not own nodeType")
assert.isUndefined(Object.getOwnPropertyDescriptor(HTMLElement.prototype, "nodeType"), "HTMLElement.prototype should not own nodeType")
assert.isUndefined(Object.getOwnPropertyDescriptor(EventTarget.prototype, "nodeType"), "EventTarget.prototype should not have nodeType")

// ============================================================================
// Test 5: dispatchEvent is ONLY on EventTarget.prototype
// ============================================================================
assert.isDefined(Object.getOwnPropertyDescriptor(EventTarget.prototype, "dispatchEvent"), "EventTarget.prototype should own dispatchEvent")
assert.isUndefined(Object.getOwnPropertyDescriptor(Node.prototype, "dispatchEvent"), "Node.prototype should not own dispatchEvent")
assert.isUndefined(Object.getOwnPropertyDescriptor(Element.prototype, "dispatchEvent"), "Element.prototype should not own dispatchEvent")
assert.isFunction(Node.prototype.dispatchEvent, "Node.prototype.dispatchEvent should be accessible")
assert.isFunction(Element.prototype.dispatchEvent, "Element.prototype.dispatchEvent should be accessible")

// ============================================================================
// Test 6: removeEventListener is ONLY on EventTarget.prototype
// ============================================================================
assert.isDefined(Object.getOwnPropertyDescriptor(EventTarget.prototype, "removeEventListener"), "EventTarget.prototype should own removeEventListener")
assert.isUndefined(Object.getOwnPropertyDescriptor(Node.prototype, "removeEventListener"), "Node.prototype should not own removeEventListener")
assert.isUndefined(Object.getOwnPropertyDescriptor(Element.prototype, "removeEventListener"), "Element.prototype should not own removeEventListener")
assert.isFunction(Node.prototype.removeEventListener, "Node.prototype.removeEventListener should be accessible")
assert.isFunction(Element.prototype.removeEventListener, "Element.prototype.removeEventListener should be accessible")

// ============================================================================
// Test 7: Element-specific methods are ONLY on Element.prototype
// ============================================================================
assert.isDefined(Object.getOwnPropertyDescriptor(Element.prototype, "getAttribute"), "Element.prototype should own getAttribute")
assert.isUndefined(Node.prototype.getAttribute, "Node.prototype.getAttribute should be undefined")
assert.isUndefined(EventTarget.prototype.getAttribute, "EventTarget.prototype.getAttribute should be undefined")
assert.isFunction(HTMLElement.prototype.getAttribute, "HTMLElement.prototype.getAttribute should be accessible")
assert.isUndefined(Object.getOwnPropertyDescriptor(HTMLElement.prototype, "getAttribute"), "HTMLElement.prototype should not own getAttribute")

// ============================================================================
// Test 8: Own vs Inherited Properties
// ============================================================================
assert.ok(Object.getOwnPropertyNames(EventTarget.prototype).includes("addEventListener"), "EventTarget own props should include addEventListener")
assert.ok(!Object.getOwnPropertyNames(Node.prototype).includes("addEventListener"), "Node own props should not include addEventListener")
assert.ok(!Object.getOwnPropertyNames(Element.prototype).includes("addEventListener"), "Element own props should not include addEventListener")

assert.ok(Object.getOwnPropertyNames(Node.prototype).includes("appendChild"), "Node own props should include appendChild")
assert.ok(!Object.getOwnPropertyNames(Element.prototype).includes("appendChild"), "Element own props should not include appendChild")

assert.ok(Object.getOwnPropertyNames(Element.prototype).includes("getAttribute"), "Element own props should include getAttribute")
assert.ok(!Object.getOwnPropertyNames(Node.prototype).includes("getAttribute"), "Node own props should not include getAttribute")

// ============================================================================
// Test 9: Method Identity - Same Function Reference
// ============================================================================
assert.strictEqual(Element.prototype.addEventListener, Node.prototype.addEventListener, "addEventListener should be same on Element and Node")
assert.strictEqual(Node.prototype.addEventListener, EventTarget.prototype.addEventListener, "addEventListener should be same on Node and EventTarget")
assert.strictEqual(HTMLElement.prototype.addEventListener, EventTarget.prototype.addEventListener, "addEventListener should be same on HTMLElement and EventTarget")

assert.strictEqual(Element.prototype.dispatchEvent, Node.prototype.dispatchEvent, "dispatchEvent should be same on Element and Node")
assert.strictEqual(Node.prototype.dispatchEvent, EventTarget.prototype.dispatchEvent, "dispatchEvent should be same on Node and EventTarget")

assert.strictEqual(Element.prototype.appendChild, Node.prototype.appendChild, "appendChild should be same on Element and Node")
assert.strictEqual(HTMLElement.prototype.appendChild, Node.prototype.appendChild, "appendChild should be same on HTMLElement and Node")

// ============================================================================
// Test 10: hasOwnProperty verification
// ============================================================================
assert.ok(Object.hasOwnProperty.call(EventTarget.prototype, "addEventListener"), "EventTarget.prototype should have own addEventListener")
assert.ok(!Object.hasOwnProperty.call(Node.prototype, "addEventListener"), "Node.prototype should not have own addEventListener")
assert.ok(!Object.hasOwnProperty.call(Element.prototype, "addEventListener"), "Element.prototype should not have own addEventListener")

assert.ok(Object.hasOwnProperty.call(Node.prototype, "nodeType"), "Node.prototype should have own nodeType")
assert.ok(!Object.hasOwnProperty.call(Element.prototype, "nodeType"), "Element.prototype should not have own nodeType")
assert.ok(!Object.hasOwnProperty.call(HTMLElement.prototype, "nodeType"), "HTMLElement.prototype should not have own nodeType")
