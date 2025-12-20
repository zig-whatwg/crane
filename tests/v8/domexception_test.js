// DOMException property test

// Test basic constructor
var e = new DOMException("test message", "TestError");
assert.isString(e.name, "DOMException.name should be a string");
assert.isString(e.message, "DOMException.message should be a string");
assert.strictEqual(e.name, "TestError", "name should be 'TestError'");
assert.strictEqual(e.message, "test message", "message should be 'test message'");
assert.strictEqual(e.code, 0, "code should be 0 for unknown error name");

// Test with known error name
var e2 = new DOMException("my message", "NotSupportedError");
assert.isString(e2.name, "e2.name should be a string");
assert.strictEqual(e2.name, "NotSupportedError", "name should be 'NotSupportedError'");
assert.strictEqual(e2.message, "my message", "message should be 'my message'");
assert.strictEqual(e2.code, 9, "code should be 9 for NotSupportedError");

// Test default constructor
var e3 = new DOMException();
assert.isString(e3.name, "e3.name should be a string");
assert.strictEqual(e3.name, "Error", "default name should be 'Error'");
assert.strictEqual(e3.message, "", "default message should be ''");
assert.strictEqual(e3.code, 0, "default code should be 0");

// Test instanceof Error
assert.instanceOf(e, DOMException, "e should be instanceof DOMException");
assert.instanceOf(e, Error, "DOMException should be instanceof Error");
