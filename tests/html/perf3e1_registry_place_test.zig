//! An element's custom element registry read from where E1 keeps it (lane
//! perf3, E1 item 1): its node document's global registry is read from the
//! document, any other registry from the element's rare data. These hold
//! before and after E1: the association's storage moved, not its value.
//! Each scenario follows the spec text and its cross-document paths: two
//! browsing contexts' documents (each with its Window's registry), a
//! document initialized with a scoped registry (HTML initialize step 2),
//! and an element made with a scoped registry that has a definition.
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

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
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

fn twoBrowsingContexts() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.f = document.body.appendChild(document.createElement('iframe'));
        \\globalThis.d = f.contentDocument;
        \\globalThis.inner = f.contentWindow.customElements;
        \\globalThis.el = document.createElement('div');
        \\el.innerHTML = '<span></span>';
        \\0
    );
    try expectTrue(browser, "d.customElementRegistry === inner && inner !== customElements");
    try expectTrue(browser, "d.createElement('p').customElementRegistry === inner");
    // Adopt 3.3.2.4: each global association follows the new document's.
    try expectTrue(browser, "d.adoptNode(el) === el && el.customElementRegistry === inner && el.firstChild.customElementRegistry === inner");
    try expectTrue(browser, "document.adoptNode(el) === el && el.customElementRegistry === customElements && el.firstChild.customElementRegistry === customElements");
    try collect(browser);
    try expectTrue(browser, "el.customElementRegistry === customElements && d.customElementRegistry === inner");
    // An element moved into the iframe's document upgrades through that
    // document's registry when it connects (insert 7.7.3 try to upgrade:
    // look up a definition with the element's registry).
    try run(browser,
        \\f.contentWindow.eval("customElements.define('x-up', class extends HTMLElement {})");
        \\globalThis.x = document.createElement('x-up');
        \\d.body.appendChild(x);
        \\0
    );
    try expectTrue(browser, "x.customElementRegistry === inner && x.matches(':defined') && x.constructor === inner.get('x-up')");
    // The top document's registry knows no x-up: one made there stays undefined.
    try expectTrue(browser, "!document.body.appendChild(document.createElement('x-up')).matches(':defined')");
}

test "adopting between two browsing contexts' documents follows each document's global registry" {
    try onFreshThread(twoBrowsingContexts);
}

fn scopedDocument() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.s = new CustomElementRegistry();
        \\globalThis.doc = document.implementation.createHTMLDocument('');
        \\s.initialize(doc);
        \\globalThis.made = doc.createElement('div');
        \\globalThis.g = document.createElement('div');
        \\0
    );
    // HTML initialize step 2 gave the document the scoped registry; its
    // elements take it ("look up a custom element registry" of the document).
    try expectTrue(browser, "doc.customElementRegistry === s && made.customElementRegistry === s");
    // Adopt 3.3.2.2-3.3.2.4: a global association becomes the document's
    // effective global registry - null for a scoped one.
    try expectTrue(browser, "doc.adoptNode(g) === g && g.customElementRegistry === null");
    // Adopted out, a scoped association stays.
    try expectTrue(browser, "document.adoptNode(made) === made && made.customElementRegistry === s");
    try collect(browser);
    try expectTrue(browser, "made.customElementRegistry === s && g.customElementRegistry === null");
}

test "a document initialized with a scoped registry: its elements keep it, an adopted global element reads null" {
    try onFreshThread(scopedDocument);
}

fn scopedDefinition() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.s2 = new CustomElementRegistry();
        \\s2.define('x-s', class extends HTMLElement {});
        \\globalThis.xs = document.createElement('x-s', { customElementRegistry: s2 });
        \\globalThis.plain = document.createElement('x-s');
        \\0
    );
    try expectTrue(browser, "xs.customElementRegistry === s2 && xs.constructor === s2.get('x-s')");
    try expectTrue(browser, "plain.customElementRegistry === customElements && plain.constructor === HTMLElement");
    try expectTrue(browser, "(document.body.append(xs, plain), xs.matches(':defined') && !plain.matches(':defined'))");
    // A deep clone keeps the scoped registry and constructs through it.
    try expectTrue(browser, "(globalThis.c = xs.cloneNode(true), c.customElementRegistry === s2 && c.constructor === s2.get('x-s'))");
    try collect(browser);
    try expectTrue(browser, "xs.customElementRegistry === s2 && c.customElementRegistry === s2");
}

test "an element made with a scoped registry constructs, clones and stays with it" {
    try onFreshThread(scopedDefinition);
}
