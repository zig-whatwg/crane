// WHATWG TestUtils Standard - gc() method test
// https://testutils.spec.whatwg.org/

// Test 1: TestUtils exists
typeof TestUtils === "object"

// Test 2: TestUtils.gc exists  
typeof TestUtils.gc === "function"

// Test 3: gc() returns a Promise
TestUtils.gc() instanceof Promise

// Test 4: Promise constructor exists (sanity check)
typeof Promise === "function"
