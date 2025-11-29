// Simple querySelector test

// Setup
var doc = new Document()
var body = doc.createElement("body")
var header = doc.createElement("header")
var _setup = body.appendChild(header)

// Test 1: querySelector is defined
assert.isDefined(body.querySelector, "querySelector should be defined")

// Test 2: querySelector is a function
assert.isFunction(body.querySelector, "querySelector should be a function")

// Test 3: querySelector finds the element
assert.isNotNull(body.querySelector("header"), "querySelector('header') should find element")

// Test 4: querySelector returns the same object (wrapper identity)
assert.strictEqual(body.querySelector("header"), header, "querySelector should return the appended header element")

// Test 5: querySelector returns consistent results
assert.strictEqual(body.querySelector("header"), body.querySelector("header"), "querySelector should return same object on repeated calls")

// Test 6: Test with dynamically created element
var div = doc.createElement("div")
var _append = body.appendChild(div)
assert.strictEqual(body.querySelector("div"), div, "querySelector should find dynamically added div")
