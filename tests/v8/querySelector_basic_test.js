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
body.appendChild(header);
body.appendChild(main);
main.appendChild(section1);
main.appendChild(section2);
section1.appendChild(div1);
section1.appendChild(div2);
section2.appendChild(div3);
section2.appendChild(article);
article.appendChild(p);
p.appendChild(span);
div1.appendChild(a);
div2.appendChild(button);
div3.appendChild(input);
body.appendChild(footer);

// ============================================================================
// TYPE SELECTOR TESTS
// ============================================================================

// querySelector finds first match
body.querySelector("header") === header
body.querySelector("main") === main
body.querySelector("footer") === footer
body.querySelector("section") === section1  // First section
body.querySelector("div") === div1  // First div
body.querySelector("article") === article
body.querySelector("p") === p
body.querySelector("span") === span
body.querySelector("a") === a
body.querySelector("button") === button
body.querySelector("input") === input

// querySelector returns null for non-existent
body.querySelector("table") === null
body.querySelector("form") === null
body.querySelector("h1") === null

// ============================================================================
// DESCENDANT COMBINATOR TESTS (space)
// ============================================================================

// Simple descendant
body.querySelector("main section") === section1
body.querySelector("section div") === div1
body.querySelector("section article") === article
body.querySelector("article p") === p
body.querySelector("p span") === span

// Multi-level descendant
body.querySelector("main section div") === div1
body.querySelector("main section article") === article
body.querySelector("section article p") === p
body.querySelector("article p span") === span

// Deep nesting
body.querySelector("main section article p span") === span
body.querySelector("body main section div") === div1

// Descendant not found
body.querySelector("header section") === null
body.querySelector("footer div") === null
body.querySelector("span article") === null  // Wrong order

// ============================================================================
// CHILD COMBINATOR TESTS (>)
// ============================================================================

// Direct child
body.querySelector("body > header") === header
body.querySelector("body > main") === main
body.querySelector("body > footer") === footer
body.querySelector("main > section") === section1
body.querySelector("section > div") === div1
body.querySelector("article > p") === p
body.querySelector("p > span") === span

// Child vs descendant distinction
body.querySelector("body main") === main  // Descendant works
body.querySelector("body > main") === main  // Direct child also works
body.querySelector("body section") === section1  // Descendant works
body.querySelector("body > section") === null  // Not direct child

// Multiple levels of child selectors
body.querySelector("main > section > div") === div1
body.querySelector("section > article > p") === p

// ============================================================================
// QUERYSELECTORALL TESTS
// ============================================================================

// querySelectorAll returns collection
(() => {
    var sections = body.querySelectorAll("section");
    return sections !== null && sections !== undefined;
})()

// Count all divs
(() => {
    var divs = body.querySelectorAll("div");
    return divs.length === 3;
})()

// Count all sections
(() => {
    var sections = body.querySelectorAll("section");
    return sections.length === 2;
})()

// Count with descendant selector
(() => {
    var mainSections = body.querySelectorAll("main section");
    return mainSections.length === 2;
})()

// Count all elements of multiple types
(() => {
    var elements = body.querySelectorAll("section, div");
    return elements.length === 5;  // 2 sections + 3 divs
})()

// querySelectorAll with child selector
(() => {
    var directChildren = main.querySelectorAll("main > section");
    return directChildren.length === 2;
})()

// ============================================================================
// SCOPING TESTS
// ============================================================================

// querySelector respects scope
header.querySelector("section") === null  // section not in header
main.querySelector("section") === section1  // section is in main
section1.querySelector("div") === div1  // div1 is in section1
section2.querySelector("div") === div3  // div3 is in section2

// querySelectorAll respects scope
(() => {
    var headerDivs = header.querySelectorAll("div");
    return headerDivs.length === 0;
})()

(() => {
    var mainDivs = main.querySelectorAll("div");
    return mainDivs.length === 3;
})()

(() => {
    var section1Divs = section1.querySelectorAll("div");
    return section1Divs.length === 2;
})()

(() => {
    var section2Divs = section2.querySelectorAll("div");
    return section2Divs.length === 1;
})()

// ============================================================================
// ELEMENT TYPE TESTS
// ============================================================================

// Find specific element types
body.querySelector("span") === span
body.querySelector("a") === a
body.querySelector("button") === button
body.querySelector("input") === input

// Find nested elements
section1.querySelector("a") === a
section1.querySelector("button") === button
section2.querySelector("input") === input
article.querySelector("span") === span

// ============================================================================
// MULTIPLE SELECTOR TESTS (comma)
// ============================================================================

// First match from list
body.querySelector("header, main") === header
body.querySelector("main, footer") === main
body.querySelector("section, div") === section1  // section comes first in tree

// querySelectorAll with multiple selectors
(() => {
    var elements = body.querySelectorAll("header, footer");
    return elements.length === 2;
})()

(() => {
    var elements = body.querySelectorAll("header, main, footer");
    return elements.length === 3;
})()

// ============================================================================
// COMPLEX SELECTORS
// ============================================================================

// Combining descendant and child
body.querySelector("main > section div") === div1
body.querySelector("body > main section") === section1

// Deep nesting with different combinators
body.querySelector("body main > section > div") === div1
body.querySelector("main section > article > p") === p

// Multiple types with descendant
body.querySelector("section div a") === a
body.querySelector("section div button") === button

// ============================================================================
// DOCUMENT ORDER TESTS
// ============================================================================

// querySelector returns first in document order
body.querySelector("div") === div1  // div1 comes before div2 and div3
body.querySelector("section") === section1  // section1 comes before section2

// querySelectorAll returns in document order
(() => {
    var divs = body.querySelectorAll("div");
    return divs[0] === div1 && divs[1] === div2 && divs[2] === div3;
})()

// ============================================================================
// NULL/EMPTY TESTS
// ============================================================================

// Non-existent selectors return null
body.querySelector("nonexistent") === null
body.querySelector("table") === null
header.querySelector("div") === null

// querySelectorAll returns empty for non-existent
(() => {
    var elements = body.querySelectorAll("nonexistent");
    return elements.length === 0;
})()

(() => {
    var elements = header.querySelectorAll("section");
    return elements.length === 0;
})()

// ============================================================================
// SUMMARY
// ============================================================================

// Verify core functionality
body.querySelector("header") === header &&
body.querySelector("main section") === section1 &&
body.querySelectorAll("div").length === 3 &&
body.querySelector("main > section > div") === div1 &&
main.querySelector("section") === section1
