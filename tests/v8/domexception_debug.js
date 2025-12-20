// Test exactly like WPT but without testharness
'use strict';

// Test: new DOMException("foo")
var ex = new DOMException("foo");
if (ex.name !== "Error") {
    throw new Error("FAIL: new DOMException('foo').name is '" + ex.name + "' (type: " + typeof ex.name + ") expected 'Error'");
}
if (ex.message !== "foo") {
    throw new Error("FAIL: new DOMException('foo').message is '" + ex.message + "' (type: " + typeof ex.message + ") expected 'foo'");
}

// Test: new DOMException("bar", "NotSupportedError")
var ex2 = new DOMException("bar", "NotSupportedError");
if (ex2.name !== "NotSupportedError") {
    throw new Error("FAIL: DOMException name is '" + ex2.name + "' (type: " + typeof ex2.name + ") expected 'NotSupportedError'");
}
if (ex2.message !== "bar") {
    throw new Error("FAIL: DOMException message is '" + ex2.message + "' (type: " + typeof ex2.message + ") expected 'bar'");
}
if (ex2.code !== DOMException.NOT_SUPPORTED_ERR) {
    throw new Error("FAIL: DOMException code is " + ex2.code + " expected " + DOMException.NOT_SUPPORTED_ERR);
}

// All pass
