// WHATWG TestUtils Standard - gc() method test
// https://testutils.spec.whatwg.org/
//
// NOTE: This test requires building with -Denable-test-utils=true
// It is excluded from the default test-v8 run.
//
// To run manually:
//   zig build -Denable-test-utils=true
//   ./zig-out/bin/repl < tests/v8/testutils_gc_test.js

// Test 1: TestUtils exists
typeof TestUtils === "object"

// Test 2: TestUtils.gc exists  
typeof TestUtils.gc === "function"

// Test 3: gc() returns a Promise
TestUtils.gc() instanceof Promise

// Test 4: Promise constructor exists (sanity check)
typeof Promise === "function"
