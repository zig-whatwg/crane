// Simplest possible wrapper identity test

var doc = new Document()
var div = doc.createElement("div")

// Test 1: div is not null
assert.isNotNull(div, "createElement should return non-null")

// Test 2: div equals itself
assert.strictEqual(div, div, "div should equal itself")

// Test 3: calling createElement twice creates different objects
var div2 = doc.createElement("div")
assert.notStrictEqual(div, div2, "createElement should create different objects")

// Test 4: Storing in variable and retrieving works
var x = div
assert.strictEqual(x, div, "Variable assignment should preserve identity")
