// Shadow DOM Functional Tests
// Tests ShadowRoot creation, properties, and Element.attachShadow
// Each test expression must be on its own line

var doc = new Document();

// =============================================================================
// Element.attachShadow Tests
// =============================================================================

// Test 1: attachShadow exists on Element prototype
typeof Element.prototype.attachShadow === "function"

// Test 2: Can attach shadow to div
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow !== null && shadow !== undefined; })()

// Test 3: attachShadow returns ShadowRoot instance
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow instanceof ShadowRoot; })()

// Test 4: Element.shadowRoot returns the attached shadow root (open mode)
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return div.shadowRoot === shadow; })()

// Test 5: Cannot attach shadow twice to same element
(() => { var div = doc.createElement("div"); div.attachShadow({mode: "open"}); try { div.attachShadow({mode: "open"}); return false; } catch(e) { return true; } })()

// Test 6: attachShadow works on span
(() => { var span = doc.createElement("span"); var shadow = span.attachShadow({mode: "open"}); return shadow instanceof ShadowRoot; })()

// Test 7: attachShadow works on article
(() => { var article = doc.createElement("article"); var shadow = article.attachShadow({mode: "open"}); return shadow instanceof ShadowRoot; })()

// Test 8: attachShadow works on section
(() => { var section = doc.createElement("section"); var shadow = section.attachShadow({mode: "open"}); return shadow instanceof ShadowRoot; })()

// =============================================================================
// ShadowRoot Properties Tests
// =============================================================================

// Test 9: ShadowRoot.mode returns "open" for open shadow
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.mode === "open"; })()

// Test 10: ShadowRoot.delegatesFocus defaults to false
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.delegatesFocus === false; })()

// Test 11: ShadowRoot.slotAssignment defaults to "named"
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.slotAssignment === "named"; })()

// Test 12: ShadowRoot.clonable defaults to false
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.clonable === false; })()

// Test 13: ShadowRoot.serializable defaults to false
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.serializable === false; })()

// =============================================================================
// ShadowRoot Inheritance Tests
// =============================================================================

// Test 14: ShadowRoot inherits from DocumentFragment
ShadowRoot.prototype.__proto__ === DocumentFragment.prototype

// Test 15: ShadowRoot has host property
"host" in ShadowRoot.prototype

// Test 16: ShadowRoot has mode property
"mode" in ShadowRoot.prototype

// Test 17: ShadowRoot has delegatesFocus property
"delegatesFocus" in ShadowRoot.prototype

// Test 18: ShadowRoot has slotAssignment property
"slotAssignment" in ShadowRoot.prototype

// =============================================================================
// ShadowRoot DOM Manipulation Tests
// =============================================================================

// Test 19: Can appendChild to shadow root
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var child = doc.createElement("span"); shadow.appendChild(child); return shadow.childNodes.length === 1; })()

// Test 20: Shadow root querySelector works
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var child = doc.createElement("span"); child.id = "test-span"; shadow.appendChild(child); var found = shadow.querySelector("#test-span"); return found === child; })()

// Test 21: Shadow root querySelectorAll works
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var c1 = doc.createElement("span"); var c2 = doc.createElement("span"); c1.className = "item"; c2.className = "item"; shadow.appendChild(c1); shadow.appendChild(c2); var found = shadow.querySelectorAll(".item"); return found.length === 2; })()

// Test 22: Shadow root firstElementChild works
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var child = doc.createElement("span"); shadow.appendChild(child); return shadow.firstElementChild === child; })()

// Test 23: Shadow root childElementCount works
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var c1 = doc.createElement("div"); var c2 = doc.createElement("div"); shadow.appendChild(c1); shadow.appendChild(c2); return shadow.childElementCount === 2; })()

// =============================================================================
// Closed Shadow Root Tests
// =============================================================================

// Test 24: Can create closed shadow root
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "closed"}); return shadow instanceof ShadowRoot; })()

// Test 25: Closed shadow mode is "closed"
(() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "closed"}); return shadow.mode === "closed"; })()

// Test 26: Element.shadowRoot is null for closed shadow
(() => { var div = doc.createElement("div"); div.attachShadow({mode: "closed"}); return div.shadowRoot === null; })()
