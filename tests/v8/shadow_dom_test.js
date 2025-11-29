// Shadow DOM Functional Tests
// Tests ShadowRoot creation, properties, and Element.attachShadow
// Each test expression must be on its own line

var doc = new Document();

// =============================================================================
// Element.attachShadow Tests
// =============================================================================

// Test 1: attachShadow exists on Element prototype
assert.isFunction(Element.prototype.attachShadow, "attachShadow should exist on Element prototype")

// Test 2: Can attach shadow to div
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow !== null && shadow !== undefined; })(), "attachShadow should return a non-null value")

// Test 3: attachShadow returns ShadowRoot instance
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow instanceof ShadowRoot; })(), "attachShadow should return ShadowRoot instance")

// Test 4: Element.shadowRoot returns the attached shadow root (open mode)
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return div.shadowRoot === shadow; })(), "Element.shadowRoot should return attached shadow root (open mode)")

// Test 5: Cannot attach shadow twice to same element
assert.isTrue((() => { var div = doc.createElement("div"); div.attachShadow({mode: "open"}); try { div.attachShadow({mode: "open"}); return false; } catch(e) { return true; } })(), "attachShadow twice should throw")

// Test 6: attachShadow works on span
assert.isTrue((() => { var span = doc.createElement("span"); var shadow = span.attachShadow({mode: "open"}); return shadow instanceof ShadowRoot; })(), "attachShadow should work on span")

// Test 7: attachShadow works on article
assert.isTrue((() => { var article = doc.createElement("article"); var shadow = article.attachShadow({mode: "open"}); return shadow instanceof ShadowRoot; })(), "attachShadow should work on article")

// Test 8: attachShadow works on section
assert.isTrue((() => { var section = doc.createElement("section"); var shadow = section.attachShadow({mode: "open"}); return shadow instanceof ShadowRoot; })(), "attachShadow should work on section")

// =============================================================================
// ShadowRoot Properties Tests
// =============================================================================

// Test 9: ShadowRoot.mode returns "open" for open shadow
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.mode === "open"; })(), "ShadowRoot.mode should be 'open'")

// Test 10: ShadowRoot.delegatesFocus defaults to false
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.delegatesFocus === false; })(), "ShadowRoot.delegatesFocus should default to false")

// Test 11: ShadowRoot.slotAssignment defaults to "named"
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.slotAssignment === "named"; })(), "ShadowRoot.slotAssignment should default to 'named'")

// Test 12: ShadowRoot.clonable defaults to false
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.clonable === false; })(), "ShadowRoot.clonable should default to false")

// Test 13: ShadowRoot.serializable defaults to false
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); return shadow.serializable === false; })(), "ShadowRoot.serializable should default to false")

// =============================================================================
// ShadowRoot Inheritance Tests
// =============================================================================

// Test 14: ShadowRoot inherits from DocumentFragment
assert.strictEqual(ShadowRoot.prototype.__proto__, DocumentFragment.prototype, "ShadowRoot should inherit from DocumentFragment")

// Test 15: ShadowRoot has host property
assert.isTrue("host" in ShadowRoot.prototype, "ShadowRoot.prototype should have host property")

// Test 16: ShadowRoot has mode property
assert.isTrue("mode" in ShadowRoot.prototype, "ShadowRoot.prototype should have mode property")

// Test 17: ShadowRoot has delegatesFocus property
assert.isTrue("delegatesFocus" in ShadowRoot.prototype, "ShadowRoot.prototype should have delegatesFocus property")

// Test 18: ShadowRoot has slotAssignment property
assert.isTrue("slotAssignment" in ShadowRoot.prototype, "ShadowRoot.prototype should have slotAssignment property")

// =============================================================================
// ShadowRoot DOM Manipulation Tests
// =============================================================================

// Test 19: Can appendChild to shadow root
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var child = doc.createElement("span"); shadow.appendChild(child); return shadow.childNodes.length === 1; })(), "appendChild to shadow root should work")

// Test 20: Shadow root querySelector works
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var child = doc.createElement("span"); child.id = "test-span"; shadow.appendChild(child); var found = shadow.querySelector("#test-span"); return found === child; })(), "Shadow root querySelector should work")

// Test 21: Shadow root querySelectorAll works
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var c1 = doc.createElement("span"); var c2 = doc.createElement("span"); c1.className = "item"; c2.className = "item"; shadow.appendChild(c1); shadow.appendChild(c2); var found = shadow.querySelectorAll(".item"); return found.length === 2; })(), "Shadow root querySelectorAll should work")

// Test 22: Shadow root firstElementChild works
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var child = doc.createElement("span"); shadow.appendChild(child); return shadow.firstElementChild === child; })(), "Shadow root firstElementChild should work")

// Test 23: Shadow root childElementCount works
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "open"}); var c1 = doc.createElement("div"); var c2 = doc.createElement("div"); shadow.appendChild(c1); shadow.appendChild(c2); return shadow.childElementCount === 2; })(), "Shadow root childElementCount should work")

// =============================================================================
// Closed Shadow Root Tests
// =============================================================================

// Test 24: Can create closed shadow root
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "closed"}); return shadow instanceof ShadowRoot; })(), "Closed shadow root should be creatable")

// Test 25: Closed shadow mode is "closed"
assert.isTrue((() => { var div = doc.createElement("div"); var shadow = div.attachShadow({mode: "closed"}); return shadow.mode === "closed"; })(), "Closed shadow mode should be 'closed'")

// Test 26: Element.shadowRoot is null for closed shadow
assert.isTrue((() => { var div = doc.createElement("div"); div.attachShadow({mode: "closed"}); return div.shadowRoot === null; })(), "Element.shadowRoot should be null for closed shadow")
