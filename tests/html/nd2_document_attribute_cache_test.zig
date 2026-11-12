//! The Document's shared attribute blocks (lane nd2 batch 5): the cache that
//! hands a parser one block per distinct attribute set is its DOCUMENT's,
//! not one parser run's - every run of the document shares through it (the
//! page's own parse, document.write, innerHTML and the other fragment
//! parsers, an XML parse) - and it goes 10 s after the run that left it
//! last, by a one-shot timer that is not pending work: Blink's
//! Document::element_data_cache_ (made by Document::SetParsingState, dropped
//! by element_data_cache_clear_timer_, which Document::FinishedParsing starts
//! for 10 s and no access restarts) and WebKit's Document::m_sharedObjectPool
//! (Document::setParsing, m_sharedObjectPoolClearTimer). Unlike theirs, a
//! parse after the cache has gone makes a new one (see
//! dom.attribute_block_cache).
//!
//! Which elements share is not web-observable, so each test reads it from
//! the elements script kept: they hold ONE block, and its holder count is
//! the number of elements plus one while the document's cache lives. The
//! 10 s pass on a Browser with the testing platform's virtual clock, which a
//! page's own setTimeout moves. Every Browser is on std.testing.allocator: a
//! cache, a table or a block left behind fails its test as a leak.
//!
//! tests/html is one executable: each test runs its Browser on a thread of
//! its own.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const browser_mod = @import("browser");
const platform = @import("platform");

const AttributeList = dom.element_data.AttributeList;

const is_testing = std.mem.eql(u8, platform.name, "testing");

const page_url = "http://nd2.test/page.html";
/// The repeated element: every `p` of a test has this attribute set.
const p = "<p class=nd2k title=nd2t></p>";
/// The same element in XML.
const xp = "<p class=\"nd2k\" title=\"nd2t\"/>";

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

/// A Browser whose clock is virtual (the testing platform's): it stands
/// still while the page works and moves to the next timer when the loop is
/// idle.
fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "", .platform = .{ .virtual_clock = true, .random_seed = 1 } });
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript(source);
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn loadPage(browser: *browser_mod.Browser, html: []const u8) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
}

/// Turn the loop until it has nothing left to do.
fn runUntilIdle(browser: *browser_mod.Browser) !void {
    _ = try browser.runEventLoopBlocking(60_000);
    try testing.expect(!browser.event_loop.?.hasPendingWork());
}

/// Let `ms` of the Browser's virtual time pass: a page timer of that delay
/// is what moves the clock.
fn pass(browser: *browser_mod.Browser, comptime ms: []const u8) !void {
    try run(browser, "globalThis.nd2Passed = false; setTimeout(() => { globalThis.nd2Passed = true; }, " ++ ms ++ ");");
    try waitFor(browser, "globalThis.nd2Passed === true");
}

/// Collect, then let the event loop free what the collection released
/// (collected trees are freed in slices from the event loop).
fn settle(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    for (0..3) |_| {
        const realm = browser.getRealm() orelse return error.NoRealm;
        const agent = browser.getAgent() orelse return error.NoAgent;
        try engine.runInRealm(realm, Collect.steps, agent);
        _ = try browser.runEventLoopBlocking(10);
    }
}

