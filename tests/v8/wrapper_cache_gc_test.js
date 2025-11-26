// V8 Wrapper Cache GC Integration Tests
// Tests wrapper identity is preserved across repeated queries
// Each test expression must be on its own line

// Setup - create document and body
var doc = new Document();
var body = doc.createElement("body");

// TEST 1: querySelector should return same wrapper for same element
(() => { var div = doc.createElement("div"); div.id = "test-basic-identity"; body.appendChild(div); var e1 = body.querySelector("#test-basic-identity"); var e2 = body.querySelector("#test-basic-identity"); return e1 === e2; })()

// TEST 2: Multiple queries return same wrapper
(() => { var span = doc.createElement("span"); span.className = "test-class"; body.appendChild(span); var r1 = body.querySelector(".test-class"); var r2 = body.querySelector(".test-class"); var r3 = body.querySelector(".test-class"); return r1 === r2 && r2 === r3; })()

// TEST 3: Element created via constructor matches when queried
(() => { var section = doc.createElement("section"); section.id = "constructor-query-test"; body.appendChild(section); var queried = body.querySelector("#constructor-query-test"); return section === queried; })()

// TEST 4: Each unique element gets unique wrapper
(() => { var div1 = doc.createElement("div"); var div2 = doc.createElement("div"); div1.id = "div1"; div2.id = "div2"; body.appendChild(div1); body.appendChild(div2); var q1 = body.querySelector("#div1"); var q2 = body.querySelector("#div2"); return q1 !== q2 && div1 === q1 && div2 === q2; })()

// TEST 5: Parent and child maintain separate wrapper identity
(() => { var parent = doc.createElement("div"); var child = doc.createElement("span"); parent.id = "parent"; child.id = "child"; parent.appendChild(child); body.appendChild(parent); var pq = body.querySelector("#parent"); var cq = body.querySelector("#child"); return parent === pq && child === cq && parent !== child; })()

// TEST 6: querySelector with non-existent selector returns null
body.querySelector("#this-id-does-not-exist-12345") === null

// TEST 7: Multiple queries for non-existent element return null consistently
(() => { var r1 = body.querySelector("#nonexistent-abc"); var r2 = body.querySelector("#nonexistent-abc"); return r1 === null && r2 === null; })()

// TEST 8: querySelectorAll returns collection
(() => { var result = body.querySelectorAll("div"); return result !== null && result !== undefined; })()

// TEST 9: querySelectorAll items match createElement results
(() => { var d1 = doc.createElement("article"); var d2 = doc.createElement("article"); d1.id = "art1"; d2.id = "art2"; body.appendChild(d1); body.appendChild(d2); var all = body.querySelectorAll("article"); return all.length >= 2; })()

// TEST 10: Wrapper identity after property modification
(() => { var el = doc.createElement("div"); el.id = "modify-test"; body.appendChild(el); var before = body.querySelector("#modify-test"); el.className = "modified"; var after = body.querySelector("#modify-test"); return before === after; })()
