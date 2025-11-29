// Test: Property access on prototypes should return undefined (not crash)
// 
// Browser behavior:
// - Accessing Element.prototype.tagName returns undefined
// - No crash, no error thrown
// - This is because there's no instance to get the property from

console.log("=== Prototype Property Access Tests ===\n");

// Test 1: Access property on Element.prototype
console.log("\n--- Test 1: Element.prototype.tagName ---");
assert.isTrue((() => {
    try {
        var result = Element.prototype.tagName;
        return result === undefined;
    } catch (e) {
        return false; // Should not crash
    }
})(), "Element.prototype.tagName should return undefined (not crash)")

// Test 2: Access property on Node.prototype
console.log("\n--- Test 2: Node.prototype.nodeType ---");
assert.isTrue((() => {
    try {
        var result = Node.prototype.nodeType;
        return result === undefined;
    } catch (e) {
        return false; // Should not crash
    }
})(), "Node.prototype.nodeType should return undefined (not crash)")

// Test 3: Access property on EventTarget.prototype
console.log("\n--- Test 3: EventTarget.prototype (no instance properties) ---");
assert.strictEqual(typeof EventTarget.prototype, "object", "EventTarget.prototype should be an object")

// Test 4: Multiple prototype property accesses
console.log("\n--- Test 4: Multiple accesses ---");
assert.isTrue((() => {
    try {
        Element.prototype.tagName;
        Element.prototype.tagName;
        Element.prototype.tagName;
        return true;
    } catch (e) {
        return false;
    }
})(), "Multiple Element.prototype.tagName accesses should not crash")

// Test 5: Check that prototype is still accessible
console.log("\n--- Test 5: Prototype chain ---");
assert.strictEqual(typeof Element.prototype, "object", "Element.prototype should be an object")

// Test 6: hasOwnProperty check
console.log("\n--- Test 6: hasOwnProperty ---");
assert.isTrue((() => {
    try {
        return typeof Element.prototype.hasOwnProperty('tagName') === 'boolean';
    } catch (e) {
        return false;
    }
})(), "Element.prototype.hasOwnProperty('tagName') check should not crash")

console.log("\n=== Prototype Property Access Tests Complete ===")
