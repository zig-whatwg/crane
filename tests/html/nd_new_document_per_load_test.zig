//! Every load of a page makes a new Document (HTML "create and initialize a
//! Document object" step 9). The document it replaces is aborted and left to
//! whatever still holds it: its nodes are never freed under script, and no
//! load replaces it under one of its parsers - one asked for there waits for
//! that parser to return. A load replacing any document but the initial
//! about:blank one gives the page a new Window (step 7; lane newwin1), so
//! these tests keep what outlives a load - the old page's objects - through
//! engine handles, never through the old Window's globals.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const engine = @import("engine");
const runtime = @import("runtime");

/// Run `body` on a thread of its own: each test starts its own Browser, and a
/// test directory is one process (AGENTS.md "A test directory is one
/// executable").
fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn startBrowser() !*browser_mod.Browser {
    // No snapshot: the startup path JavaScriptCore runs on.
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

/// `expression`'s value in the page's current realm, held across loads.
fn hold(page: *browser_mod.Context, expression: []const u8) !engine.Owned {
    return page.evaluateScript(expression);
}

/// `globalThis[name] = held` in the page's current realm - the held value
/// of an earlier page, which script of this one reaches from here.
fn expose(page: *browser_mod.Context, name: []const u8, held: engine.Owned) !void {
    const realm = page.realm orelse return error.NoRealm;
    const global = try engine.getProperty(realm, .{ .instance = page.window_instance.? }, "window");
    defer global.release();
    try engine.setProperty(realm, global.value, name, held.value);
}

// ---------------------------------------------------------------------------
// A load asked for from inside the previous page's parser
// ---------------------------------------------------------------------------

const second_page =
    \\<!doctype html><body><p id=second>two</p>
    \\<script>globalThis.secondDoc = document; globalThis.secondSaw = document.getElementById('second').textContent;</script>
    \\</body>
;

/// The first page's loader: its one external script asks for the second
/// page to be loaded into the same Context, while the first page's parser is
/// preparing that script - on the native stack, holding the script element
/// and its ancestors. Then, still under that parser, it collects garbage and
/// runs the event loop.
const Reloader = struct {
    browser: *browser_mod.Browser,
    page: *browser_mod.Context,
    reloaded: bool = false,
    first_document: ?*runtime.Instance = null,
    first_window: ?*runtime.Instance = null,
    /// The first page's document, held across the loads.
    first_hold: ?engine.Owned = null,
    replaced_under_parser: bool = false,
    destroyed_under_parser: bool = false,
    failure: ?anyerror = null,

    fn load(context: ?*anyopaque, url: []const u8) ?[]const u8 {
        const self: *Reloader = @ptrCast(@alignCast(context.?));
        // The loader is given the src as written.
        if (!std.mem.endsWith(u8, url, "reload.js")) return null;
        // What a loader returns is the caller's to free (FetchedSource).
        if (self.reloaded) return testing.allocator.dupe(u8, "") catch null;
        self.reloaded = true;
        self.reenter() catch |err| {
            self.failure = err;
        };
        return testing.allocator.dupe(u8, "globalThis.firstParserRanReload = true;") catch null;
    }

    fn reenter(self: *Reloader) !void {
        const first = self.page.document_instance orelse return error.NoFirstDocument;
        self.first_document = first;
        self.first_window = self.page.window_instance;
        self.first_hold = try engine.retainValue(self.page.realm.?, .{ .instance = first });
        try self.page.loadHTML(second_page, .{ .base_url = "http://example.test/second" });
        // The first page's parser is still below us: the load waits for it.
        self.replaced_under_parser = self.page.document_instance != first;
        try self.page.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try self.browser.runEventLoopBlocking(20);
        try self.page.runScript("TestUtils.gc();");
        self.destroyed_under_parser = dom.document_internals.getInternal(first).?.destroyed;
    }

    fn retain(_: ?*anyopaque) void {}
    fn release(_: ?*anyopaque) void {}

    fn descriptor(self: *Reloader) browser_mod.Context.ScriptLoader {
        return .{ .context = self, .loadScript = &load, .retain = &retain, .release = &release };
    }
};

const ScriptHolds = enum { first_page, nothing };

const first_page_held =
    \\<!doctype html><body><div id=first>one</div>
    \\<script>globalThis.firstDoc = document; globalThis.firstDiv = document.getElementById('first');
    \\for (const type of ['pagehide', 'unload']) addEventListener(type, () => { window.name += type + ';'; });</script>
    \\<script src="reload.js"></script>
    \\<div id=after>after</div>
    \\<script>globalThis.firstPageWentOn = true;</script>
    \\</body>
;

/// Nothing in script names this page: only its parser's active call keeps
/// it while that parser runs, with open elements around the script.
const first_page_unheld =
    \\<!doctype html><body><div id=first><span>one</span>
    \\<p><b><i><script src="reload.js"></script></i></b></p>
    \\<div id=after>after</div>
    \\<script>globalThis.firstPageWentOn = true;</script>
    \\</div></body>
;

fn reentrantLoad(holds: ScriptHolds) !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;

    var reloader: Reloader = .{ .browser = browser, .page = page };
    defer if (reloader.first_hold) |held| held.release();
    const first_page = switch (holds) {
        .first_page => first_page_held,
        .nothing => first_page_unheld,
    };
    try page.loadHTML(first_page, .{ .base_url = "http://example.test/first", .script_loader = reloader.descriptor() });
    if (reloader.failure) |err| return err;
    try testing.expect(reloader.reloaded);
    const first = reloader.first_document orelse return error.TestUnexpectedResult;
    const second = page.document_instance orelse return error.TestUnexpectedResult;
    // Nothing was replaced, or destroyed, under the first page's parser: the
    // load ran once that parse returned, and made a Document of its own - in
    // a new Window, the first page being no initial about:blank document.
    try testing.expect(!reloader.replaced_under_parser);
    try testing.expect(!reloader.destroyed_under_parser);
    try testing.expect(second != first);
    try testing.expect(page.window_instance.? != reloader.first_window.?);
    // The first page never finished loading: destroyed, like Chrome and
    // Safari, with no unload events.
    try testing.expect(dom.document_internals.getInternal(first).?.destroyed);

    try expose(page, "heldFirstDoc", reloader.first_hold.?);
    try page.runScript(
        \\if (secondSaw !== 'two') throw new Error('second page scripts saw ' + secondSaw);
        \\if (document !== secondDoc) throw new Error('document is not the second page');
        \\if (window.document !== document) throw new Error('window.document is another document');
        \\if (document.getElementById('second')?.textContent !== 'two') throw new Error('second page missing');
        \\if (document.getElementById('first') !== null) throw new Error('first page content in the second document');
        \\if (document.getElementById('after') !== null) throw new Error('first parser wrote into the second document');
        \\if (typeof firstPageWentOn !== 'undefined') throw new Error('the first page\'s globals reached the second page\'s Window');
        \\if (window.name !== '') throw new Error('a page that never loaded got ' + window.name);
        \\// The first page's parser ran to its end, in its own document.
        \\if (heldFirstDoc.getElementById('after')?.textContent !== 'after') throw new Error('the first parse stopped early');
        \\if (heldFirstDoc.defaultView !== null) throw new Error('the replaced document keeps its window');
    );
    switch (holds) {
        .first_page => try page.runScript(
            \\TestUtils.gc();
            \\TestUtils.gc();
            \\const firstDiv = heldFirstDoc.getElementById('first');
            \\if (firstDiv.textContent !== 'one' || firstDiv.parentNode.nodeName !== 'BODY') throw new Error('held page lost its nodes');
        ),
        .nothing => {},
    }
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\TestUtils.gc();
        \\if (document.readyState !== 'complete') throw new Error('second page did not finish: ' + document.readyState);
    );
    // std.testing.allocator: nothing of either page leaks.
}

