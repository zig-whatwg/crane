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
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
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
}

test "the :heading() level counts the heading offset of the element's ancestors" {
    try onFreshThread(headingLevels);
}
