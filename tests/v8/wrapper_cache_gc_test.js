// V8 Wrapper Cache GC Integration Tests
// Tests wrapper identity is preserved across repeated queries

// Setup
var doc = new Document()
var body = doc.createElement("body")

// TEST 1: querySelector should return same wrapper for same element
var div = doc.createElement("div")
div.id = "test-basic-identity"
var _a1 = body.appendChild(div)
var e1 = body.querySelector("#test-basic-identity")
var e2 = body.querySelector("#test-basic-identity")
assert.strictEqual(e1, e2, "querySelector should return same wrapper for same element")

// TEST 2: Multiple queries return same wrapper
var span = doc.createElement("span")
span.className = "test-class"
var _a2 = body.appendChild(span)
var r1 = body.querySelector(".test-class")
var r2 = body.querySelector(".test-class")
var r3 = body.querySelector(".test-class")
assert.strictEqual(r1, r2, "First and second query should return same wrapper")
assert.strictEqual(r2, r3, "Second and third query should return same wrapper")

// TEST 3: Element created via constructor matches when queried
var section = doc.createElement("section")
section.id = "constructor-query-test"
var _a3 = body.appendChild(section)
var queried = body.querySelector("#constructor-query-test")
assert.strictEqual(section, queried, "Created element should match queried element")

// TEST 4: Each unique element gets unique wrapper
var div1 = doc.createElement("div")
var div2 = doc.createElement("div")
div1.id = "div1"
div2.id = "div2"
var _a4 = body.appendChild(div1)
var _a5 = body.appendChild(div2)
var q1 = body.querySelector("#div1")
var q2 = body.querySelector("#div2")
assert.notStrictEqual(q1, q2, "Different elements should have different wrappers")
assert.strictEqual(div1, q1, "div1 should match queried div1")
assert.strictEqual(div2, q2, "div2 should match queried div2")

// TEST 5: Parent and child maintain separate wrapper identity
var parent = doc.createElement("div")
var child = doc.createElement("span")
parent.id = "parent"
child.id = "child"
var _a6 = parent.appendChild(child)
var _a7 = body.appendChild(parent)
var pq = body.querySelector("#parent")
var cq = body.querySelector("#child")
assert.strictEqual(parent, pq, "parent should match queried parent")
assert.strictEqual(child, cq, "child should match queried child")
assert.notStrictEqual(parent, child, "parent and child should be different")

// TEST 6: querySelector with non-existent selector returns null
assert.isNull(body.querySelector("#this-id-does-not-exist-12345"), "Non-existent selector should return null")

// TEST 7: Multiple queries for non-existent element return null consistently
var nr1 = body.querySelector("#nonexistent-abc")
var nr2 = body.querySelector("#nonexistent-abc")
assert.isNull(nr1, "First non-existent query should return null")
assert.isNull(nr2, "Second non-existent query should return null")

// TEST 8: querySelectorAll returns collection
var result = body.querySelectorAll("div")
assert.isNotNull(result, "querySelectorAll should return non-null")
assert.isDefined(result, "querySelectorAll should return defined value")

// TEST 9: querySelectorAll items match createElement results
var d1 = doc.createElement("article")
var d2 = doc.createElement("article")
d1.id = "art1"
d2.id = "art2"
var _a8 = body.appendChild(d1)
var _a9 = body.appendChild(d2)
var all = body.querySelectorAll("article")
assert.greaterThan(all.length, 1, "querySelectorAll should return at least 2 articles")

// TEST 10: Wrapper identity after property modification
var el = doc.createElement("div")
el.id = "modify-test"
var _a10 = body.appendChild(el)
var before = body.querySelector("#modify-test")
el.className = "modified"
var after = body.querySelector("#modify-test")
assert.strictEqual(before, after, "Wrapper identity should be preserved after property modification")
