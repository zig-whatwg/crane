// Test NodeList indexed property access (bracket notation)
// This tests that list[0], list[1], etc. work correctly

var doc = new Document()
var body = doc.createElement("body")

// Create test elements
var div1 = doc.createElement("div")
div1.id = "div1"
var _a1 = body.appendChild(div1)

var div2 = doc.createElement("div")
div2.id = "div2"
var _a2 = body.appendChild(div2)

var div3 = doc.createElement("div")
div3.id = "div3"
var _a3 = body.appendChild(div3)

// Get NodeList
var list = body.querySelectorAll("div")

// Test: NodeList has correct length
assert.strictEqual(list.length, 3, "NodeList should have 3 items")

// Test indexed access with bracket notation
var item0 = list[0]
var item1 = list[1]
var item2 = list[2]

// Test: Items are defined
assert.isDefined(item0, "list[0] should be defined")
assert.isDefined(item1, "list[1] should be defined")
assert.isDefined(item2, "list[2] should be defined")

// Test: IDs are correct
assert.strictEqual(item0.id, "div1", "list[0].id should be 'div1'")
assert.strictEqual(item1.id, "div2", "list[1].id should be 'div2'")
assert.strictEqual(item2.id, "div3", "list[2].id should be 'div3'")

// Test: Out-of-bounds returns undefined
var item3 = list[3]
assert.isUndefined(item3, "list[3] should be undefined (out of bounds)")

// Test: Identity is preserved (same object references)
assert.strictEqual(list[0], div1, "list[0] should be same object as div1")
assert.strictEqual(list[1], div2, "list[1] should be same object as div2")
assert.strictEqual(list[2], div3, "list[2] should be same object as div3")

// Test: .item() method still works
var itemMethod0 = list.item(0)
assert.strictEqual(itemMethod0, item0, "list.item(0) should equal list[0]")
