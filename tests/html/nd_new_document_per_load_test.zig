//! Every load of a page makes a new Document (HTML "create and initialize a
//! Document object" step 9). The document it replaces is aborted and left to
//! whatever still holds it: its nodes are never freed under script, or under
//! a parser still on the native stack.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
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

// ---------------------------------------------------------------------------
// A load started from inside the previous page's parser
// ---------------------------------------------------------------------------

const second_page =
    \\<!doctype html><body><p id=second>two</p>
    \\<script>globalThis.secondDoc = document; globalThis.secondSaw = document.getElementById('second').textContent;</script>
    \\</body>
;

/// The first page's loader: its one external script loads the second page
/// into the same Context, while the first page's parser is preparing that
/// script - on the native stack, holding the script element and its
/// ancestors. Then, still under that parser, it collects garbage and runs
/// the event loop, where the replaced document's deferred destroy must wait.
const Reloader = struct {
    browser: *browser_mod.Browser,
    page: *browser_mod.Context,
    reloaded: bool = false,
    first_document: ?*runtime.Instance = null,
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
        try self.page.loadHTML(second_page, .{ .base_url = "http://example.test/second" });
        // The first page's parser is still below us: its active call keeps
        // its document and nodes, whatever script holds.
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
    \\globalThis.firstPageEvents = [];
    \\for (const type of ['pagehide', 'unload']) addEventListener(type, () => firstPageEvents.push(type));</script>
    \\<script src="reload.js"></script>
    \\<div id=after>after</div>
    \\<script>globalThis.firstPageWentOn = true;</script>
    \\</body>
;

/// Nothing in script names this page: only its parser's active call keeps
/// it while that parser unwinds, with open elements around the script.
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
    const first_page = switch (holds) {
        .first_page => first_page_held,
        .nothing => first_page_unheld,
    };
    try page.loadHTML(first_page, .{ .base_url = "http://example.test/first", .script_loader = reloader.descriptor() });
    if (reloader.failure) |err| return err;
    try testing.expect(reloader.reloaded);
    const first = reloader.first_document orelse return error.TestUnexpectedResult;
    const second = page.document_instance orelse return error.TestUnexpectedResult;
    // The second load made a Document of its own.
    try testing.expect(second != first);
    // "Destroy a document" waited for the parser that was on the stack.
    try testing.expect(!reloader.destroyed_under_parser);

    try page.runScript(
        \\if (secondSaw !== 'two') throw new Error('second page scripts saw ' + secondSaw);
        \\if (document !== secondDoc) throw new Error('document is not the second page');
        \\if (window.document !== document) throw new Error('window.document is another document');
        \\if (document.getElementById('second')?.textContent !== 'two') throw new Error('second page missing');
        \\if (document.getElementById('first') !== null) throw new Error('first page content in the second document');
        \\if (document.getElementById('after') !== null) throw new Error('first parser wrote into the second document');
        \\if (globalThis.firstPageWentOn) throw new Error('the aborted parser ran a later script');
    );
    switch (holds) {
        .first_page => {
            try page.runScript(
                \\if (document === firstDoc) throw new Error('the second load reused the first Document');
                \\if (firstDoc.getElementById('after') !== null) throw new Error('the aborted parser went on parsing');
                \\if (firstDoc.defaultView !== null) throw new Error('the replaced document keeps its window');
                \\if (firstDiv.ownerDocument !== firstDoc || firstDiv.textContent !== 'one') throw new Error('first page node lost');
                \\// It never finished loading: like Chrome and Safari, no unload events.
                \\if (firstPageEvents.length) throw new Error('a page that never loaded got ' + firstPageEvents);
            );
            // The parser has unwound: the deferred destroy runs now. Script
            // still holds the first page, so `first` is live to ask.
            _ = try browser.runEventLoopBlocking(20);
            try testing.expect(dom.document_internals.getInternal(first).?.destroyed);
            try page.runScript(
                \\TestUtils.gc();
                \\TestUtils.gc();
                \\if (firstDiv.textContent !== 'one') throw new Error('held node lost its text');
                \\if (firstDiv.parentNode.nodeName !== 'BODY') throw new Error('held node left its tree');
                \\if (firstDoc.getElementById('first') !== firstDiv) throw new Error('held node not in its document');
                \\if (document.readyState !== 'complete') throw new Error('second page did not finish: ' + document.readyState);
            );
        },
        .nothing => {
            // `first` may be the collector's from here: never dereferenced.
            _ = try browser.runEventLoopBlocking(20);
            try page.runScript(
                \\TestUtils.gc();
                \\if (document.readyState !== 'complete') throw new Error('second page did not finish: ' + document.readyState);
            );
        },
    }
    // std.testing.allocator: nothing of either page leaks.
}

