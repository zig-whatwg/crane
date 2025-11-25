// Debug: Force multiple operations to see if wrapper caching works

// This test will create one element, then try to retrieve it multiple ways
var doc = new Document();
var body = doc.createElement("body");
var div = doc.createElement("div");

// Store div reference
var originalDiv = div;

// Append to body
body.appendChild(div);

// Test 1: Original reference works
originalDiv === div

// Test 2: Try to get from body's children (if that API exists)
// For now, just test querySelector
var retrieved = body.querySelector("div");

// Test 3: Retrieved is not null
retrieved !== null

// Test 4: Retrieved equals original (CRITICAL TEST)
retrieved === originalDiv

// Test 5: Multiple querySelector calls return same wrapper
var retrieved2 = body.querySelector("div");
retrieved === retrieved2
