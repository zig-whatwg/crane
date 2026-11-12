//! Lane quick1 batch 1 (C07): the members MathMLElement, SVGElement and
//! HTMLElement take from the ElementCSSInlineStyle and
//! HTMLOrSVGOrMathMLElement interface mixins, implemented ONCE in each
//! mixin's impl (src/webidl/AGENTS.md "Names are the binding map"), and the
//! MathML `a` element's hyperlink (MathML Core 3.6).
//!
//! RED at 9a7434fdee9: MathMLElement's style, dataset and nonce answer
//! error.NotImplemented (script sees undefined), SVGElement's dataset and
//! tabIndex too, and MathMLAnchorElement's href; a MathML a has no
//! activation behaviour and never matches :any-link.
//!
//! The leak tests are the integrator's condition 1 for the move (05:55 UTC
//! 2026-11-12): the nonce bytes of every includer are freed by Element's
//! rare-data destroy, at the element's deinit and at its Browser's teardown
//! sweep, and SVGElement's own swept nonce store is gone.
//!
//! These name only generated interfaces and src/dom (AGENTS.md "The impls
//! boundary").
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

const html_ns = "http://www.w3.org/1999/xhtml";
const svg_ns = "http://www.w3.org/2000/svg";
const mathml_ns = "http://www.w3.org/1998/Math/MathML";

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

fn expectEval(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const result = try page.evaluate(source);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected, result);
}

// ============================================================================
// ElementCSSInlineStyle: style and attributeStyleMap on every includer
// ============================================================================

fn inlineStyleOnEveryIncluder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectEval(page,
        \\(() => {
        \\  const out = [];
        \\  for (const [ns, name] of [['http://www.w3.org/1999/xhtml', 'div'], ['http://www.w3.org/2000/svg', 'rect'], ['http://www.w3.org/1998/Math/MathML', 'mi'], ['http://www.w3.org/1998/Math/MathML', 'a']]) {
        \\    const e = document.createElementNS(ns, name);
        \\    document.body.append(e);
        \\    e.style.color = 'red';
        \\    out.push([e.style === e.style, e.getAttribute('style'), e.attributeStyleMap === e.attributeStyleMap, e.attributeStyleMap.size].join(' '));
        \\  }
        \\  return out.join('|');
        \\})()
    , "true color: red; true 1|true color: red; true 1|true color: red; true 1|true color: red; true 1");
}

fn inlineStyleSetterForwards() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // [PutForwards=cssText] on the mixin's attribute, for a MathML element.
    try expectEval(page,
        \\(() => {
        \\  const m = document.createElementNS('http://www.w3.org/1998/Math/MathML', 'mrow');
        \\  m.style = 'background-color: green';
        \\  const d = Object.getOwnPropertyDescriptor(MathMLElement.prototype, 'style');
        \\  return [m.getAttribute('style'), m.style.backgroundColor, typeof d.get, typeof d.set].join(',');
        \\})()
    , "background-color: green;,green,function,function");
}

// ============================================================================
// HTMLOrSVGOrMathMLElement: dataset, nonce, autofocus, tabIndex, focus, blur
// ============================================================================

fn datasetOnEveryIncluder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectEval(page,
        \\(() => {
        \\  const out = [];
        \\  for (const [ns, name] of [['http://www.w3.org/1999/xhtml', 'p'], ['http://www.w3.org/2000/svg', 'g'], ['http://www.w3.org/1998/Math/MathML', 'math']]) {
        \\    const e = document.createElementNS(ns, name);
        \\    e.dataset.fooBar = 'x';
        \\    e.setAttribute('data-other', 'y');
        \\    out.push([e.dataset === e.dataset, e.getAttribute('data-foo-bar'), e.dataset.other].join(' '));
        \\  }
        \\  return out.join('|');
        \\})()
    , "true x y|true x y|true x y");
}

