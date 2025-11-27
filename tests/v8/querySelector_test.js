// Comprehensive querySelector/querySelectorAll Tests
// Tests CSS selector matching per Selectors API specification
//
// Run with: zig build test-v8
//
// Test format: Each test is an expression that evaluates to true/false.
// The test runner shows the failing expression when a test fails.

// ============================================================================
// SETUP - Create test document structure
// ============================================================================

// Helper to create a test document with a complex DOM tree
var doc = new Document();

// Create root structure: html > body
var html = doc.createElement("html");
var body = doc.createElement("body");

// Create header section
var header = doc.createElement("header");
header.id = "main-header";
header.className = "header primary";

var h1 = doc.createElement("h1");
h1.className = "title";
h1.textContent = "Test Document";
header.appendChild(h1);

var nav = doc.createElement("nav");
nav.className = "navigation";
header.appendChild(nav);

// Create navigation links
var navList = doc.createElement("ul");
for (var i = 1; i <= 3; i++) {
    var li = doc.createElement("li");
    var a = doc.createElement("a");
    a.setAttribute("href", "#section" + i);  // Use setAttribute so [href] selector works
    a.className = "nav-link";
    a.textContent = "Section " + i;
    li.appendChild(a);
    navList.appendChild(li);
}
nav.appendChild(navList);

// Create main content area
var main = doc.createElement("main");
main.id = "content";
main.className = "main-content";

// Create multiple sections with various structures
for (var i = 1; i <= 3; i++) {
    var section = doc.createElement("section");
    section.id = "section" + i;
    section.className = "content-section";
    section.setAttribute("data-priority", i === 1 ? "high" : "normal");
    
    var h2 = doc.createElement("h2");
    h2.textContent = "Section " + i + " Title";
    section.appendChild(h2);
    
    var p = doc.createElement("p");
    p.className = "description";
    p.textContent = "This is section " + i + " content.";
    section.appendChild(p);
    
    // Add nested divs in section 2
    if (i === 2) {
        var container = doc.createElement("div");
        container.className = "nested-container";
        
        var innerDiv = doc.createElement("div");
        innerDiv.className = "inner-content highlight";
        innerDiv.textContent = "Nested content";
        container.appendChild(innerDiv);
        
        var specialSpan = doc.createElement("span");
        specialSpan.className = "special";
        specialSpan.setAttribute("data-type", "info");
        specialSpan.textContent = "Important info";
        innerDiv.appendChild(specialSpan);
        
        section.appendChild(container);
    }
    
    main.appendChild(section);
}

// Create sidebar with form
var aside = doc.createElement("aside");
aside.id = "sidebar";
aside.className = "sidebar secondary";

var form = doc.createElement("form");
form.id = "contact-form";
form.className = "form";

var inputName = doc.createElement("input");
inputName.setAttribute("type", "text");  // Use setAttribute for attribute selectors to work
inputName.setAttribute("name", "name");  // Use setAttribute for attribute selectors to work
inputName.className = "form-input";
inputName.placeholder = "Name";
form.appendChild(inputName);

var inputEmail = doc.createElement("input");
inputEmail.setAttribute("type", "email");  // Use setAttribute for attribute selectors to work
inputEmail.setAttribute("name", "email");  // Use setAttribute for attribute selectors to work
inputEmail.className = "form-input";
inputEmail.setAttribute("required", "");  // Use setAttribute for attribute selectors to work
form.appendChild(inputEmail);

var textarea = doc.createElement("textarea");
textarea.setAttribute("name", "message");  // Use setAttribute for attribute selectors to work
textarea.className = "form-input";
textarea.rows = 5;
form.appendChild(textarea);

var submitBtn = doc.createElement("button");
submitBtn.setAttribute("type", "submit");  // Use setAttribute for attribute selectors to work
submitBtn.className = "btn primary";
submitBtn.textContent = "Submit";
form.appendChild(submitBtn);

aside.appendChild(form);

