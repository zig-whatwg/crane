//! Lane maj6: small DOM conformance fixes, each pinned by script in a page.
//! - DOM 4.2.10.2: an HTMLCollection is named by an element's `name`
//!   attribute only when the element is in the HTML namespace - namedItem,
//!   `in`, hasOwnProperty and Object.getOwnPropertyNames alike
//!   (dom/nodes/Element-children.html, Element-/Document-getElementsByTagName
//!   .html, dom/collections/HTMLCollection-supported-property-names.html;
//!   Chrome 157, Firefox 160 and Safari 27.2 pass).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");
const runtime = @import("runtime");
const loop_settle = @import("loop_settle.zig");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://maj6.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

fn collectionNames() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\const c = document.createElement('div');
        \\c.innerHTML = '<img id=foo><img name=bar>';
        \\const id = document.createElementNS('', 'img'); id.setAttribute('id', 'baz'); c.append(id);
        \\const named = document.createElementNS('', 'img'); named.setAttribute('name', 'qux'); c.append(named);
        \\const svg = document.createElementNS('http://www.w3.org/2000/svg', 'g'); svg.setAttribute('name', 'quux'); c.append(svg);
        \\document.body.append(c);
        \\globalThis.list = c.children;
        \\0;
    );
    try expectTrue(browser, "JSON.stringify(Object.getOwnPropertyNames(list)) === '[\"0\",\"1\",\"2\",\"3\",\"4\",\"foo\",\"bar\",\"baz\"]'");
    try expectTrue(browser, "!('qux' in list) && !list.hasOwnProperty('qux') && list.qux === undefined && list.namedItem('qux') === null");
    try expectTrue(browser, "!('quux' in list) && list.namedItem('quux') === null");
    // An id names it in any namespace; a name in the HTML namespace.
    try expectTrue(browser, "list.baz === list[2] && list.namedItem('baz') === list[2] && list.bar === list[1]");
    try expectTrue(browser, "document.getElementsByTagName('img').namedItem('qux') === null");
}

test "an HTMLCollection is named by the name attribute of HTML elements only" {
    try onFreshThread(collectionNames);
}

fn transientObservers() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.tree = () => {
        \\  const parent = document.createElement('div'); parent.id = 'parent';
        \\  const child = parent.appendChild(document.createElement('div')); child.id = 'child';
        \\  const grandchild = child.appendChild(document.createElement('div')); grandchild.id = 'grandchild';
        \\  return { parent, child, grandchild };
        \\};
        \\globalThis.summarize = (records) => records.map(r => r.type + ' ' + r.target.id + [...r.addedNodes].map(n => ' +' + n.id).join('') + [...r.removedNodes].map(n => ' -' + n.id).join(''));
        \\globalThis.out = {};
        \\// Added with no record queued: the transient still goes at the next notify.
        \\{ const { parent, child } = tree();
        \\  const mo = new MutationObserver(() => { out.calledA = true; });
        \\  mo.observe(parent, { attributes: true, subtree: true });
        \\  child.remove();
        \\  setTimeout(() => { child.setAttribute('data-x', ''); out.a = mo.takeRecords().length; }, 0); }
        \\// The removal queues the notify microtask before a later promise job.
        \\{ const { parent, child } = tree();
        \\  out.order = [];
        \\  const mo = new MutationObserver(() => out.order.push('observer'));
        \\  mo.observe(parent, { attributes: true, subtree: true });
        \\  child.remove();
        \\  Promise.resolve().then(() => out.order.push('promise'));
        \\  child.setAttribute('data-x', ''); }
        \\// observe() again on the target ends a transient copied from a transient.
        \\{ const { parent, child, grandchild } = tree();
        \\  const mo = new MutationObserver(() => {});
        \\  mo.observe(parent, { childList: true, subtree: true });
        \\  child.remove(); grandchild.remove();
        \\  mo.observe(parent, { childList: true, subtree: true });
        \\  child.append(document.createElement('span')); grandchild.append(document.createElement('span'));
        \\  out.c = summarize(mo.takeRecords()).join(','); }
        \\0;
    );
    _ = try browser.runEventLoopBlocking(50);
    try expectTrue(browser, "out.a === 0 && out.calledA === undefined");
    try expectTrue(browser, "out.order.join(',') === 'observer,promise'");
    try expectTrue(browser, "out.c === 'childList parent -child,childList child -grandchild'");
}

