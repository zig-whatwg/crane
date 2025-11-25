// Test child combinator specifically

var doc = new Document();
var body = doc.createElement("body");
var header = doc.createElement("header");
var main = doc.createElement("main");

body.appendChild(header);
body.appendChild(main);

// Test 1: Simple type selector (should work)
body.querySelector("header") === header

// Test 2: Descendant combinator (should work)
body.querySelector("body header") === header

// Test 3: Child combinator - direct child (THIS IS THE TEST)
body.querySelector("body > header") === header

// Test 4: Another child combinator
body.querySelector("body > main") === main

// Test 5: Child combinator that should fail (header is not direct child of header)
header.querySelector("header > main") === null