// Create footer
var footer = doc.createElement("footer");
footer.id = "page-footer";
footer.className = "footer";

var footerText = doc.createElement("p");
footerText.textContent = "© 2024 Test Document";
footer.appendChild(footerText);

// Assemble document
body.appendChild(header);
body.appendChild(main);
body.appendChild(aside);
body.appendChild(footer);
html.appendChild(body);
// Note: Can't append to doc directly, but we can query from body

// ============================================================================
// BASIC SELECTOR TESTS
// ============================================================================

// querySelector returns first match or null
body.querySelector("#main-header") === header
body.querySelector(".title") === h1
body.querySelector("nav") === nav
body.querySelector("#nonexistent") === null
body.querySelector(".nonexistent") === null

// querySelectorAll returns NodeList (or similar collection)
(() => {
    var result = body.querySelectorAll("section");
    return result !== null && result !== undefined;
})()

// ID selector
body.querySelector("#content") === main
body.querySelector("#sidebar") === aside
body.querySelector("#section1") !== null
body.querySelector("#section2") !== null

// Class selector (single class)
body.querySelector(".title") === h1
body.querySelector(".navigation") === nav
body.querySelector(".description") !== null

// Type selector
body.querySelector("header") === header
body.querySelector("main") === main
body.querySelector("footer") === footer
body.querySelector("section") !== null
body.querySelector("form") === form

// ============================================================================
// DESCENDANT COMBINATOR TESTS
// ============================================================================

// Space combinator (descendant)
body.querySelector("header h1") === h1
body.querySelector("nav ul") === navList
body.querySelector("main section") !== null
body.querySelector("aside form") === form
body.querySelector("section p") !== null

// Multi-level descendant
body.querySelector("nav ul li") !== null
body.querySelector("main section p") !== null
body.querySelector("aside form input") !== null

// Deep nesting
body.querySelector("section .nested-container .inner-content") !== null
body.querySelector("section .nested-container .inner-content .special") !== null

// ============================================================================
// CHILD COMBINATOR TESTS
// ============================================================================

// Direct child (>)
body.querySelector("header > h1") === h1
body.querySelector("nav > ul") === navList
body.querySelector("main > section") !== null
body.querySelector("form > input") !== null
body.querySelector("form > button") === submitBtn

// Child vs descendant distinction
body.querySelector("body > header") === header
body.querySelector("body > main") === main
body.querySelector("body section") !== null
body.querySelector("body > section") === null  // section is child of main, not body

// ============================================================================
// ATTRIBUTE SELECTOR TESTS
// ============================================================================

// Attribute existence
body.querySelector("[id]") !== null
body.querySelector("[class]") !== null
body.querySelector("[data-priority]") !== null
body.querySelector("[data-type]") !== null
body.querySelector("[href]") !== null
body.querySelector("[type]") !== null

// Attribute exact value
body.querySelector("[id='main-header']") === header
body.querySelector("[id='content']") === main
body.querySelector("[data-priority='high']") !== null
body.querySelector("[data-type='info']") !== null
body.querySelector("[type='text']") === inputName
body.querySelector("[type='email']") === inputEmail
body.querySelector("[type='submit']") === submitBtn

// Attribute contains word ([attr~=value])
// class="header primary" should match [class~="primary"]
body.querySelector("[class~='primary']") !== null
body.querySelector("[class~='header']") !== null
body.querySelector("[class~='secondary']") === aside

// Attribute starts with ([attr^=value])
body.querySelector("[id^='section']") !== null
body.querySelector("[class^='form']") !== null
body.querySelector("[class^='nav']") !== null

// Attribute ends with ([attr$=value])
body.querySelector("[id$='header']") === header
body.querySelector("[id$='footer']") === footer
body.querySelector("[class$='primary']") !== null

// Attribute contains substring ([attr*=value])
body.querySelector("[id*='section']") !== null
body.querySelector("[class*='content']") !== null
body.querySelector("[href*='section']") !== null

// ============================================================================
// CLASS SELECTOR TESTS (MULTIPLE CLASSES)
// ============================================================================