/// The platform object `source` evaluates to. Script must keep it alive (a
/// global names it): the instance is borrowed from its wrapper.
fn instanceOf(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

/// The script array `array` has `count` elements, they hold ONE attribute
/// block, and that block has exactly `holders` holders. Returns the block.
fn expectOneBlock(browser: *browser_mod.Browser, array: []const u8, count: usize, holders: u8) !*const AttributeList {
    var buffer: [128]u8 = undefined;
    try testing.expect(try truthy(browser, try std.fmt.bufPrint(&buffer, "{s}.length === {d}", .{ array, count })));
    var block: ?*const AttributeList = null;
    for (0..count) |i| {
        const element = try instanceOf(browser, try std.fmt.bufPrint(&buffer, "{s}[{d}]", .{ array, i }));
        const view = dom.element_data.of(element) orelse return error.NotAnElement;
        const list = view.data.attrs orelse return error.NoAttributes;
        if (block) |first| {
            if (list != first) {
                std.debug.print("{s}[{d}] holds another block than {s}[0]\n", .{ array, i, array });
                return error.TestExpectedOneBlock;
            }
        } else block = list;
    }
    if (block.?.holders != holders) {
        std.debug.print("{s}: the block has {d} holder(s), expected {d}\n", .{ array, block.?.holders, holders });
        return error.TestUnexpectedHolders;
    }
    return block.?;
}

/// How many references the Browser's value table counts on the record of
/// `bytes`: 0 when no attribute entry (and so no block) names it.
fn referencesOn(browser: *browser_mod.Browser, bytes: []const u8) !u32 {
    const page = browser.current_context orelse return error.NoPage;
    const document = page.document_instance orelse return error.NoDocument;
    const table = dom.attribute_values.tableOf(runtime.BrowserScope.ofInstance(document)) orelse return 0;
    const id = table.find(bytes) orelse return 0;
    return table.get(id).references;
}

// ---------------------------------------------------------------------------
// Runs of one document share

fn fragmentRunsShare() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body></body>");
    // Two fragment parses (innerHTML, insertAdjacentHTML), then a third
    // through a range: three parser runs, one document, one block - held by
    // the four elements and the document's cache.
    try run(browser, "const a = document.body.appendChild(document.createElement('div')); a.innerHTML = '" ++ p ++ p ++ "';" ++
        "const b = document.body.appendChild(document.createElement('div')); b.insertAdjacentHTML('beforeend', '" ++ p ++ "');" ++
        "const c = document.createRange().createContextualFragment('" ++ p ++ "');" ++
        "globalThis.kept = [...a.querySelectorAll('p'), ...b.querySelectorAll('p'), ...c.querySelectorAll('p')];");
    _ = try expectOneBlock(browser, "kept", 4, 5);
}

test "document cache: the fragment parses of one document share one block" {
    try onFreshThread(fragmentRunsShare);
}

fn pageParseAndLaterRunsShare() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // The page's own parse, a script's document.write into it, an innerHTML
    // after the load, and a script-created parser (document.open) on a
    // frame's document are runs of two documents: each document has its own
    // cache.
    try loadPage(browser, "<!doctype html><body>" ++ p ++ "<script>document.write('" ++ p ++ "')</script>" ++ p ++ "<iframe id=f></iframe></body>");
    try run(browser, "const host = document.body.appendChild(document.createElement('div')); host.innerHTML = '" ++ p ++ p ++ "';" ++
        "globalThis.kept = [...document.querySelectorAll('p')];" ++
        "const d = document.getElementById('f').contentDocument; d.open(); d.write('<!doctype html><body>" ++ p ++ p ++ "'); d.close();" ++
        "d.body.insertAdjacentHTML('beforeend', '" ++ p ++ "');" ++
        "globalThis.framed = [...d.querySelectorAll('p')];");
    const page = try expectOneBlock(browser, "kept", 5, 6);
    const framed = try expectOneBlock(browser, "framed", 3, 4);
    try testing.expect(page != framed);
}

test "document cache: a page's parse, its document.write and a later innerHTML share; a frame's document has its own" {
    try onFreshThread(pageParseAndLaterRunsShare);
}

fn otherDocumentsAndParsers() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body></body>");
    // DOMParser's HTML document, an XML document, and a fragment parse into
    // each: every document's runs share through that document's cache.
    try run(browser, "globalThis.parsed = new DOMParser().parseFromString('" ++ p ++ p ++ "', 'text/html');" ++
        "parsed.body.insertAdjacentHTML('beforeend', '" ++ p ++ "');" ++
        "globalThis.fromHTML = [...parsed.querySelectorAll('p')];" ++
        "globalThis.xml = new DOMParser().parseFromString('<r>" ++ xp ++ xp ++ "</r>', 'application/xml');" ++
        "xml.documentElement.insertAdjacentHTML('beforeend', '" ++ xp ++ "');" ++
        "globalThis.fromXML = [...xml.querySelectorAll('p')];");
    const html = try expectOneBlock(browser, "fromHTML", 3, 4);
    const xml = try expectOneBlock(browser, "fromXML", 3, 4);
    try testing.expect(html != xml);
}