fn reentrantLoadHeld() !void {
    try reentrantLoad(.first_page);
}

fn reentrantLoadUnheld() !void {
    try reentrantLoad(.nothing);
}

test "a load asked for under the previous page's parser waits for it, then makes a new Document in a new Window" {
    try onFreshThread(reentrantLoadHeld);
}

test "a load asked for under the previous page's parser, with nothing in script holding that page, survives collection under the parser" {
    try onFreshThread(reentrantLoadUnheld);
}

// ---------------------------------------------------------------------------
// Loads in sequence
// ---------------------------------------------------------------------------

fn sequentialLoads() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    const initial = page.document_instance orelse return error.TestUnexpectedResult;
    const initial_window = page.window_instance orelse return error.TestUnexpectedResult;

    // The realm's first document is its navigable's initial about:blank one
    // (HTML "create a new browsing context and document" steps 15 and 22).
    try page.runScript(
        \\globalThis.initialDoc = document;
        \\if (document.compatMode !== 'BackCompat') throw new Error('initial about:blank is not in quirks mode');
        \\if (document.readyState !== 'complete') throw new Error('initial about:blank readiness ' + document.readyState);
        \\if (!document.body || !document.head || document.documentElement.nodeName !== 'HTML')
        \\  throw new Error('initial about:blank is not populated with html/head/body');
        \\if (document.contentType !== 'text/html') throw new Error('initial about:blank content type ' + document.contentType);
    );

    try page.loadHTML(
        \\<!doctype html><body><div id=one>first</div>
        \\<script>globalThis.firstDoc = document; globalThis.held = document.getElementById('one');
        \\globalThis.firstSawWindowDoc = window.document === document && document.defaultView === window;</script>
        \\</body>
    , .{ .base_url = "http://example.test/first" });
    const first = page.document_instance orelse return error.TestUnexpectedResult;
    // The first load replaces the initial about:blank document, and keeps
    // its Window (step 6).
    try testing.expect(first != initial);
    try testing.expectEqual(initial_window, page.window_instance.?);
    try page.runScript(
        \\if (!firstSawWindowDoc) throw new Error('the first page script saw another document');
        \\if (document === initialDoc) throw new Error('the first load kept the initial document');
        \\if (initialDoc.defaultView !== null) throw new Error('initial about:blank keeps its window');
        \\if (document.compatMode !== 'CSS1Compat') throw new Error('the loaded page is in ' + document.compatMode);
    );
    const held_first = try hold(page, "firstDoc");
    defer held_first.release();
    const held_node = try hold(page, "held");
    defer held_node.release();

    try page.loadHTML(
        \\<!doctype html><body><p id=two>second</p>
        \\<script>globalThis.secondDoc = document;</script>
        \\</body>
    , .{ .base_url = "http://example.test/second" });
    const second = page.document_instance orelse return error.TestUnexpectedResult;
    try testing.expect(second != first);
    // Step 7: the first page was no initial about:blank document.
    try testing.expect(page.window_instance.? != initial_window);
    // It had not loaded (no task ran since its load): destroyed, silently,
    // by the load - no parser of it was on the stack.
    try testing.expect(dom.document_internals.getInternal(first).?.destroyed);
    try testing.expect(dom.document_internals.getInternal(initial).?.destroyed);
    try testing.expect(!dom.document_internals.getInternal(second).?.destroyed);
    try expose(page, "firstDoc", held_first);
    try expose(page, "held", held_node);
    try page.runScript(
        \\if (secondDoc !== document) throw new Error('second page script saw another document');
        \\if (document === firstDoc) throw new Error('the second load reused the first Document');
        \\if (window.document !== document || document.defaultView !== window) throw new Error('window and document disagree');
        \\if (firstDoc.defaultView !== null) throw new Error('the replaced document keeps its window');
        \\if (document.getElementById('one') !== null) throw new Error('first page content in the second document');
        \\if (held.ownerDocument !== firstDoc) throw new Error('held node changed documents');
        \\if (document.URL !== 'http://example.test/second') throw new Error('document URL ' + document.URL);
        \\globalThis.firstDoc = null;
    );
    // Leave the job, then collect: only `held` keeps the first page now.
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (held.textContent !== 'first') throw new Error('held node lost its text');
        \\const doc = held.ownerDocument;
        \\if (doc.getElementById('one') !== held) throw new Error('held node left its document');
        \\if (held.parentNode.nodeName !== 'BODY') throw new Error('held node left its tree');
        \\held.appendChild(doc.createElement('span'));
        \\if (held.childNodes.length !== 2) throw new Error('held node cannot be mutated');
        \\if (doc.defaultView !== null) throw new Error('the replaced document regained a window');
    );
}

