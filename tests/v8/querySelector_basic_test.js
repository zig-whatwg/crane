// Basic querySelector/querySelectorAll Tests
// Tests core selector functionality with minimal DOM manipulation
//
// Run with: zig build test-v8

// ============================================================================
// SETUP - Create minimal test structure
// ============================================================================

var doc = new Document();
var body = doc.createElement("body");

// Create simple elements without property setters
var header = doc.createElement("header");
var main = doc.createElement("main");
var footer = doc.createElement("footer");
var div1 = doc.createElement("div");
var div2 = doc.createElement("div");
var div3 = doc.createElement("div");
var section1 = doc.createElement("section");
var section2 = doc.createElement("section");
var article = doc.createElement("article");
var p = doc.createElement("p");
var span = doc.createElement("span");
var a = doc.createElement("a");
var button = doc.createElement("button");
var input = doc.createElement("input");

// Build tree structure
var _b1 = body.appendChild(header);
var _b2 = body.appendChild(main);
var _m1 = main.appendChild(section1);
var _m2 = main.appendChild(section2);
var _s1a = section1.appendChild(div1);
var _s1b = section1.appendChild(div2);
var _s2a = section2.appendChild(div3);
var _s2b = section2.appendChild(article);
var _art = article.appendChild(p);
var _p = p.appendChild(span);
var _d1 = div1.appendChild(a);
var _d2 = div2.appendChild(button);
var _d3 = div3.appendChild(input);
var _b3 = body.appendChild(footer);

// ============================================================================
// TYPE SELECTOR TESTS
// ============================================================================

// querySelector finds first match
assert.strictEqual(body.querySelector("header"), header, "querySelector should find header")
assert.strictEqual(body.querySelector("main"), main, "querySelector should find main")
assert.strictEqual(body.querySelector("footer"), footer, "querySelector should find footer")
assert.strictEqual(body.querySelector("section"), section1, "querySelector should find first section")
assert.strictEqual(body.querySelector("div"), div1, "querySelector should find first div")
assert.strictEqual(body.querySelector("article"), article, "querySelector should find article")
assert.strictEqual(body.querySelector("p"), p, "querySelector should find p")
assert.strictEqual(body.querySelector("span"), span, "querySelector should find span")
assert.strictEqual(body.querySelector("a"), a, "querySelector should find a")
assert.strictEqual(body.querySelector("button"), button, "querySelector should find button")
assert.strictEqual(body.querySelector("input"), input, "querySelector should find input")

// querySelector returns null for non-existent
assert.strictEqual(body.querySelector("table"), null, "querySelector should return null for table")
assert.strictEqual(body.querySelector("form"), null, "querySelector should return null for form")
assert.strictEqual(body.querySelector("h1"), null, "querySelector should return null for h1")

// ============================================================================
// DESCENDANT COMBINATOR TESTS (space)
// ============================================================================

// Simple descendant
assert.strictEqual(body.querySelector("main section"), section1, "main section should find section1")
assert.strictEqual(body.querySelector("section div"), div1, "section div should find div1")
assert.strictEqual(body.querySelector("section article"), article, "section article should find article")
assert.strictEqual(body.querySelector("article p"), p, "article p should find p")
assert.strictEqual(body.querySelector("p span"), span, "p span should find span")

// Multi-level descendant
assert.strictEqual(body.querySelector("main section div"), div1, "main section div should find div1")
assert.strictEqual(body.querySelector("main section article"), article, "main section article should find article")
assert.strictEqual(body.querySelector("section article p"), p, "section article p should find p")
assert.strictEqual(body.querySelector("article p span"), span, "article p span should find span")

// Deep nesting
assert.strictEqual(body.querySelector("main section article p span"), span, "deep nesting should find span")
assert.strictEqual(body.querySelector("body main section div"), div1, "body main section div should find div1")

// Descendant not found
assert.strictEqual(body.querySelector("header section"), null, "header section should be null")
assert.strictEqual(body.querySelector("footer div"), null, "footer div should be null")
assert.strictEqual(body.querySelector("span article"), null, "span article (wrong order) should be null")

// ============================================================================
// CHILD COMBINATOR TESTS (>)
// ============================================================================

// Direct child
assert.strictEqual(body.querySelector("body > header"), header, "body > header should find header")
assert.strictEqual(body.querySelector("body > main"), main, "body > main should find main")
assert.strictEqual(body.querySelector("body > footer"), footer, "body > footer should find footer")
assert.strictEqual(body.querySelector("main > section"), section1, "main > section should find section1")
assert.strictEqual(body.querySelector("section > div"), div1, "section > div should find div1")
assert.strictEqual(body.querySelector("article > p"), p, "article > p should find p")
assert.strictEqual(body.querySelector("p > span"), span, "p > span should find span")

// Child vs descendant distinction
assert.strictEqual(body.querySelector("body main"), main, "body main (descendant) should find main")
assert.strictEqual(body.querySelector("body > main"), main, "body > main (child) should find main")
assert.strictEqual(body.querySelector("body section"), section1, "body section (descendant) should find section1")
assert.strictEqual(body.querySelector("body > section"), null, "body > section should be null (not direct child)")

// Multiple levels of child selectors
assert.strictEqual(body.querySelector("main > section > div"), div1, "main > section > div should find div1")
assert.strictEqual(body.querySelector("section > article > p"), p, "section > article > p should find p")

// ============================================================================
// QUERYSELECTORALL TESTS
// ============================================================================

// querySelectorAll returns collection
assert.isTrue((() => {
    var sections = body.querySelectorAll("section");
    return sections !== null && sections !== undefined;
})(), "querySelectorAll should return a collection")