test "document cache: DOMParser's HTML and XML documents each share with the fragment parses into them" {
    try onFreshThread(otherDocumentsAndParsers);
}

const templates = p ++ "<template id=t>" ++ p ++ p ++ "</template><div id=sh><template shadowrootmode=open>" ++ p ++ p ++ "</template></div>";
/// Script: the five `p` of `templates` under `root` - in the tree, in the
/// template's contents, in the declarative shadow root.
const five =
    \\globalThis.five = (root) => [
    \\  ...root.querySelectorAll('p'),
    \\  ...root.querySelector('#t').content.querySelectorAll('p'),
    \\  ...(root.querySelector('#sh').shadowRoot?.querySelectorAll('p') ?? []),
    \\];
;

fn templateContentsShareWithTheirDocument() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // A template's contents (nodes of the template contents owner document)
    // and a declarative shadow root are made by their page's runs, and share
    // through the page's document's cache - the page's parse, setHTMLUnsafe
    // and innerHTML alike. (innerHTML attaches no declarative shadow root:
    // that template stays an element, with its two `p` in its contents.)
    try loadPage(browser, "<!doctype html><body>" ++ templates ++ "</body>");
    try run(browser, five ++ "globalThis.loaded = five(document);" ++
        "const host = document.body.appendChild(document.createElement('div'));" ++
        "const html = '" ++ templates ++ "';" ++
        "host.setHTMLUnsafe(html);" ++
        "const inner = document.body.appendChild(document.createElement('div'));" ++
        "inner.innerHTML = html;" ++
        "globalThis.all = [...loaded, ...five(host), ...five(inner).slice(0, 3), ...inner.querySelector('#sh template').content.querySelectorAll('p')];");
    _ = try expectOneBlock(browser, "all", 15, 16);
}

test "document cache: template contents and declarative shadow roots share through their page's document" {
    try onFreshThread(templateContentsShareWithTheirDocument);
}

// ---------------------------------------------------------------------------
// The cache's end: 10 s after the run that left it last

fn droppedTenSecondsAfterTheParse() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body>" ++ p ++ p ++ "</body>");
    try run(browser, "globalThis.kept = [...document.querySelectorAll('p')];");
    const first = try expectOneBlock(browser, "kept", 2, 3);
    // 9 s after the parse ended the cache is still there, and an innerHTML
    // shares through it - without giving it more time.
    try pass(browser, "9000");
    try run(browser, "const host = document.body.appendChild(document.createElement('div')); host.innerHTML = '" ++ p ++ "'; kept.push(host.firstChild);");
    try testing.expect(try expectOneBlock(browser, "kept", 3, 4) == first);
    // 10 s after: gone. The block is its three elements' alone.
    try pass(browser, "1001");
    try testing.expect(try expectOneBlock(browser, "kept", 3, 3) == first);
    try testing.expectEqual(@as(u32, 1), try referencesOn(browser, "nd2t"));
    // The next parse makes a new cache: its elements share with each other,
    // not with the earlier ones.
    try run(browser, "const later = document.body.appendChild(document.createElement('div')); later.innerHTML = '" ++ p ++ p ++ "'; globalThis.next = [...later.querySelectorAll('p')];");
    const second = try expectOneBlock(browser, "next", 2, 3);
    try testing.expect(second != first);
    // And that one goes 10 s after the run that made it.
    try pass(browser, "10001");
    try testing.expect(try expectOneBlock(browser, "next", 2, 2) == second);
    try testing.expect(try expectOneBlock(browser, "kept", 3, 3) == first);
}

test "document cache: gone 10 s after the parse, no access restarts the wait, and the next parse makes a new one" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onFreshThread(droppedTenSecondsAfterTheParse);
}

