// Simple querySelector test to debug issues

// Basic setup
var doc = new Document();
var body = doc.createElement("body");
var header = doc.createElement("header");
body.appendChild(header);

// Test 1: querySelector returns something
typeof body.querySelector !== "undefined"

// Test 2: querySelector is a function
typeof body.querySelector === "function"

// Test 3: querySelector finds the element
body.querySelector("header") !== null

// Test 4: querySelector returns the same object (wrapper identity)
body.querySelector("header") === header

// Test 5: querySelector returns consistent results
body.querySelector("header") === body.querySelector("header")

// Test 6: Test with div
(() => {
    var div = doc.createElement("div");
    body.appendChild(div);
    return body.querySelector("div") === div;
})()
