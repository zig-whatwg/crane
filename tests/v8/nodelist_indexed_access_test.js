// Test NodeList indexed property access (bracket notation)
// This tests that list[0], list[1], etc. work correctly
//
// Expected output format: Each test evaluates to true/false
// The test runner counts true/false lines to determine pass/fail

var doc = new Document();
var body = doc.createElement("body");

// Create test elements
var div1 = doc.createElement('div');
div1.id = 'div1';
body.appendChild(div1);

var div2 = doc.createElement('div');
div2.id = 'div2';
body.appendChild(div2);

var div3 = doc.createElement('div');
div3.id = 'div3';
body.appendChild(div3);

// Get NodeList
var list = body.querySelectorAll('div');

// Test: NodeList has correct length
list.length === 3

// Test indexed access with bracket notation
var item0 = list[0];
var item1 = list[1];
var item2 = list[2];

// Test: Items are defined
item0 !== undefined
item1 !== undefined
item2 !== undefined

// Test: IDs are correct
item0.id === 'div1'
item1.id === 'div2'
item2.id === 'div3'

// Test: Out-of-bounds returns undefined
var item3 = list[3];
item3 === undefined

// Test: Identity is preserved (same object references)
list[0] === div1
list[1] === div2
list[2] === div3

// Test: .item() method still works
var itemMethod0 = list.item(0);
itemMethod0 === item0