fn timerIsNotPendingWork() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body>" ++ p ++ p ++ "</body>");
    try run(browser, "globalThis.kept = [...document.querySelectorAll('p')]; globalThis.before = performance.now();");
    _ = try expectOneBlock(browser, "kept", 2, 3);
    // The loop goes idle with the cache's timer armed: an armed drop is not
    // pending work, and an idle loop does not move its virtual clock to it.
    try runUntilIdle(browser);
    try testing.expect(try truthy(browser, "performance.now() - before < 1000"));
    _ = try expectOneBlock(browser, "kept", 2, 3);
    // It fires when the loop's own work takes the clock past it.
    try pass(browser, "10001");
    _ = try expectOneBlock(browser, "kept", 2, 2);
    try runUntilIdle(browser);
}

test "document cache: its timer keeps no event loop busy and moves no virtual clock" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onFreshThread(timerIsNotPendingWork);
}

fn runningParserKeepsItsCache() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body>" ++ p ++ "</body>");
    // A script-created parser starts 1 s into the 10 s the page's parse left
    // the cache, and is still running when they are over.
    try pass(browser, "1000");
    try run(browser, "globalThis.old = document.querySelector('p'); document.open(); document.write('<!doctype html><body>" ++ p ++ p ++ "<div>'); globalThis.kept = [old, ...document.querySelectorAll('p')];");
    const block = try expectOneBlock(browser, "kept", 3, 4);
    try pass(browser, "9500");
    // The running parser still shares through it...
    try run(browser, "document.write('" ++ p ++ "'); kept.push(document.querySelectorAll('p')[2]);");
    try testing.expect(try expectOneBlock(browser, "kept", 4, 5) == block);
    // ...and it goes when that run ends: its time was over.
    try run(browser, "document.close();");
    try testing.expect(try expectOneBlock(browser, "kept", 4, 4) == block);
}

test "document cache: a parser still running when the 10 s are over keeps sharing; the cache goes when it ends" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onFreshThread(runningParserKeepsItsCache);
}

// ---------------------------------------------------------------------------
// The document's end

fn documentTeardownEndsItsCache() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body><iframe id=f></iframe></body>");
    // The frame's document parses two elements the parent keeps; its cache
    // is alive (timer armed) when the frame is removed and the document
    // collected.
    try run(browser, "{ const d = document.getElementById('f').contentDocument; d.open(); d.write('<!doctype html><body>" ++ p ++ p ++ "'); d.close();" ++
        "globalThis.kept = [...d.querySelectorAll('p')].map((el) => document.adoptNode(el)); }");
    const block = try expectOneBlock(browser, "kept", 2, 3);
    try run(browser, "document.getElementById('f').remove();");
    try settle(browser);
    // The document went, and its cache with it: the adopted elements hold
    // the block alone.
    try testing.expect(try expectOneBlock(browser, "kept", 2, 2) == block);
    // Its timer was cancelled: 10 s later nothing fires into the freed
    // document (a Browser on std.testing.allocator: a use after free here
    // reads poisoned memory).
    try pass(browser, "10001");
    try testing.expect(try expectOneBlock(browser, "kept", 2, 2) == block);
}

test "document cache: a document's teardown ends its cache and cancels its timer" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onFreshThread(documentTeardownEndsItsCache);
}

fn browserEndsWithCachesAlive() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // Caches alive - timers armed - on the page's document, a frame's, a
    // DOMParser document and an XML one when the Browser ends: its end
    // frees them all (std.testing.allocator).
    try loadPage(browser, "<!doctype html><body>" ++ p ++ p ++ "<iframe srcdoc='" ++ p ++ p ++ "'></iframe></body>");
    try run(browser, "globalThis.parsed = new DOMParser().parseFromString('" ++ p ++ p ++ "', 'text/html');" ++
        "globalThis.xml = new DOMParser().parseFromString('<r>" ++ xp ++ xp ++ "</r>', 'application/xml');" ++
        "globalThis.kept = [...document.querySelectorAll('p')];");
    _ = try expectOneBlock(browser, "kept", 2, 3);
}

test "document cache: a Browser that ends with caches alive frees them" {
    try onFreshThread(browserEndsWithCachesAlive);
}
