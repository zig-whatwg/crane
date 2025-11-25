// Test with exact structure from querySelector_basic_test.js

var doc = new Document();
var body = doc.createElement("body");
var header = doc.createElement("header");
var main = doc.createElement("main");
var footer = doc.createElement("footer");
var section1 = doc.createElement("section");
var section2 = doc.createElement("section");

body.appendChild(header);
body.appendChild(main);
main.appendChild(section1);
main.appendChild(section2);
body.appendChild(footer);

// These should all pass based on the 83% pass rate
// Let's test the more complex ones

// Test 1: Direct child of body
body.querySelector("body > header") === header

// Test 2: Direct child of body
body.querySelector("body > main") === main

// Test 3: Section is NOT direct child of body (should be null)
body.querySelector("body > section") === null

// Test 4: Multi-level child combinator
body.querySelector("main > section") === section1

// Test 5: Comma-separated selectors (might not be supported?)
body.querySelectorAll("header, main").length === 2

// Test 6: Multiple descendant levels
body.querySelector("body main section") === section1

// Test 7: Mixed child and descendant
body.querySelector("body > main section") === section1