// Single class match
body.querySelector(".title") === h1
body.querySelector(".navigation") === nav
body.querySelector(".description") !== null
body.querySelector(".form-input") !== null

// Multiple class match (element must have all)
body.querySelector(".header.primary") === header
body.querySelector(".sidebar.secondary") === aside
body.querySelector(".inner-content.highlight") !== null
body.querySelector(".btn.primary") === submitBtn

// Class with descendant
body.querySelector(".content-section .description") !== null
body.querySelector(".nested-container .special") !== null
body.querySelector(".form .form-input") !== null

// ============================================================================
// PSEUDO-CLASS TESTS
// ============================================================================

// :first-child
body.querySelector("ul li:first-child") !== null
body.querySelector("main section:first-child") !== null

// :last-child
body.querySelector("ul li:last-child") !== null
body.querySelector("main section:last-child") !== null

// :nth-child(n)
body.querySelector("section:nth-child(1)") !== null
body.querySelector("section:nth-child(2)") !== null
body.querySelector("li:nth-child(2)") !== null

// :nth-child(odd) and :nth-child(even)
body.querySelector("section:nth-child(odd)") !== null
body.querySelector("section:nth-child(even)") !== null

// :only-child
body.querySelector("header h1:only-child") === null  // h1 is not only child (nav exists)
body.querySelector("footer p:only-child") === footerText  // p is only child in footer

// :empty
// Note: Elements with text content are not empty
// We'd need to create an empty element for this test

// ============================================================================
// COMBINING SELECTORS TESTS
// ============================================================================

// Multiple selectors (comma-separated, OR logic)
body.querySelector("h1, h2") !== null  // Should match h1 first
body.querySelector("header, footer") === header  // Should match first found
body.querySelector(".title, .description") === h1  // Should match first

// Complex combinations
body.querySelector("main section.content-section") !== null
body.querySelector("#content section[data-priority='high']") !== null
body.querySelector("aside #contact-form .form-input") !== null
body.querySelector("section > .description") !== null
body.querySelector("nav ul li a.nav-link") !== null

// Very complex selectors
body.querySelector("body > main#content > section.content-section[data-priority]") !== null
body.querySelector("section .nested-container > .inner-content.highlight .special[data-type='info']") !== null
body.querySelector("aside#sidebar form#contact-form input.form-input[type='email'][required]") === inputEmail

// ============================================================================
// QUERYSELECTORALL TESTS
// ============================================================================

// querySelectorAll returns all matches
(() => {
    var sections = body.querySelectorAll("section");
    return sections.length === 3;
})()

(() => {
    var links = body.querySelectorAll("a.nav-link");
    return links.length === 3;
})()

(() => {
    var formInputs = body.querySelectorAll(".form-input");
    return formInputs.length === 3;  // 2 inputs + 1 textarea
})()

// querySelectorAll with descendant selector
(() => {
    var navItems = body.querySelectorAll("nav ul li");
    return navItems.length === 3;
})()

// querySelectorAll with attribute selector
(() => {
    var priorityElements = body.querySelectorAll("[data-priority]");
    return priorityElements.length >= 1;
})()

// querySelectorAll with multiple classes
(() => {
    var results = body.querySelectorAll(".content-section");
    return results.length === 3;
})()

// querySelectorAll with :nth-child
(() => {
    var results = body.querySelectorAll("section:nth-child(odd)");
    return results.length >= 1;
})()

// querySelectorAll with comma-separated selectors
(() => {
    var results = body.querySelectorAll("h1, h2");
    return results.length === 4;  // 1 h1 + 3 h2
})()

// ============================================================================
// EDGE CASES AND ERROR HANDLING
// ============================================================================

// Invalid selector should throw or return null
(() => {
    try {
        var result = body.querySelector("");
        return result === null;
    } catch(e) {
        return true;  // Throwing is also acceptable
    }
})()