fn reentrantLoadHeld() !void {
    try reentrantLoad(.first_page);
}

fn reentrantLoadUnheld() !void {
    try reentrantLoad(.nothing);
}

test "a load started while the previous page's parser is on the stack makes a new Document and the old parser touches only live nodes" {
    try onFreshThread(reentrantLoadHeld);
}

test "a load started under the previous page's parser, with nothing in script holding that page, survives collection under the parser" {
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
    // The first load replaces the initial about:blank document.
    try testing.expect(first != initial);
    try page.runScript(
        \\if (!firstSawWindowDoc) throw new Error('the first page script saw another document');
        \\if (document === initialDoc) throw new Error('the first load kept the initial document');
        \\if (initialDoc.defaultView !== null) throw new Error('initial about:blank keeps its window');
        \\if (document.compatMode !== 'CSS1Compat') throw new Error('the loaded page is in ' + document.compatMode);
    );

    try page.loadHTML(
        \\<!doctype html><body><p id=two>second</p>
        \\<script>globalThis.secondDoc = document;</script>
        \\</body>
    , .{ .base_url = "http://example.test/second" });
    const second = page.document_instance orelse return error.TestUnexpectedResult;
    try testing.expect(second != first);
    // "Destroy a document" is a task: the load only aborted and unlinked the
    // document it replaced. Script holds both replaced documents here.
    try testing.expect(!dom.document_internals.getInternal(first).?.destroyed);
    try page.runScript(
        \\if (secondDoc !== document) throw new Error('second page script saw another document');
        \\if (document === firstDoc) throw new Error('the second load reused the first Document');
        \\if (window.document !== document || document.defaultView !== window) throw new Error('window and document disagree');
        \\if (firstDoc.defaultView !== null) throw new Error('the replaced document keeps its window');
        \\if (document.getElementById('one') !== null) throw new Error('first page content in the second document');
        \\if (held.ownerDocument !== firstDoc) throw new Error('held node changed documents');
        \\if (document.URL !== 'http://example.test/second') throw new Error('document URL ' + document.URL);
    );
    _ = try browser.runEventLoopBlocking(20);
    try testing.expect(dom.document_internals.getInternal(initial).?.destroyed);
    try testing.expect(dom.document_internals.getInternal(first).?.destroyed);
    try testing.expect(!dom.document_internals.getInternal(second).?.destroyed);
    try page.runScript(
        \\globalThis.firstDoc = null;
        \\globalThis.initialDoc = null;
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
    // The Window is the same for every load here, so its listeners hear
    // every document it unloads.
    try page.runScript(
        \\globalThis.log = [];
        \\globalThis.initialDoc = document;
        \\for (const type of ['pagehide', 'unload']) addEventListener(type, () => log.push(type + '@' + document.URL));
        \\document.addEventListener('visibilitychange', () => log.push('initial:' + document.visibilityState));
    );
    try page.loadHTML(
        \\<!doctype html><body><script>log.push('first-script');
        \\document.addEventListener('visibilitychange', () => log.push('first:' + document.visibilityState));</script></body>
    , .{ .base_url = "http://example.test/first" });
    // The initial about:blank had loaded: it was unloaded, and destroyed,
    // before the first page's script ran.
    try testing.expect(dom.document_internals.getInternal(initial).?.destroyed);
    const first = page.document_instance orelse return error.TestUnexpectedResult;
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\if (document.readyState !== 'complete') throw new Error('first page readiness ' + document.readyState);
        \\globalThis.firstDoc = document;
    );
    try page.loadHTML("<!doctype html><body><script>log.push('second-script')</script></body>", .{ .base_url = "http://example.test/second" });
    // The first page had loaded: unloaded and destroyed inside the load.
    try testing.expect(dom.document_internals.getInternal(first).?.destroyed);
    try page.runScript(
        \\const expected = ['pagehide@about:blank', 'initial:hidden', 'unload@about:blank', 'first-script',
        \\  'pagehide@http://example.test/first', 'first:hidden', 'unload@http://example.test/first', 'second-script'];
        \\if (log.join() !== expected.join()) throw new Error('events: ' + log.join());
        \\if (firstDoc.visibilityState !== 'hidden' || document.visibilityState !== 'visible') throw new Error('visibility');
    );
}