test "every load makes a new Document, and a node of a replaced one stays usable after collection" {
    try onFreshThread(sequentialLoads);
}

fn unloadOrder() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    const initial = page.document_instance orelse return error.TestUnexpectedResult;
    // The initial about:blank document's Window is the first page's too
    // (step 6), so its listeners hear both documents unload. What they log
    // goes in window.name - the browsing context's target name, which every
    // Window of the page reports - so the next Window's script reads it.
    try page.runScript(
        \\for (const type of ['pagehide', 'unload']) addEventListener(type, () => { window.name += type + '@' + document.URL + ','; });
        \\document.addEventListener('visibilitychange', () => { window.name += 'initial:' + document.visibilityState + ','; });
    );
    try page.loadHTML(
        \\<!doctype html><body><script>window.name += 'first-script,';
        \\document.addEventListener('visibilitychange', () => { window.name += 'first:' + document.visibilityState + ','; });</script></body>
    , .{ .base_url = "http://example.test/first" });
    // The initial about:blank had loaded: it was unloaded, and destroyed,
    // before the first page's script ran.
    try testing.expect(dom.document_internals.getInternal(initial).?.destroyed);
    const first = page.document_instance orelse return error.TestUnexpectedResult;
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\if (document.readyState !== 'complete') throw new Error('first page readiness ' + document.readyState);
    );
    const held_first = try hold(page, "document");
    defer held_first.release();
    try page.loadHTML("<!doctype html><body><script>window.name += 'second-script';</script></body>", .{ .base_url = "http://example.test/second" });
    // The first page had loaded: unloaded and destroyed inside the load, in
    // its own Window, before the second page's script ran in a new one.
    try testing.expect(dom.document_internals.getInternal(first).?.destroyed);
    try expose(page, "firstDoc", held_first);
    try page.runScript(
        \\const expected = 'pagehide@about:blank,initial:hidden,unload@about:blank,first-script,' +
        \\  'pagehide@http://example.test/first,first:hidden,unload@http://example.test/first,second-script';
        \\if (window.name !== expected) throw new Error('events: ' + window.name);
        \\if (firstDoc.visibilityState !== 'hidden' || document.visibilityState !== 'visible') throw new Error('visibility');
    );
}