fn nonceOnEveryIncluder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // HTML 2.5.6: the IDL attribute is the element's [[CryptographicNonce]]
    // slot, which the content attribute sets and cloning copies.
    try expectEval(page,
        \\(() => {
        \\  const out = [];
        \\  for (const [ns, name] of [['http://www.w3.org/1999/xhtml', 'div'], ['http://www.w3.org/2000/svg', 'rect'], ['http://www.w3.org/1998/Math/MathML', 'mi']]) {
        \\    const e = document.createElementNS(ns, name);
        \\    const empty = e.nonce;
        \\    e.setAttribute('nonce', 'abc');
        \\    const fromAttribute = e.nonce;
        \\    e.nonce = 'def';
        \\    const copy = e.cloneNode();
        \\    e.removeAttribute('nonce');
        \\    out.push([JSON.stringify(empty), fromAttribute, copy.nonce, copy.getAttribute('nonce'), JSON.stringify(e.nonce)].join(' '));
        \\  }
        \\  return out.join('|');
        \\})()
    , "\"\" abc def abc \"\"|\"\" abc def abc \"\"|\"\" abc def abc \"\"");
}

fn tabIndexAndAutofocusOnEveryIncluder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectEval(page,
        \\(() => {
        \\  const out = [];
        \\  for (const [ns, name] of [['http://www.w3.org/1999/xhtml', 'a'], ['http://www.w3.org/1999/xhtml', 'span'], ['http://www.w3.org/2000/svg', 'a'], ['http://www.w3.org/2000/svg', 'rect'], ['http://www.w3.org/1998/Math/MathML', 'a'], ['http://www.w3.org/1998/Math/MathML', 'mi']]) {
        \\    const e = document.createElementNS(ns, name);
        \\    const initial = e.tabIndex;
        \\    e.tabIndex = 3;
        \\    const autofocus = e.autofocus;
        \\    e.autofocus = true;
        \\    out.push([initial, e.getAttribute('tabindex'), e.tabIndex, autofocus, e.hasAttribute('autofocus')].join(' '));
        \\  }
        \\  return out.join('|');
        \\})()
    , "0 3 3 false true|-1 3 3 false true|0 3 3 false true|-1 3 3 false true|0 3 3 false true|-1 3 3 false true");
}

fn focusAndBlurOnEveryIncluder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectEval(page,
        \\(() => {
        \\  document.body.innerHTML = '<div id=h tabindex=0></div><svg><rect id=s tabindex=0></rect></svg><math><mi id=m tabindex=0>x</mi></math>';
        \\  const out = [];
        \\  for (const id of ['h', 's', 'm']) {
        \\    const e = document.getElementById(id);
        \\    e.focus();
        \\    const focused = document.activeElement === e;
        \\    e.blur();
        \\    out.push(focused + ' ' + (document.activeElement === document.body));
        \\  }
        \\  return out.join('|');
        \\})()
    , "true true|true true|true true");
}

fn oneImplPerMember() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // WebIDL includes: every includer has the mixin's members on its own
    // prototype, under its own brand check.
    try expectEval(page,
        \\(() => {
        \\  const out = [];
        \\  for (const I of [HTMLElement, SVGElement, MathMLElement]) {
        \\    const names = ['style', 'attributeStyleMap', 'dataset', 'nonce', 'autofocus', 'tabIndex', 'focus', 'blur'];
        \\    out.push(names.every(n => Object.getOwnPropertyDescriptor(I.prototype, n) !== undefined));
        \\  }
        \\  let threw = false;
        \\  try { Object.getOwnPropertyDescriptor(MathMLElement.prototype, 'dataset').get.call(document.createElement('div')); } catch (e) { threw = e instanceof TypeError; }
        \\  out.push(threw);
        \\  return out.join(',');
        \\})()
    , "true,true,true,true");
}

// ============================================================================
// MathMLAnchorElement (MathML Core 3.6)
// ============================================================================

