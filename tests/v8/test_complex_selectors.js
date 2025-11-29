// Complex selector tests

var doc = new Document()
var body = doc.createElement("body")
var header = doc.createElement("header")
var main = doc.createElement("main")
var footer = doc.createElement("footer")
var section1 = doc.createElement("section")
var section2 = doc.createElement("section")

var _s1 = body.appendChild(header)
var _s2 = body.appendChild(main)
var _s3 = main.appendChild(section1)
var _s4 = main.appendChild(section2)
var _s5 = body.appendChild(footer)

// Test 1: Direct child of body
assert.strictEqual(body.querySelector("body > header"), header, "body > header should find header")

// Test 2: Direct child of body  
assert.strictEqual(body.querySelector("body > main"), main, "body > main should find main")

// Test 3: Section is NOT direct child of body (should be null)
assert.isNull(body.querySelector("body > section"), "body > section should be null (section is inside main)")

// Test 4: Multi-level child combinator
assert.strictEqual(body.querySelector("main > section"), section1, "main > section should find first section")

// Test 5: Comma-separated selectors
assert.strictEqual(body.querySelectorAll("header, main").length, 2, "querySelectorAll('header, main') should return 2 elements")

// Test 6: Multiple descendant levels
assert.strictEqual(body.querySelector("body main section"), section1, "body main section should find first section")

// Test 7: Mixed child and descendant
assert.strictEqual(body.querySelector("body > main section"), section1, "body > main section should find first section")
