// Simplest possible wrapper identity test

var doc = new Document();
var div = doc.createElement("div");

// Test 1: div is not null
div !== null

// Test 2: div equals itself
div === div

// Test 3: calling createElement twice creates different objects
var div2 = doc.createElement("div");
div !== div2

// Test 4: Storing in variable and retrieving works
var x = div;
x === div
