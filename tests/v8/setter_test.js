// Property Setter Tests
// Tests that property setters work correctly

// Test: element.id setter
var doc = new Document()
var element = doc.createElement("div")
element.id = "my-id"
assert.strictEqual(element.id, "my-id", "element.id setter should work")

// Test: element.className setter
var element2 = doc.createElement("div")
element2.className = "my-class"
assert.strictEqual(element2.className, "my-class", "element.className setter should work")

// Test: set both id and className
var div = doc.createElement("div")
div.id = "test-id"
div.className = "test-class"
assert.strictEqual(div.id, "test-id", "div.id should be set")
assert.strictEqual(div.className, "test-class", "div.className should be set")

// Test: set property multiple times
var div2 = doc.createElement("div")
div2.id = "first"
assert.strictEqual(div2.id, "first", "id should be 'first'")
div2.id = "second"
assert.strictEqual(div2.id, "second", "id should be 'second' after update")
div2.id = "third"
assert.strictEqual(div2.id, "third", "id should be 'third' after second update")

// Test: empty string setter
var div3 = doc.createElement("div")
div3.id = "initial"
div3.id = ""
assert.strictEqual(div3.id, "", "id should be empty string after setting to ''")

// Test: numeric value coercion
var div4 = doc.createElement("div")
div4.id = 123
assert.strictEqual(div4.id, "123", "numeric id should be coerced to string")
