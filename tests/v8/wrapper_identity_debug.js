// Debug wrapper identity

var doc = new Document();
var div1 = doc.createElement("div");
var div2 = doc.createElement("div");

// Test 1: Different elements should NOT be equal
assert.isTrue(div1 !== div2, "Different elements should NOT be equal")

// Test 2: Same element should be equal to itself
assert.strictEqual(div1, div1, "Same element should be equal to itself")

// Test 3: Append and retrieve
var body = doc.createElement("body");
var _append = body.appendChild(div1);
var retrieved = body.querySelector("div");

// Test 4: Retrieved element should be non-null
assert.isNotNull(retrieved, "Retrieved element should be non-null")

// Test 5: Retrieved element should equal original (WRAPPER IDENTITY TEST)
assert.strictEqual(retrieved, div1, "Retrieved element should equal original (wrapper identity)")

// Test 6: Multiple calls should return same wrapper
assert.strictEqual(body.querySelector("div"), body.querySelector("div"), "Multiple querySelector calls should return same wrapper")
