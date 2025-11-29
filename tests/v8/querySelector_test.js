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
var _h1app = header.appendChild(h1);

var nav = doc.createElement("nav");
nav.className = "navigation";
var _navapp = header.appendChild(nav);

// Create navigation links
var navList = doc.createElement("ul");
for (var i = 1; i <= 3; i++) {
    var li = doc.createElement("li");
    var a = doc.createElement("a");
    a.setAttribute("href", "#section" + i);  // Use setAttribute so [href] selector works
    a.className = "nav-link";
    a.textContent = "Section " + i;
    var _aapp = li.appendChild(a);
    var _liapp = navList.appendChild(li);
}
var _navlistapp = nav.appendChild(navList);

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
    var _h2app = section.appendChild(h2);
    
    var p = doc.createElement("p");
    p.className = "description";
    p.textContent = "This is section " + i + " content.";
    var _papp = section.appendChild(p);
    
    // Add nested divs in section 2
    if (i === 2) {
        var container = doc.createElement("div");
        container.className = "nested-container";
        
        var innerDiv = doc.createElement("div");
        innerDiv.className = "inner-content highlight";
        innerDiv.textContent = "Nested content";
        var _innerdivapp = container.appendChild(innerDiv);
        
        var specialSpan = doc.createElement("span");
        specialSpan.className = "special";
        specialSpan.setAttribute("data-type", "info");
        specialSpan.textContent = "Important info";
        var _spanapp = innerDiv.appendChild(specialSpan);
        
        var _containerapp = section.appendChild(container);
    }
    
    var _sectionapp = main.appendChild(section);
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
var _inputnameapp = form.appendChild(inputName);

var inputEmail = doc.createElement("input");
inputEmail.setAttribute("type", "email");  // Use setAttribute for attribute selectors to work
inputEmail.setAttribute("name", "email");  // Use setAttribute for attribute selectors to work
inputEmail.className = "form-input";
inputEmail.setAttribute("required", "");  // Use setAttribute for attribute selectors to work
var _inputemailapp = form.appendChild(inputEmail);

var textarea = doc.createElement("textarea");
textarea.setAttribute("name", "message");  // Use setAttribute for attribute selectors to work
textarea.className = "form-input";
textarea.rows = 5;
var _textareaapp = form.appendChild(textarea);

var submitBtn = doc.createElement("button");
submitBtn.setAttribute("type", "submit");  // Use setAttribute for attribute selectors to work
submitBtn.className = "btn primary";
submitBtn.textContent = "Submit";
var _submitapp = form.appendChild(submitBtn);

var _formapp = aside.appendChild(form);

// Create footer
var footer = doc.createElement("footer");
footer.id = "page-footer";
footer.className = "footer";

var footerText = doc.createElement("p");
footerText.textContent = "© 2024 Test Document";
var _footertextapp = footer.appendChild(footerText);

// Assemble document
var _headerapp = body.appendChild(header);
var _mainapp = body.appendChild(main);
var _asideapp = body.appendChild(aside);
var _footerapp = body.appendChild(footer);
var _bodyapp = html.appendChild(body);
// Note: Can't append to doc directly, but we can query from body

// ============================================================================
// BASIC SELECTOR TESTS
// ============================================================================

// querySelector returns first match or null
assert.strictEqual(body.querySelector("#main-header"), header, "querySelector should find #main-header")
assert.strictEqual(body.querySelector(".title"), h1, "querySelector should find .title")
assert.strictEqual(body.querySelector("nav"), nav, "querySelector should find nav")
assert.strictEqual(body.querySelector("#nonexistent"), null, "querySelector should return null for #nonexistent")
assert.strictEqual(body.querySelector(".nonexistent"), null, "querySelector should return null for .nonexistent")

// querySelectorAll returns NodeList (or similar collection)
assert.isTrue((() => {
    var result = body.querySelectorAll("section");
    return result !== null && result !== undefined;
})(), "querySelectorAll should return a collection")

// ID selector
assert.strictEqual(body.querySelector("#content"), main, "querySelector should find #content")
assert.strictEqual(body.querySelector("#sidebar"), aside, "querySelector should find #sidebar")
assert.isNotNull(body.querySelector("#section1"), "#section1 should exist")
assert.isNotNull(body.querySelector("#section2"), "#section2 should exist")

