// Debug: Force multiple operations to see if wrapper caching works

// This test will create one element, then try to retrieve it multiple ways
var doc = new Document();
var body = doc.createElement("body");
var div = doc.createElement("div");

// Store div reference
var originalDiv = div;

// Append to body
var _append = body.appendChild(div);

// Test 1: Original reference works
assert.strictEqual(originalDiv, div, "Original reference should equal div")

// Test 2: Try to get from body's children (if that API exists)
// For now, just test querySelector
var retrieved = body.querySelector("div");

// Test 3: Retrieved is not null
assert.isNotNull(retrieved, "Retrieved element should not be null")

// Test 4: Retrieved equals original (CRITICAL TEST)
assert.strictEqual(retrieved, originalDiv, "Retrieved element should equal original")

// Test 5: Multiple querySelector calls return same wrapper
var retrieved2 = body.querySelector("div");
assert.strictEqual(retrieved, retrieved2, "Multiple querySelector calls should return same wrapper")
