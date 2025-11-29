// WHATWG TestUtils Standard - gc() method test
// https://testutils.spec.whatwg.org/

// Test 1: TestUtils exists
assert.isObject(TestUtils, "TestUtils should be an object")

// Test 2: TestUtils.gc exists  
assert.isFunction(TestUtils.gc, "TestUtils.gc should be a function")

// Test 3: gc() returns a Promise
assert.instanceOf(TestUtils.gc(), Promise, "gc() should return a Promise")

// Test 4: Promise constructor exists (sanity check)
assert.isFunction(Promise, "Promise should be a function")