// querySelector on element (not just document)
header.querySelector("h1") === h1
nav.querySelector("ul") === navList
main.querySelector("section") !== null
form.querySelector("button") === submitBtn
aside.querySelector("form") === form

// querySelectorAll on element
(() => {
    var mainSections = main.querySelectorAll("section");
    return mainSections.length === 3;
})()

(() => {
    var formElements = form.querySelectorAll("input, textarea, button");
    return formElements.length === 4;
})()

// Case sensitivity
// Per CSS Selectors spec, type selectors are case-INSENSITIVE in HTML documents
body.querySelector("HEADER") === header  // HTML type selectors are case-insensitive
body.querySelector("header") === header
body.querySelector("[ID='main-header']") === header  // Attribute names are case-insensitive in HTML
body.querySelector("[id='main-header']") === header
body.querySelector("[class='TITLE']") === null  // Attribute values are case-sensitive
body.querySelector("[class='title']") === h1

// querySelector returns first match in document order
(() => {
    var first = body.querySelector(".content-section");
    return first.id === "section1";
})()

// Selector scoping - querySelector only finds descendants
(() => {
    var result = header.querySelector("footer");
    return result === null;  // footer is sibling, not descendant
})()

// ============================================================================
// PERFORMANCE AND STRESS TESTS
// ============================================================================

// Deeply nested selector
body.querySelector("body > main > section > .nested-container > .inner-content > .special") !== null

// Long comma-separated selector list
body.querySelector("h1, h2, h3, h4, h5, h6, p, div, span, a, ul, li, input, button, form, header, footer, nav, section, aside, main") !== null

// Multiple attribute selectors combined
body.querySelector("input[type='email'][class='form-input'][name='email'][required]") === inputEmail

// Selector with all combinator types
body.querySelector("body main#content > section.content-section[data-priority] .nested-container .inner-content.highlight") !== null

// ============================================================================
// REAL-WORLD SCENARIOS
// ============================================================================

// Find all interactive elements
(() => {
    var interactive = body.querySelectorAll("a, button, input, textarea, select");
    return interactive.length >= 5;
})()

// Find all elements with specific data attributes
(() => {
    var dataElements = body.querySelectorAll("[data-priority], [data-type]");
    return dataElements.length >= 2;
})()

// Find form elements by type
(() => {
    var textInputs = body.querySelectorAll("input[type='text'], input[type='email'], textarea");
    return textInputs.length === 3;
})()

// Find all headings
(() => {
    var headings = body.querySelectorAll("h1, h2, h3, h4, h5, h6");
    return headings.length === 4;  // 1 h1 + 3 h2
})()

// Find elements by class prefix pattern
(() => {
    var formElements = body.querySelectorAll("[class^='form']");
    return formElements.length >= 4;
})()

// Find nested elements at specific depth
body.querySelector("main > section > div > div > span") !== null

// Find elements with multiple conditions
(() => {
    var specialInputs = body.querySelectorAll("form input.form-input[type]:not([type='submit'])");
    return specialInputs.length === 2;
})()

// ============================================================================
// DOCUMENT VS ELEMENT SCOPING
// ============================================================================

// querySelector from different scopes gives different results
body.querySelector("section") !== null
header.querySelector("section") === null  // No section in header
main.querySelector("section") !== null  // Sections are in main

// querySelectorAll scoping
(() => {
    var bodyInputs = body.querySelectorAll("input");
    var formInputs = form.querySelectorAll("input");
    return bodyInputs.length >= formInputs.length && formInputs.length === 2;
})()

// Finding elements in specific subtree
(() => {
    var headerLinks = header.querySelectorAll("a");
    return headerLinks.length === 3;  // Only nav links in header
})()

// ============================================================================
// SUMMARY VALIDATION
// ============================================================================

// Verify core functionality works
body.querySelector("#main-header") === header &&
body.querySelector(".title") === h1 &&
body.querySelectorAll("section").length === 3 &&
body.querySelector("section .special[data-type='info']") !== null &&
form.querySelectorAll(".form-input").length === 3
