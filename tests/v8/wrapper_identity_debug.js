// Debug wrapper identity

var doc = new Document();
var div1 = doc.createElement("div");
var div2 = doc.createElement("div");

// Test 1: Different elements should NOT be equal
div1 !== div2

// Test 2: Same element should be equal to itself
div1 === div1

// Test 3: Append and retrieve
var body = doc.createElement("body");
body.appendChild(div1);
var retrieved = body.querySelector("div");

// Test 4: Retrieved element should be non-null
retrieved !== null

// Test 5: Retrieved element should equal original (WRAPPER IDENTITY TEST)
retrieved === div1

// Test 6: Multiple calls should return same wrapper
body.querySelector("div") === body.querySelector("div")