fn mathmlAnchorHref() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // The href getter steps: no url and no attribute -> ""; no url (the
    // value does not parse) -> the attribute's value; else the url,
    // serialized. The setter reflects ([ReflectSetter]); the
    // HyperlinkElementUtils members read and write the same url.
    try expectEval(page,
        \\(() => {
        \\  const a = document.createElementNS('http://www.w3.org/1998/Math/MathML', 'a');
        \\  const out = [JSON.stringify(a.href)];
        \\  a.setAttribute('href', 'http://EXAMPLE.test:80/p?q#h');
        \\  out.push(a.href);
        \\  a.setAttribute('href', 'http://[bad');
        \\  out.push(a.href);
        \\  a.href = 'https://a.test/x';
        \\  out.push(a.getAttribute('href'));
        \\  a.hash = 'frag';
        \\  out.push(a.href, a.getAttribute('href'));
        \\  a.target = '_blank';
        \\  out.push(a.getAttribute('target'));
        \\  return out.join(' ');
        \\})()
    , "\"\" http://example.test/p?q#h http://[bad https://a.test/x https://a.test/x#frag https://a.test/x#frag _blank");
}

fn mathmlAnchorLinkPseudoClasses() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // :any-link and :link: an a element with an href (HTML's a and area;
    // a MathML a, as Firefox and Safari match it - anchor-visited-privacy).
    // Never :visited (no history). Only `a` links in MathML: an mi with an
    // href does not (MathML Core 3.6).
    try expectEval(page,
        \\(() => {
        \\  document.body.innerHTML = '<math><a id=l href="#x">l</a><a id=n>n</a><mi id=i href="#x">i</mi></math>';
        \\  const [l, n, i] = ['l', 'n', 'i'].map(id => document.getElementById(id));
        \\  return [l.matches(':any-link'), l.matches(':link'), l.matches(':visited'), n.matches(':any-link'), i.matches(':any-link'), document.querySelectorAll(':any-link').length].join(',');
        \\})()
    , "true,true,false,false,false,1");
}

fn mathmlAnchorFollowsItsHyperlink() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // An HTML a first, the same way: the page's javascript: navigation is
    // what both reach (HTML 4.6.4 "follow the hyperlink").
    try page.run(
        \\window.hits = [];
        \\document.body.innerHTML = '<a id=h href="javascript:hits.push(0)">h</a><math><a id=m href="javascript:hits.push(1)"><mi>x</mi></a><a id=n><mi>y</mi></a><mi id=i href="javascript:hits.push(2)">z</mi></math>';
        \\document.getElementById('h').dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
    );
    try page.turn();
    try page.turn();
    // A click on the a's child: the a is the activation target.
    try page.run(
        \\document.getElementById('m').firstChild.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
    );
    try page.turn();
    try page.turn();
    try page.run(
        \\document.getElementById('n').dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
        \\document.getElementById('i').dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
        \\const cancelled = new MouseEvent('click', {bubbles: true, cancelable: true});
        \\document.getElementById('m').addEventListener('click', e => e.preventDefault(), {once: true});
        \\document.getElementById('m').dispatchEvent(cancelled);
    );
    try page.turn();
    try page.turn();
    // The a with an href followed it once; the a without one, the mi with
    // one and the cancelled click did nothing.
    try expectEval(page, "hits.join(',')", "0,1");
}

// ============================================================================
// Ownership: nothing is left behind (the integrator's condition 1)
// ============================================================================

/// An engine-less page over `allocator` (tests/dom/cg1_element_same_object_test.zig's).
const NativePage = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,

    fn open(self: *NativePage, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
    }

    fn close(self: *NativePage) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

fn setEverything(comptime I: type, element: *runtime.Instance) ![2]*runtime.Instance {
    try interfaces.Element.call_setAttribute(element, str("nonce"), .{ .domstring = str("from the attribute") });
    try I.set_nonce(element, str("set by script"));
    try interfaces.Element.call_setAttribute(element, str("style"), .{ .domstring = str("color: red") });
    _ = try I.get_style(element);
    try interfaces.Element.call_setAttribute(element, str("data-x"), .{ .domstring = str("1") });
    // The generated caches' objects (dataset, attributeStyleMap) are their
    // wrappers' to free; no engine wraps them here.
    return .{ try I.get_dataset(element), try I.get_attributeStyleMap(element) };
}

