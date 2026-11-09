//! The wrapper redesign's P6 for the HTML parser (tmp/redesign/wrapper-
//! redesign-design.md 4.4 "Holders" and section 7's P6 entry; refcount step
//! 9a): a live parser's structures - the stack of open elements, the list of
//! active formatting elements, the head and form element pointers - hold
//! their nodes counted, and the Document traces its active parser's nodes
//! when its tree is walked, as Blink's Document traces its parser and
//! HTMLConstructionSite::Trace visits head_, form_, open_elements_ and
//! active_formatting_elements_ (Chromium 131.0.6778.0, core/html/parser/
//! html_construction_site.cc). No wrapper is made for a held node: the
//! parser's rescue - one wrapper for a detached held tree's root, rooted from
//! the Document's kept-roots array - is gone.
//!
//! Rule 3.2 (c)/(d): a parser-held element no script wrapped, whose tree is
//! otherwise unreachable, keeps its tree's wrappers through a collection
//! mid-parse - with every node edge off (`tree_edges = false`), the
//! tracing alone - and they go once the parser ends.
//!
//! Each test runs a real Browser on a thread of its own.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");

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
    for (0..3) |_| try engine.runInRealm(realm, Collect.steps, agent);
}

fn openBrowser() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    return browser;
}

fn byId(document: *runtime.Instance, id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoSuchElement;
}

fn holds(page: anytype, source: []const u8) !bool {
    const answer = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(answer);
    return std.mem.eql(u8, answer, "true");
}

/// The parser's open element #a, never wrapped, is detached by script with
/// its tree; script wraps #b inside it, marks it and drops it. A collection
/// mid-parse keeps #b's wrapper - reached only through the parser's hold on
/// #a - and makes no wrapper for #a; the parser keeps building into #a; once
/// the parser ends, nothing keeps them.
fn parserHeldTreeKeepsItsWrappers(edges: bool) !void {
    const browser = try openBrowser();
    defer browser.deinit();
    // The Browser started the process, which installed the hooks.
    var hooks = runtime.lifetime.installedHooks();
    hooks.tree_edges = edges;
    const override = runtime.lifetime.overrideHooksForTest(hooks);
    defer override.restore();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><div id=a><p id=b><span id=c>')");
    const document = page.document_instance orelse return error.NoDocument;
    const a = try byId(document, "a");
    const c = try byId(document, "c");
    try testing.expect(!engine.hasWrapper(a));
    // #a leaves the document without script seeing it; #b's wrapper is
    // reachable from nothing but the WeakRef once this job ends.
    try page.runScript(
        \\(() => {
        \\  const b = document.getElementById('b'); b.wr = 'b';
        \\  globalThis.ref = new WeakRef(b);
        \\  document.body.replaceChildren();
        \\})();
    );
    try collect(browser);
    try testing.expect(try holds(page, "String(ref.deref() !== undefined && ref.deref().wr === 'b' && ref.deref().parentNode.parentNode === null)"));
    // The trace names wrappers; it makes none. (With the edges on, #b's
    // wrap made its ancestors' wrappers - node tracing's upward closure,
    // until P7 - so only #c is unwrapped then.)
    if (!edges) try testing.expect(!engine.hasWrapper(a));
    try testing.expect(!engine.hasWrapper(c));
    // The parser keeps building into the detached tree.
    try page.runScript("document.write('still parsed</span></p></div>')");
    try testing.expect(try holds(page, "String(ref.deref().firstChild.textContent === 'still parsed')"));
    try page.runScript("document.close()");
    try testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    // The parser ended: nothing reaches the tree any more.
    try collect(browser);
    try testing.expect(try holds(page, "String(ref.deref() === undefined)"));
}

fn withEdgesOff() !void {
    try parserHeldTreeKeepsItsWrappers(false);
}

fn withEdgesOn() !void {
    try parserHeldTreeKeepsItsWrappers(true);
}

test "wr6 RED: with every node edge off, a parser-held tree script detached keeps its wrappers through a collection mid-parse, wrapping nothing" {
    try onFreshThread(withEdgesOff);
}

test "wr6: production - a parser-held tree script detached keeps its wrappers mid-parse and lets them go when the parser ends" {
    try onFreshThread(withEdgesOn);
}