// Count all divs
assert.strictEqual(body.querySelectorAll("div").length, 3, "querySelectorAll('div') should find 3 divs")

// Count all sections
assert.strictEqual(body.querySelectorAll("section").length, 2, "querySelectorAll('section') should find 2 sections")

// Count with descendant selector
assert.strictEqual(body.querySelectorAll("main section").length, 2, "querySelectorAll('main section') should find 2 sections")

// Count all elements of multiple types
assert.strictEqual(body.querySelectorAll("section, div").length, 5, "querySelectorAll('section, div') should find 5 elements")

// querySelectorAll with child selector
assert.strictEqual(main.querySelectorAll("main > section").length, 2, "main.querySelectorAll('main > section') should find 2 sections")

// ============================================================================
// SCOPING TESTS
// ============================================================================

// querySelector respects scope
assert.strictEqual(header.querySelector("section"), null, "header.querySelector('section') should be null")
assert.strictEqual(main.querySelector("section"), section1, "main.querySelector('section') should find section1")
assert.strictEqual(section1.querySelector("div"), div1, "section1.querySelector('div') should find div1")
assert.strictEqual(section2.querySelector("div"), div3, "section2.querySelector('div') should find div3")

// querySelectorAll respects scope
assert.strictEqual(header.querySelectorAll("div").length, 0, "header.querySelectorAll('div') should find 0")
assert.strictEqual(main.querySelectorAll("div").length, 3, "main.querySelectorAll('div') should find 3")
assert.strictEqual(section1.querySelectorAll("div").length, 2, "section1.querySelectorAll('div') should find 2")
assert.strictEqual(section2.querySelectorAll("div").length, 1, "section2.querySelectorAll('div') should find 1")

// ============================================================================
// ELEMENT TYPE TESTS
// ============================================================================

// Find specific element types
assert.strictEqual(body.querySelector("span"), span, "body.querySelector('span') should find span")
assert.strictEqual(body.querySelector("a"), a, "body.querySelector('a') should find a")
assert.strictEqual(body.querySelector("button"), button, "body.querySelector('button') should find button")
assert.strictEqual(body.querySelector("input"), input, "body.querySelector('input') should find input")

// Find nested elements
assert.strictEqual(section1.querySelector("a"), a, "section1.querySelector('a') should find a")
assert.strictEqual(section1.querySelector("button"), button, "section1.querySelector('button') should find button")
assert.strictEqual(section2.querySelector("input"), input, "section2.querySelector('input') should find input")
assert.strictEqual(article.querySelector("span"), span, "article.querySelector('span') should find span")

// ============================================================================
// MULTIPLE SELECTOR TESTS (comma)
// ============================================================================

// First match from list
assert.strictEqual(body.querySelector("header, main"), header, "header, main should find header first")
assert.strictEqual(body.querySelector("main, footer"), main, "main, footer should find main first")
assert.strictEqual(body.querySelector("section, div"), section1, "section, div should find section1 first")

// querySelectorAll with multiple selectors
assert.strictEqual(body.querySelectorAll("header, footer").length, 2, "querySelectorAll('header, footer') should find 2")
assert.strictEqual(body.querySelectorAll("header, main, footer").length, 3, "querySelectorAll('header, main, footer') should find 3")

// ============================================================================
// COMPLEX SELECTORS
// ============================================================================

// Combining descendant and child
assert.strictEqual(body.querySelector("main > section div"), div1, "main > section div should find div1")
assert.strictEqual(body.querySelector("body > main section"), section1, "body > main section should find section1")

// Deep nesting with different combinators
assert.strictEqual(body.querySelector("body main > section > div"), div1, "body main > section > div should find div1")
assert.strictEqual(body.querySelector("main section > article > p"), p, "main section > article > p should find p")

// Multiple types with descendant
assert.strictEqual(body.querySelector("section div a"), a, "section div a should find a")
assert.strictEqual(body.querySelector("section div button"), button, "section div button should find button")

// ============================================================================
// DOCUMENT ORDER TESTS
// ============================================================================

// querySelector returns first in document order
assert.strictEqual(body.querySelector("div"), div1, "querySelector('div') should return div1 (first)")
assert.strictEqual(body.querySelector("section"), section1, "querySelector('section') should return section1 (first)")

// querySelectorAll returns in document order
assert.isTrue((() => {
    var divs = body.querySelectorAll("div");
    return divs[0] === div1 && divs[1] === div2 && divs[2] === div3;
})(), "querySelectorAll should return divs in document order")

// ============================================================================
// NULL/EMPTY TESTS
// ============================================================================

// Non-existent selectors return null
assert.strictEqual(body.querySelector("nonexistent"), null, "querySelector('nonexistent') should be null")
assert.strictEqual(body.querySelector("table"), null, "querySelector('table') should be null")
assert.strictEqual(header.querySelector("div"), null, "header.querySelector('div') should be null")

// querySelectorAll returns empty for non-existent
assert.strictEqual(body.querySelectorAll("nonexistent").length, 0, "querySelectorAll('nonexistent') should return empty")
assert.strictEqual(header.querySelectorAll("section").length, 0, "header.querySelectorAll('section') should return empty")

// ============================================================================
// SUMMARY
// ============================================================================

// Verify core functionality
assert.isTrue(
    body.querySelector("header") === header &&
    body.querySelector("main section") === section1 &&
    body.querySelectorAll("div").length === 3 &&
    body.querySelector("main > section > div") === div1 &&
    main.querySelector("section") === section1,
    "Core querySelector functionality should work correctly"
)