// Class selector (single class)
assert.strictEqual(body.querySelector(".title"), h1, ".title should find h1")
assert.strictEqual(body.querySelector(".navigation"), nav, ".navigation should find nav")
assert.isNotNull(body.querySelector(".description"), ".description should exist")

// Type selector
assert.strictEqual(body.querySelector("header"), header, "header selector should find header")
assert.strictEqual(body.querySelector("main"), main, "main selector should find main")
assert.strictEqual(body.querySelector("footer"), footer, "footer selector should find footer")
assert.isNotNull(body.querySelector("section"), "section selector should find element")
assert.strictEqual(body.querySelector("form"), form, "form selector should find form")

// ============================================================================
// DESCENDANT COMBINATOR TESTS
// ============================================================================

// Space combinator (descendant)
assert.strictEqual(body.querySelector("header h1"), h1, "header h1 should find h1")
assert.strictEqual(body.querySelector("nav ul"), navList, "nav ul should find navList")
assert.isNotNull(body.querySelector("main section"), "main section should find element")
assert.strictEqual(body.querySelector("aside form"), form, "aside form should find form")
assert.isNotNull(body.querySelector("section p"), "section p should find element")

// Multi-level descendant
assert.isNotNull(body.querySelector("nav ul li"), "nav ul li should find element")
assert.isNotNull(body.querySelector("main section p"), "main section p should find element")
assert.isNotNull(body.querySelector("aside form input"), "aside form input should find element")

// Deep nesting
assert.isNotNull(body.querySelector("section .nested-container .inner-content"), "deep nesting should find element")
assert.isNotNull(body.querySelector("section .nested-container .inner-content .special"), "deeper nesting should find element")

// ============================================================================
// CHILD COMBINATOR TESTS
// ============================================================================

// Direct child (>)
assert.strictEqual(body.querySelector("header > h1"), h1, "header > h1 should find h1")
assert.strictEqual(body.querySelector("nav > ul"), navList, "nav > ul should find navList")
assert.isNotNull(body.querySelector("main > section"), "main > section should find element")
assert.isNotNull(body.querySelector("form > input"), "form > input should find element")
assert.strictEqual(body.querySelector("form > button"), submitBtn, "form > button should find submitBtn")

// Child vs descendant distinction
assert.strictEqual(body.querySelector("body > header"), header, "body > header should find header")
assert.strictEqual(body.querySelector("body > main"), main, "body > main should find main")
assert.isNotNull(body.querySelector("body section"), "body section (descendant) should find element")
assert.strictEqual(body.querySelector("body > section"), null, "body > section should be null (section is child of main)")

// ============================================================================
// ATTRIBUTE SELECTOR TESTS
// ============================================================================

// Attribute existence
assert.isNotNull(body.querySelector("[id]"), "[id] should find element")
assert.isNotNull(body.querySelector("[class]"), "[class] should find element")
assert.isNotNull(body.querySelector("[data-priority]"), "[data-priority] should find element")
assert.isNotNull(body.querySelector("[data-type]"), "[data-type] should find element")
assert.isNotNull(body.querySelector("[href]"), "[href] should find element")
assert.isNotNull(body.querySelector("[type]"), "[type] should find element")

// Attribute exact value
assert.strictEqual(body.querySelector("[id='main-header']"), header, "[id='main-header'] should find header")
assert.strictEqual(body.querySelector("[id='content']"), main, "[id='content'] should find main")
assert.isNotNull(body.querySelector("[data-priority='high']"), "[data-priority='high'] should find element")
assert.isNotNull(body.querySelector("[data-type='info']"), "[data-type='info'] should find element")
assert.strictEqual(body.querySelector("[type='text']"), inputName, "[type='text'] should find inputName")
assert.strictEqual(body.querySelector("[type='email']"), inputEmail, "[type='email'] should find inputEmail")
assert.strictEqual(body.querySelector("[type='submit']"), submitBtn, "[type='submit'] should find submitBtn")

