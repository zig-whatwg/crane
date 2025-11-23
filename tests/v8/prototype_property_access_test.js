// Test: Property access on prototypes should return undefined (not crash)
// 
// Browser behavior:
// - Accessing Element.prototype.tagName returns undefined
// - No crash, no error thrown
// - This is because there's no instance to get the property from

console.log("=== Prototype Property Access Tests ===\n");

let passed = 0;
let failed = 0;

function test(description, fn) {
    try {
        const result = fn();
        console.log(`✓ ${description}`);
        passed++;
        return result;
    } catch (e) {
        console.log(`✗ ${description}`);
        console.log(`  Error: ${e.name}: ${e.message}`);
        failed++;
        return undefined;
    }
}

function assertEqual(actual, expected, message) {
    if (actual === expected) {
        console.log(`✓ ${message}: ${JSON.stringify(actual)}`);
        passed++;
    } else {
        console.log(`✗ ${message}`);
        console.log(`  Expected: ${JSON.stringify(expected)}`);
        console.log(`  Got: ${JSON.stringify(actual)}`);
        failed++;
    }
}

// Test 1: Access property on Element.prototype
console.log("\n--- Test 1: Element.prototype.tagName ---");
const result1 = test("Element.prototype.tagName should not crash", () => {
    return Element.prototype.tagName;
});
assertEqual(result1, undefined, "Element.prototype.tagName should return undefined");

// Test 2: Access property on Node.prototype
console.log("\n--- Test 2: Node.prototype.nodeType ---");
const result2 = test("Node.prototype.nodeType should not crash", () => {
    return Node.prototype.nodeType;
});
assertEqual(result2, undefined, "Node.prototype.nodeType should return undefined");

// Test 3: Access property on EventTarget.prototype
console.log("\n--- Test 3: EventTarget.prototype (no instance properties) ---");
const result3 = test("EventTarget.prototype access should not crash", () => {
    // EventTarget has no attributes, only methods
    // But accessing the prototype itself should still work
    return typeof EventTarget.prototype;
});
assertEqual(result3, "object", "EventTarget.prototype should be an object");

// Test 4: Multiple prototype property accesses
console.log("\n--- Test 4: Multiple accesses ---");
test("Multiple Element.prototype.tagName accesses", () => {
    Element.prototype.tagName;
    Element.prototype.tagName;
    Element.prototype.tagName;
    return true;
});

// Test 5: Check that prototype is still accessible
console.log("\n--- Test 5: Prototype chain ---");
const result5 = test("Element.prototype should exist", () => {
    return Element.prototype;
});
assertEqual(typeof result5, "object", "Element.prototype should be an object");

// Test 6: hasOwnProperty check
console.log("\n--- Test 6: hasOwnProperty ---");
test("Element.prototype.hasOwnProperty('tagName') check", () => {
    return Element.prototype.hasOwnProperty('tagName');
});

// Summary
console.log("\n=== Summary ===");
console.log(`Passed: ${passed}`);
console.log(`Failed: ${failed}`);
console.log(`Total: ${passed + failed}`);

if (failed === 0) {
    console.log("\n✅ All tests passed!");
} else {
    console.log(`\n❌ ${failed} test(s) failed`);
}