test "transient registered observers: sourced from the original registration, and gone at the next notify" {
    try onFreshThread(transientObservers);
}

fn headingLevels() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\document.body.innerHTML = '<section headingoffset=2><h1 id=a></h1><div headingreset headingoffset=1><h2 id=b></h2></div>' +
        \\  '<article headingoffset=7><h5 id=c></h5></article><div headingoffset=x><h3 id=d></h3></div></section><div id=host headingoffset=3></div>';
        \\const root = document.getElementById('host').attachShadow({ mode: 'open' });
        \\root.innerHTML = '<div headingoffset=1><h1 id=e></h1></div>';
        \\globalThis.$ = (id) => document.getElementById(id) || root.getElementById(id);
        \\globalThis.levelOf = (el) => { for (let n = 1; n <= 9; n++) if (el.matches(':heading(' + n + ')')) return n; return 0; };
        \\0;
    );
    // 2 + 1 for a, the reset ends b's walk at its div: 2 + 1.
    try expectTrue(browser, "levelOf($('a')) === 3 && $('a').matches(':heading') && !$('a').matches(':heading(1)')");
    try expectTrue(browser, "levelOf($('b')) === 3");
    // Capped at 9; an unparsable offset adds nothing.
    try expectTrue(browser, "levelOf($('c')) === 9 && levelOf($('d')) === 5");
    // Up the host chain from a shadow tree: 1 + 1 + 3.
    try expectTrue(browser, "levelOf($('e')) === 5");
    // A change of an ancestor's offset is a new level.
    try expectTrue(browser, "document.querySelector('section').headingOffset = 0; levelOf($('a')) === 1");
    try expectTrue(browser, "$('b').parentElement.headingReset = false; levelOf($('b')) === 3");
    // The headingoffset and headingreset attributes are in no namespace
    // (HTML 4.3.11.1 "has a headingoffset attribute"; Blink's
    // FastHasAttribute(kHeadingoffsetAttr)): a namespaced attribute of that
    // local name is neither, though its qualified name is the same.
    try expectTrue(browser, "const f = document.createElement('div'); f.setAttributeNS('urn:x', 'headingoffset', '4'); f.appendChild(document.createElement('h1')); document.body.appendChild(f); levelOf(f.firstChild) === 1");
    try expectTrue(browser, "const g = document.createElement('div'); g.setAttribute('headingoffset', '2'); const r = g.appendChild(document.createElement('div')); r.setAttributeNS('urn:x', 'headingreset', ''); r.appendChild(document.createElement('h1')); document.body.appendChild(g); levelOf(r.firstChild) === 3");
}

test "the :heading() level counts the heading offset of the element's ancestors" {
    try onFreshThread(headingLevels);
}

// :heading skips the offset walk while its document has never had a
// headingoffset or headingreset attribute (dom.heading_offsets: a sticky bit
// in the Document's rare data, set by every path that gives an element one of
// them - main's design 2026-11-21). Each case is a fresh Browser, so its
// document starts with the bit clear.