// Attribute contains word ([attr~=value])
// class="header primary" should match [class~="primary"]
assert.isNotNull(body.querySelector("[class~='primary']"), "[class~='primary'] should find element")
assert.isNotNull(body.querySelector("[class~='header']"), "[class~='header'] should find element")
assert.strictEqual(body.querySelector("[class~='secondary']"), aside, "[class~='secondary'] should find aside")

// Attribute starts with ([attr^=value])
assert.isNotNull(body.querySelector("[id^='section']"), "[id^='section'] should find element")
assert.isNotNull(body.querySelector("[class^='form']"), "[class^='form'] should find element")
assert.isNotNull(body.querySelector("[class^='nav']"), "[class^='nav'] should find element")

// Attribute ends with ([attr$=value])
assert.strictEqual(body.querySelector("[id$='header']"), header, "[id$='header'] should find header")
assert.strictEqual(body.querySelector("[id$='footer']"), footer, "[id$='footer'] should find footer")
assert.isNotNull(body.querySelector("[class$='primary']"), "[class$='primary'] should find element")

// Attribute contains substring ([attr*=value])
assert.isNotNull(body.querySelector("[id*='section']"), "[id*='section'] should find element")
assert.isNotNull(body.querySelector("[class*='content']"), "[class*='content'] should find element")
assert.isNotNull(body.querySelector("[href*='section']"), "[href*='section'] should find element")

// ============================================================================
// CLASS SELECTOR TESTS (MULTIPLE CLASSES)
// ============================================================================

// Single class match
assert.strictEqual(body.querySelector(".title"), h1, ".title should find h1")
assert.strictEqual(body.querySelector(".navigation"), nav, ".navigation should find nav")
assert.isNotNull(body.querySelector(".description"), ".description should find element")
assert.isNotNull(body.querySelector(".form-input"), ".form-input should find element")

// Multiple class match (element must have all)
assert.strictEqual(body.querySelector(".header.primary"), header, ".header.primary should find header")
assert.strictEqual(body.querySelector(".sidebar.secondary"), aside, ".sidebar.secondary should find aside")
assert.isNotNull(body.querySelector(".inner-content.highlight"), ".inner-content.highlight should find element")
assert.strictEqual(body.querySelector(".btn.primary"), submitBtn, ".btn.primary should find submitBtn")

// Class with descendant
assert.isNotNull(body.querySelector(".content-section .description"), ".content-section .description should find element")
assert.isNotNull(body.querySelector(".nested-container .special"), ".nested-container .special should find element")
assert.isNotNull(body.querySelector(".form .form-input"), ".form .form-input should find element")

// ============================================================================
// PSEUDO-CLASS TESTS
// ============================================================================

// :first-child
assert.isNotNull(body.querySelector("ul li:first-child"), "ul li:first-child should find element")
assert.isNotNull(body.querySelector("main section:first-child"), "main section:first-child should find element")

// :last-child
assert.isNotNull(body.querySelector("ul li:last-child"), "ul li:last-child should find element")
assert.isNotNull(body.querySelector("main section:last-child"), "main section:last-child should find element")

// :nth-child(n)
assert.isNotNull(body.querySelector("section:nth-child(1)"), "section:nth-child(1) should find element")
assert.isNotNull(body.querySelector("section:nth-child(2)"), "section:nth-child(2) should find element")
assert.isNotNull(body.querySelector("li:nth-child(2)"), "li:nth-child(2) should find element")

// :nth-child(odd) and :nth-child(even)
assert.isNotNull(body.querySelector("section:nth-child(odd)"), "section:nth-child(odd) should find element")
assert.isNotNull(body.querySelector("section:nth-child(even)"), "section:nth-child(even) should find element")

// :only-child
assert.strictEqual(body.querySelector("header h1:only-child"), null, "h1 is not only child (nav exists)")
assert.strictEqual(body.querySelector("footer p:only-child"), footerText, "footer p:only-child should find footerText")

// ============================================================================
// COMBINING SELECTORS TESTS
// ============================================================================