test "a page that has loaded is unloaded - pagehide, visibilitychange, unload - before the next page's scripts" {
    try onFreshThread(unloadOrder);
}

fn openedDocumentIsUnloaded() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body>first</body>", .{ .base_url = "http://example.test/first" });
    _ = try browser.runEventLoopBlocking(20);
    // Loaded, then opened: a script-created parser holds its stream until
    // close(), and readiness is "loading" again. document.open erased the
    // window's listeners (document open steps 10); these come after it.
    try page.runScript(
        \\document.open();
        \\document.write('<p id=written>written</p>');
        \\for (const type of ['pagehide', 'unload']) addEventListener(type, () => { window.name += type + ','; });
        \\if (document.readyState !== 'loading') throw new Error('opened readiness ' + document.readyState);
    );
    const opened = page.document_instance orelse return error.TestUnexpectedResult;
    const held_opened = try hold(page, "document");
    defer held_opened.release();
    try page.loadHTML("<!doctype html><body><script>window.name += 'second-script'</script></body>", .{ .base_url = "http://example.test/second" });
    // Its parser waits for document.close() - it is on no stack - so the
    // load unloads it as any page whose load event has run (document.open
    // leaves it completely loaded): pagehide and unload, then destroy. The
    // stated deviation that left it to a task went with the load deferred
    // past the page's own parses.
    try testing.expect(dom.document_internals.getInternal(opened).?.destroyed);
    try expose(page, "openedDoc", held_opened);
    try page.runScript(
        \\if (window.name !== 'pagehide,unload,second-script') throw new Error('events: ' + window.name);
        \\if (openedDoc.getElementById('written')?.textContent !== 'written') throw new Error('written content lost');
    );
}

