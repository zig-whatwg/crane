// Test child combinator specifically

var doc = new Document()
var body = doc.createElement("body")
var header = doc.createElement("header")
var main = doc.createElement("main")

var _s1 = body.appendChild(header)
var _s2 = body.appendChild(main)

// Test 1: Simple type selector
assert.strictEqual(body.querySelector("header"), header, "querySelector('header') should find header")

// Test 2: Descendant combinator
assert.strictEqual(body.querySelector("body header"), header, "Descendant selector 'body header' should find header")

// Test 3: Child combinator - direct child
assert.strictEqual(body.querySelector("body > header"), header, "Child selector 'body > header' should find header")

// Test 4: Another child combinator
assert.strictEqual(body.querySelector("body > main"), main, "Child selector 'body > main' should find main")

// Test 5: Child combinator that should fail (main is not child of header)
assert.isNull(header.querySelector("header > main"), "header > main should be null (main is not child of header)")