// Multiple selectors (comma-separated, OR logic)
assert.isNotNull(body.querySelector("h1, h2"), "h1, h2 should find element")
assert.strictEqual(body.querySelector("header, footer"), header, "header, footer should find header first")
assert.strictEqual(body.querySelector(".title, .description"), h1, ".title, .description should find h1 first")

// Complex combinations
assert.isNotNull(body.querySelector("main section.content-section"), "main section.content-section should find element")
assert.isNotNull(body.querySelector("#content section[data-priority='high']"), "#content section[data-priority='high'] should find element")
assert.isNotNull(body.querySelector("aside #contact-form .form-input"), "aside #contact-form .form-input should find element")
assert.isNotNull(body.querySelector("section > .description"), "section > .description should find element")
assert.isNotNull(body.querySelector("nav ul li a.nav-link"), "nav ul li a.nav-link should find element")

// Very complex selectors
assert.isNotNull(body.querySelector("body > main#content > section.content-section[data-priority]"), "very complex selector should find element")
assert.isNotNull(body.querySelector("section .nested-container > .inner-content.highlight .special[data-type='info']"), "complex nested selector should find element")
assert.strictEqual(body.querySelector("aside#sidebar form#contact-form input.form-input[type='email'][required]"), inputEmail, "complex attribute selector should find inputEmail")

// ============================================================================
// QUERYSELECTORALL TESTS
// ============================================================================

// querySelectorAll returns all matches
assert.strictEqual(body.querySelectorAll("section").length, 3, "querySelectorAll('section') should find 3")

assert.strictEqual(body.querySelectorAll("a.nav-link").length, 3, "querySelectorAll('a.nav-link') should find 3")

assert.strictEqual(body.querySelectorAll(".form-input").length, 3, "querySelectorAll('.form-input') should find 3 (2 inputs + 1 textarea)")

// querySelectorAll with descendant selector
assert.strictEqual(body.querySelectorAll("nav ul li").length, 3, "querySelectorAll('nav ul li') should find 3")

// querySelectorAll with attribute selector
assert.isTrue(body.querySelectorAll("[data-priority]").length >= 1, "querySelectorAll('[data-priority]') should find at least 1")

// querySelectorAll with multiple classes
assert.strictEqual(body.querySelectorAll(".content-section").length, 3, "querySelectorAll('.content-section') should find 3")

// querySelectorAll with :nth-child
assert.isTrue(body.querySelectorAll("section:nth-child(odd)").length >= 1, "querySelectorAll('section:nth-child(odd)') should find at least 1")

// querySelectorAll with comma-separated selectors
assert.strictEqual(body.querySelectorAll("h1, h2").length, 4, "querySelectorAll('h1, h2') should find 4 (1 h1 + 3 h2)")

// ============================================================================
// EDGE CASES AND ERROR HANDLING
// ============================================================================

// Invalid selector should throw or return null
assert.isTrue((() => {
    try {
        var result = body.querySelector("");
        return result === null;
    } catch(e) {
        return true;  // Throwing is also acceptable
    }
})(), "Empty selector should return null or throw")

// querySelector on element (not just document)
assert.strictEqual(header.querySelector("h1"), h1, "header.querySelector('h1') should find h1")
assert.strictEqual(nav.querySelector("ul"), navList, "nav.querySelector('ul') should find navList")
assert.isNotNull(main.querySelector("section"), "main.querySelector('section') should find element")
assert.strictEqual(form.querySelector("button"), submitBtn, "form.querySelector('button') should find submitBtn")
assert.strictEqual(aside.querySelector("form"), form, "aside.querySelector('form') should find form")

// querySelectorAll on element
assert.strictEqual(main.querySelectorAll("section").length, 3, "main.querySelectorAll('section') should find 3")

assert.strictEqual(form.querySelectorAll("input, textarea, button").length, 4, "form.querySelectorAll('input, textarea, button') should find 4")

// Case sensitivity
// Per CSS Selectors spec, type selectors are case-INSENSITIVE in HTML documents
assert.strictEqual(body.querySelector("HEADER"), header, "HEADER should find header (case-insensitive)")
assert.strictEqual(body.querySelector("header"), header, "header should find header")
assert.strictEqual(body.querySelector("[ID='main-header']"), header, "[ID='main-header'] should find header (attr name case-insensitive)")
assert.strictEqual(body.querySelector("[id='main-header']"), header, "[id='main-header'] should find header")
assert.strictEqual(body.querySelector("[class='TITLE']"), null, "[class='TITLE'] should be null (attr value case-sensitive)")
assert.strictEqual(body.querySelector("[class='title']"), h1, "[class='title'] should find h1")