/// The Document the page's global `name` names.
fn documentOf(browser: *browser_mod.Browser, name: []const u8) !*runtime.Instance {
    var buf: [64]u8 = undefined;
    const held = try browser.evaluateScript(try std.fmt.bufPrint(&buf, "globalThis.{s}", .{name}));
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn rareDataOf(document: *runtime.Instance) !?*dom.document_rare_data.DocumentRareData {
    const internal = dom.document_internals.getInternal(document) orelse return error.NoDocumentState;
    return internal.rareData();
}

/// The Document's own bit (NodeBase.DocumentBits, dom.heading_offsets).
fn headingOffsetsSeen(document: *runtime.Instance) !bool {
    const base = dom.instance_bridge.getNodeBase(document) orelse return error.NoNodeBase;
    return dom.heading_offsets.seen(base);
}

const level_of =
    \\globalThis.levelOf = (el) => { for (let n = 1; n <= 9; n++) if (el.matches(':heading(' + n + ')')) return n; return 0; };
    \\0;
;

fn headingOffsetsSticky() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, level_of);
    // Two offsets; removing one leaves the other counting (the bit is not
    // cleared by a removal), and a later one elsewhere counts too.
    try run(browser,
        \\document.body.innerHTML = '';
        \\globalThis.a = document.createElement('div'); a.setAttribute('headingoffset', '1');
        \\globalThis.b = a.appendChild(document.createElement('div')); b.setAttribute('headingoffset', '2');
        \\globalThis.h = b.appendChild(document.createElement('h1')); document.body.appendChild(a);
        \\0;
    );
    try expectTrue(browser, "levelOf(h) === 4");
    try run(browser, "globalThis.own = document; 0;");
    try testing.expect(try headingOffsetsSeen(try documentOf(browser, "own")));
    try expectTrue(browser, "a.removeAttribute('headingoffset'); levelOf(h) === 3");
    try expectTrue(browser, "b.removeAttribute('headingoffset'); levelOf(h) === 1");
    try expectTrue(browser, "a.toggleAttribute('headingreset'); b.setAttribute('headingoffset', '1'); levelOf(h) === 2");
}

test "a document's heading offsets stay seen after their attributes are removed" {
    try onFreshThread(headingOffsetsSticky);
}

fn headingOffsetsAdopted() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, level_of);
    // Set in another document, then adopted into this one, which never had
    // one: by appendChild, and by innerHTML (the fragment parser's document,
    // then adoption).
    try run(browser,
        \\const other = document.implementation.createHTMLDocument('');
        \\const d = other.createElement('div'); d.setAttribute('headingoffset', '2');
        \\globalThis.h = d.appendChild(other.createElement('h1'));
        \\document.body.appendChild(d);
        \\0;
    );
    try expectTrue(browser, "h.ownerDocument === document && levelOf(h) === 3");
}

test "a heading offset set in another document counts once its element is adopted" {
    try onFreshThread(headingOffsetsAdopted);
}

fn headingOffsetsInnerHTML() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, level_of);
    try expectTrue(browser, "document.body.innerHTML = '<div headingoffset=3><h2 id=x></h2></div>'; levelOf(document.getElementById('x')) === 5");
}

test "a heading offset that innerHTML parses counts" {
    try onFreshThread(headingOffsetsInnerHTML);
}

fn headingOffsetsParsed() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, level_of);
    // The document's own parser (the token's attributes, set at once).
    try expectTrue(browser, "document.open(); document.write('<div headingoffset=1><h3 id=y></h3></div>'); document.close(); levelOf(document.getElementById('y')) === 4");
}

test "a heading offset the document's own parser sets counts" {
    try onFreshThread(headingOffsetsParsed);
}

fn headingOffsetsCloned() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, level_of);
    // Cloned into this document from another (importNode: the clone's list
    // is the source's, shared).
    try expectTrue(browser,
        \\const other = document.implementation.createHTMLDocument('');
        \\other.body.innerHTML = '<section headingoffset=2><h1></h1></section>';
        \\const copy = document.importNode(other.body.firstChild, true);
        \\document.body.appendChild(copy);
        \\levelOf(copy.firstChild) === 3
    );
}

test "a heading offset cloned in from another document counts" {
    try onFreshThread(headingOffsetsCloned);
}

fn headingOffsetsNeverSeen() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, level_of);
    // Headings matched and other attributes written: the document makes no
    // rare data on this path.
    try run(browser,
        \\document.body.innerHTML = '<section class=s data-x=1><div id=d title=t><h2 id=z></h2></div></section>';
        \\const z = document.getElementById('z'); z.setAttribute('lang', 'en'); z.toggleAttribute('hidden');
        \\for (let i = 0; i < 100; i++) levelOf(z);
        \\globalThis.own = document;
        \\0;
    );
    try expectTrue(browser, "levelOf(document.getElementById('z')) === 2");
    const own = try documentOf(browser, "own");
    if (try rareDataOf(own) != null) return error.RareDataMade;
    try testing.expect(!try headingOffsetsSeen(own));
}