test "HTML, SVG and MathML elements with nonce, style and dataset set leave nothing at their deinit" {
    var page: NativePage = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const cases = .{
        .{ html_ns, "div", interfaces.HTMLElement },
        .{ svg_ns, "rect", interfaces.SVGElement },
        .{ mathml_ns, "mi", interfaces.MathMLElement },
        .{ mathml_ns, "a", interfaces.MathMLElement },
    };
    inline for (cases) |case| {
        const element = try interfaces.Document.call_createElementNS(page.document, str(case[0]), str(case[1]), .notPassed());
        const made = try setEverything(case[2], element);
        var nonce = try case[2].get_nonce(element);
        defer nonce.deinit(testing.allocator);
        try testing.expectEqualStrings("set by script", nonce.asSlice());
        for (made) |object| runtime.Instance.deinit(object);
        // An SVG or MathML element's style object is the generated cache's,
        // its wrapper's to free: no engine wraps it here. HTMLElement's goes
        // with the element.
        if (comptime case[2] != interfaces.HTMLElement) runtime.Instance.deinit(try case[2].get_style(element));
        dom.node_creation.destroyUninserted(element);
    }
}

fn sweptAtTeardown() !void {
    const browser = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=host><div nonce=n style='color: red' data-x=1></div><svg><rect nonce=n style='color: red' data-x=1></rect></svg><math><mi nonce=n style='color: red' data-x=1>x</mi><a nonce=n href='#' style='color: red' data-x=1>a</a></math></div>", .{ .base_url = "about:blank" });
    // Each element's slot, style object, dataset and attributeStyleMap made
    // and then orphaned unwrapped-or-wrapped: the Browser's teardown sweep
    // frees what no deinit reached.
    const result = try browser.evaluateScript(
        \\for (const e of document.querySelectorAll('[nonce]')) { e.nonce = 'changed by script'; e.style.color = 'green'; e.dataset.y = '2'; e.attributeStyleMap.size; }
        \\document.getElementById('host').innerHTML = '';
        \\true
    );
    result.release();
}

test "HTML, SVG and MathML elements with nonce, style and dataset set are swept at Browser teardown" {
    try helpers.onFreshThread(sweptAtTeardown);
}

test "style and attributeStyleMap: one implementation for HTML, SVG and MathML elements" {
    try helpers.onFreshThread(inlineStyleOnEveryIncluder);
}

test "MathML style forwards a write to cssText" {
    try helpers.onFreshThread(inlineStyleSetterForwards);
}

test "dataset: one implementation for HTML, SVG and MathML elements" {
    try helpers.onFreshThread(datasetOnEveryIncluder);
}

test "nonce: one slot implementation for HTML, SVG and MathML elements" {
    try helpers.onFreshThread(nonceOnEveryIncluder);
}

test "tabIndex and autofocus: one implementation for HTML, SVG and MathML elements" {
    try helpers.onFreshThread(tabIndexAndAutofocusOnEveryIncluder);
}

test "focus and blur: one implementation for HTML, SVG and MathML elements" {
    try helpers.onFreshThread(focusAndBlurOnEveryIncluder);
}

test "every includer has the mixins' members on its own prototype, under its own brand check" {
    try helpers.onFreshThread(oneImplPerMember);
}

test "MathMLAnchorElement's href getter, setter and URL members" {
    try helpers.onFreshThread(mathmlAnchorHref);
}

test "a MathML a with an href matches :any-link and :link, never :visited" {
    try helpers.onFreshThread(mathmlAnchorLinkPseudoClasses);
}

test "a MathML a with an href follows its hyperlink when clicked" {
    try helpers.onFreshThread(mathmlAnchorFollowsItsHyperlink);
}
