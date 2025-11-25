// Test NodeList indexed property access (bracket notation)
// This tests that list[0], list[1], etc. work correctly

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

console.log('NodeList length:', list.length);
console.assert(list.length === 3, 'Expected 3 divs');

// Test indexed access with bracket notation
console.log('Testing indexed access...');
var item0 = list[0];
var item1 = list[1];
var item2 = list[2];

console.log('list[0]:', item0);
console.log('list[1]:', item1);
console.log('list[2]:', item2);

// Verify elements are correct
console.assert(item0 !== undefined, 'list[0] should not be undefined');
console.assert(item1 !== undefined, 'list[1] should not be undefined');
console.assert(item2 !== undefined, 'list[2] should not be undefined');

console.assert(item0.id === 'div1', 'list[0] should be div1');
console.assert(item1.id === 'div2', 'list[1] should be div2');
console.assert(item2.id === 'div3', 'list[2] should be div3');

// Test out-of-bounds access
var item3 = list[3];
console.log('list[3] (out of bounds):', item3);
console.assert(item3 === undefined, 'list[3] should be undefined');

// Verify order (document order)
console.assert(list[0] === div1, 'list[0] === div1');
console.assert(list[1] === div2, 'list[1] === div2');
console.assert(list[2] === div3, 'list[2] === div3');

// Also test that .item() still works
var itemMethod0 = list.item(0);
console.assert(itemMethod0 === item0, 'list.item(0) === list[0]');

console.log('✅ All NodeList indexed access tests passed!');