test "a document that never sets headingoffset or headingreset makes no rare data for :heading" {
    try onFreshThread(headingOffsetsNeverSeen);
}

fn modalDialogVisibility() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\document.body.innerHTML = '<div style="visibility: hidden"><dialog id=d>x</dialog></div>';
        \\globalThis.d = document.getElementById('d');
        \\0;
    );
    try expectTrue(browser, "(() => { d.show(); const v = getComputedStyle(d).visibility; d.close(); return v === 'hidden'; })()");
    try expectTrue(browser, "(() => { d.showModal(); const v = getComputedStyle(d).visibility; d.close(); return v === 'visible'; })()");
    try expectTrue(browser, "(() => { d.style.visibility = 'hidden'; d.showModal(); const v = getComputedStyle(d).visibility; d.close(); d.style.removeProperty('visibility'); return v === 'hidden'; })()");
}

test "a modal dialog is visibility: visible from the UA sheet, as in all three browsers" {
    try onFreshThread(modalDialogVisibility);
}

fn svgImportMap() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\const svg = document.body.appendChild(document.createElementNS('http://www.w3.org/2000/svg', 'svg'));
        \\const script = document.createElementNS('http://www.w3.org/2000/svg', 'script');
        \\script.setAttribute('type', 'importmap');
        \\script.textContent = '{ "imports": { "maj6-mapped": "data:text/javascript,export default 42;" } }';
        \\svg.appendChild(script);
        \\globalThis.out = 'pending';
        \\import('maj6-mapped').then((m) => { out = m.default; }, (e) => { out = e.name; });
        \\0;
    );
    // Until the loop is idle, not 50 ms of wall time: the import() is a module
    // fetch in flight, then the tasks that evaluate it (loop_settle.zig).
    try loop_settle.settle(browser);
    try expectTrue(browser, "out === 42");
}

test "an inline SVG script of type importmap registers its import map" {
    try onFreshThread(svgImportMap);
}

fn styleTypeChange() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.style = document.createElement('style');
        \\style.type = 'no/mime';
        \\style.textContent = 'body { color: rgb(0, 128, 0) }';
        \\document.head.append(style);
        \\0;
    );
    try expectTrue(browser, "document.styleSheets.length === 0 && getComputedStyle(document.body).color !== 'rgb(0, 128, 0)'");
    try expectTrue(browser, "style.type = 'text/css'; document.styleSheets.length === 1 && getComputedStyle(document.body).color === 'rgb(0, 128, 0)'");
    try expectTrue(browser, "style.type = 'no/mime'; document.styleSheets.length === 0 && getComputedStyle(document.body).color !== 'rgb(0, 128, 0)'");
}

test "a style element's type change updates its style block" {
    try onFreshThread(styleTypeChange);
}

fn replaceDoctype() !void {
    const browser = try open();
    defer browser.deinit();
    try expectTrue(browser,
        \\(() => {
        \\  const doc = document.implementation.createHTMLDocument('a');
        \\  const doc2 = document.implementation.createHTMLDocument('b');
        \\  const old = doc.doctype, next = doc2.doctype;
        \\  doc.replaceChild(next, old);
        \\  return doc.firstChild === next && old.parentNode === null && doc2.firstChild === doc2.documentElement;
        \\})()
    );
    // A second doctype beside the one replaced still throws.
    try expectTrue(browser,
        \\(() => {
        \\  const doc = document.implementation.createHTMLDocument('a');
        \\  const comment = doc.insertBefore(doc.createComment('c'), doc.doctype);
        \\  try { doc.replaceChild(document.implementation.createDocumentType('x', '', ''), comment); return false; }
        \\  catch (e) { return e.name === 'HierarchyRequestError'; }
        \\})()
    );
}

test "a document's doctype can be replaced with another doctype" {
    try onFreshThread(replaceDoctype);
}