test "a page that has loaded is unloaded - pagehide, visibilitychange, unload - before the next page's scripts" {
    try onFreshThread(unloadOrder);
}

fn openedDocumentIsNotUnloaded() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body>first</body>", .{ .base_url = "http://example.test/first" });
    _ = try browser.runEventLoopBlocking(20);
    // Loaded, then opened: a script-created parser holds its stream until
    // close(), and readiness is "loading" again.
    try page.runScript(
        \\globalThis.log = [];
        \\for (const type of ['pagehide', 'unload']) addEventListener(type, () => log.push(type));
        \\globalThis.openedDoc = document;
        \\document.open();
        \\document.write('<p id=written>written</p>');
        \\if (document.readyState !== 'loading') throw new Error('opened readiness ' + document.readyState);
    );
    const opened = page.document_instance orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body><script>log.push('second-script')</script></body>", .{ .base_url = "http://example.test/second" });
    try testing.expect(!dom.document_internals.getInternal(opened).?.destroyed);
    _ = try browser.runEventLoopBlocking(20);
    try testing.expect(dom.document_internals.getInternal(opened).?.destroyed);
    try page.runScript(
        \\if (log.join() !== 'second-script') throw new Error('events: ' + log.join());
        \\if (openedDoc.getElementById('written')?.textContent !== 'written') throw new Error('written content lost');
    );
}

test "a loaded page reopened by document.open is not unloaded under its parser, and is destroyed by a task" {
    try onFreshThread(openedDocumentIsNotUnloaded);
}

fn replacedDocumentIsCollectable() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML(
        \\<!doctype html><body><div id=one>first</div>
        \\<script>globalThis.weakFirst = new WeakRef(document);
        \\globalThis.weakNode = new WeakRef(document.getElementById('one'));</script>
        \\</body>
    , .{ .base_url = "http://example.test/first" });
    try page.loadHTML("<!doctype html><body><p>second</p></body>", .{ .base_url = "http://example.test/second" });
    // Leave the jobs that made the WeakRefs before collecting.
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (weakFirst.deref() !== undefined) throw new Error('nothing holds the replaced document, yet it was kept');
        \\if (weakNode.deref() !== undefined) throw new Error('nothing holds the replaced page, yet its node was kept');
    );
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
        \\<script>globalThis.firstPageScript = true;</script>
        \\</head><body><div id=late>late</div></body>
    , .{ .base_url = "http://127.0.0.1:65533/first" });
    const first = page.document_instance orelse return error.TestUnexpectedResult;
    if (dom.document_internals.getInternal(first).?.active_parser == null) return error.ParserDidNotWait;
    try page.runScript("globalThis.firstDoc = document;");
    try page.loadHTML("<!doctype html><body><p id=two>second</p></body>", .{ .base_url = "http://127.0.0.1:65533/second" });
    if (page.document_instance == first) return error.SecondLoadReusedTheDocument;
    // The waiting parser went with its document's abort.
    if (dom.document_internals.getInternal(first).?.active_parser != null) return error.WaitingParserKept;
    // The stylesheet's failure arrives later, for a document that is gone.
    _ = try browser.runEventLoopBlocking(50);
    try page.runScript(
        \\if (globalThis.firstPageScript) throw new Error('the replaced page went on parsing');
        \\if (firstDoc.getElementById('late') !== null) throw new Error('the replaced page parsed after its abort');
        \\if (document.getElementById('late') !== null) throw new Error('the old parser wrote into the new document');
        \\if (document.getElementById('two')?.textContent !== 'second') throw new Error('second page missing');
    );
}

test "a load while the previous page's parser waits on a stylesheet discards that parser" {
    try onFreshThread(loadWhileParserWaits);
}