test "a loaded page reopened by document.open is unloaded and destroyed by the load that replaces it" {
    try onFreshThread(openedDocumentIsUnloaded);
}

fn replacedDocumentIsCollectable() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML(
        \\<!doctype html><body><div id=one>first</div></body>
    , .{ .base_url = "http://example.test/first" });
    const first = page.document_instance orelse return error.TestUnexpectedResult;
    const generation = runtime.SlabAllocator.generationOf(first);
    try page.loadHTML("<!doctype html><body><p>second</p></body>", .{ .base_url = "http://example.test/second" });
    // Nothing holds the first page - neither its document nor its Window's
    // realm: the collector takes them, and the realm's end frees the
    // document (its slot reissued or dead).
    for (0..3) |_| {
        _ = try browser.runEventLoopBlocking(20);
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
    }
    _ = try browser.runEventLoopBlocking(20);
    try testing.expect(runtime.SlabAllocator.generationOf(first) != generation);
}

test "a replaced Document nothing holds is the collector's" {
    try onFreshThread(replacedDocumentIsCollectable);
}

// ---------------------------------------------------------------------------
// A load while the previous page's parser waits
// ---------------------------------------------------------------------------

fn loadWhileParserWaits() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    // A stylesheet nobody answers blocks the script after it: the parser
    // returns waiting, owned by its document.
    try page.loadHTML(
        \\<!doctype html><head>
        \\<link rel=stylesheet href="http://127.0.0.1:65533/pending.css">
        \\<script>window.name = 'the first page went on';</script>
        \\</head><body><div id=late>late</div></body>
    , .{ .base_url = "http://127.0.0.1:65533/first" });
    const first = page.document_instance orelse return error.TestUnexpectedResult;
    if (dom.document_internals.getInternal(first).?.active_parser == null) return error.ParserDidNotWait;
    const held_first = try hold(page, "document");
    defer held_first.release();
    try page.loadHTML("<!doctype html><body><p id=two>second</p></body>", .{ .base_url = "http://127.0.0.1:65533/second" });
    if (page.document_instance == first) return error.SecondLoadReusedTheDocument;
    // The waiting parser went with its document's abort.
    if (dom.document_internals.getInternal(first).?.active_parser != null) return error.WaitingParserKept;
    // The stylesheet's failure arrives later, for a document that is gone.
    _ = try browser.runEventLoopBlocking(50);
    try expose(page, "firstDoc", held_first);
    try page.runScript(
        \\if (window.name !== '') throw new Error('the replaced page went on parsing');
        \\if (firstDoc.getElementById('late') !== null) throw new Error('the replaced page parsed after its abort');
        \\if (document.getElementById('late') !== null) throw new Error('the old parser wrote into the new document');
        \\if (document.getElementById('two')?.textContent !== 'second') throw new Error('second page missing');
    );
}

test "a load while the previous page's parser waits on a stylesheet discards that parser" {
    try onFreshThread(loadWhileParserWaits);
}