// querySelector returns first match in document order
assert.isTrue((() => {
    var first = body.querySelector(".content-section");
    return first.id === "section1";
})(), "querySelector('.content-section') should return first in document order (section1)")

// Selector scoping - querySelector only finds descendants
assert.isTrue((() => {
    var result = header.querySelector("footer");
    return result === null;  // footer is sibling, not descendant
})(), "header.querySelector('footer') should be null (sibling, not descendant)")

// ============================================================================
// PERFORMANCE AND STRESS TESTS
// ============================================================================

// Deeply nested selector
assert.isNotNull(body.querySelector("body > main > section > .nested-container > .inner-content > .special"), "deeply nested selector should find element")

// Long comma-separated selector list
assert.isNotNull(body.querySelector("h1, h2, h3, h4, h5, h6, p, div, span, a, ul, li, input, button, form, header, footer, nav, section, aside, main"), "long selector list should find element")

// Multiple attribute selectors combined
assert.strictEqual(body.querySelector("input[type='email'][class='form-input'][name='email'][required]"), inputEmail, "multiple attribute selectors should find inputEmail")

// Selector with all combinator types
assert.isNotNull(body.querySelector("body main#content > section.content-section[data-priority] .nested-container .inner-content.highlight"), "all combinator types should find element")

// ============================================================================
// REAL-WORLD SCENARIOS
// ============================================================================

// Find all interactive elements
assert.isTrue(body.querySelectorAll("a, button, input, textarea, select").length >= 5, "interactive elements should be >= 5")

// Find all elements with specific data attributes
assert.isTrue(body.querySelectorAll("[data-priority], [data-type]").length >= 2, "data attribute elements should be >= 2")

// Find form elements by type
assert.strictEqual(body.querySelectorAll("input[type='text'], input[type='email'], textarea").length, 3, "form elements by type should find 3")

// Find all headings
assert.strictEqual(body.querySelectorAll("h1, h2, h3, h4, h5, h6").length, 4, "headings should find 4 (1 h1 + 3 h2)")

// Find elements by class prefix pattern
assert.isTrue(body.querySelectorAll("[class^='form']").length >= 4, "class prefix pattern should find >= 4")

// Find nested elements at specific depth
assert.isNotNull(body.querySelector("main > section > div > div > span"), "specific depth selector should find element")

// Find elements with multiple conditions
assert.strictEqual(body.querySelectorAll("form input.form-input[type]:not([type='submit'])").length, 2, ":not() selector should find 2")

// ============================================================================
// DOCUMENT VS ELEMENT SCOPING
// ============================================================================

// querySelector from different scopes gives different results
assert.isNotNull(body.querySelector("section"), "body.querySelector('section') should find element")
assert.strictEqual(header.querySelector("section"), null, "header.querySelector('section') should be null")
assert.isNotNull(main.querySelector("section"), "main.querySelector('section') should find element")

// querySelectorAll scoping
assert.isTrue((() => {
    var bodyInputs = body.querySelectorAll("input");
    var formInputs = form.querySelectorAll("input");
    return bodyInputs.length >= formInputs.length && formInputs.length === 2;
})(), "querySelectorAll scoping should work correctly")

// Finding elements in specific subtree
assert.strictEqual(header.querySelectorAll("a").length, 3, "header.querySelectorAll('a') should find 3 nav links")

// ============================================================================
// SUMMARY VALIDATION
// ============================================================================

// Verify core functionality works
assert.isTrue(
    body.querySelector("#main-header") === header &&
    body.querySelector(".title") === h1 &&
    body.querySelectorAll("section").length === 3 &&
    body.querySelector("section .special[data-type='info']") !== null &&
    form.querySelectorAll(".form-input").length === 3,
    "Core querySelector functionality should work correctly"
)
