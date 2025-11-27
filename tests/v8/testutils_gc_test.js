// WHATWG TestUtils Standard - gc() method test
// https://testutils.spec.whatwg.org/

// Test 1: gc() returns a Promise
var result = TestUtils.gc();
if (!(result instanceof Promise)) {
    throw new Error("TestUtils.gc() should return a Promise");
}
console.log("PASS: TestUtils.gc() returns a Promise");

// Test 2: Promise resolves to undefined
TestUtils.gc().then(function(value) {
    if (value !== undefined) {
        throw new Error("Promise should resolve to undefined, got: " + value);
    }
    console.log("PASS: Promise resolves to undefined");
}).catch(function(error) {
    console.error("FAIL: Promise rejected: " + error);
});

// Test 3: Multiple concurrent calls work
Promise.all([
    TestUtils.gc(),
    TestUtils.gc(),
    TestUtils.gc()
]).then(function(results) {
    if (results.length !== 3) {
        throw new Error("Expected 3 results, got: " + results.length);
    }
    for (var i = 0; i < results.length; i++) {
        if (results[i] !== undefined) {
            throw new Error("Result " + i + " should be undefined");
        }
    }
    console.log("PASS: Multiple gc() calls work correctly");
    console.log("All TestUtils.gc() tests passed!");
}).catch(function(error) {
    console.error("FAIL: Multiple gc() calls failed: " + error);
});
