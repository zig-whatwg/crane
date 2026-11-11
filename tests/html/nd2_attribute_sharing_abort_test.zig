//! Attribute-block sharing: the paths a parser run ENDS by (lane nd2 batch 4,
//! plan-v2 A3). A parser run's cache (dom.element_data.SharingCache) holds
//! every block it handed out, one holder each, and must let go on every path
//! the run ends by - finished, replaced by document.open(), aborted by
//! window.stop(), navigated away from, or failed - so that a block lives
//! exactly as long as an element holds it. Blink keeps its cache on the
//! Document (core/dom/element_data_cache.cc) and WebKit its
//! DocumentSharedObjectPool; here it is the run's (the integrator's ruling of
//! 2026-11-11), owned by the scripted parser's tree adapter
//! (parser_script_execution.zig), by dom_parser.zig's parseHTML and
//! parseFragmentWith, and by the XML builder (xml_document_parser.zig).
//!
//! Which elements share is not web-observable, so each test reads it from
//! the elements script kept: they hold ONE block, and that block's holder
//! count is the number of elements - one more only while their parser still
//! runs. Where a failed run leaves no element, the Browser's value table
//! says whether anything still counts the run's values. Every Browser here
//! is on std.testing.allocator: a cache table or block left behind fails the
//! test as a leak.
//!
//! tests/html is one executable: each test runs its Browser on a thread of
//! its own.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const browser_mod = @import("browser");

const AttributeList = dom.element_data.AttributeList;

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

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
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
        if (block) |first| try testing.expect(list == first) else block = list;
    }
    try testing.expectEqual(holders, block.?.holders);
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

/// No block of the Browser names the tests' two values any more.
fn expectNoBlockLeft(browser: *browser_mod.Browser) !void {
    try testing.expectEqual(@as(u32, 0), try referencesOn(browser, "nd2k"));
    try testing.expectEqual(@as(u32, 0), try referencesOn(browser, "nd2t"));
}

// ---------------------------------------------------------------------------
// document.open() during a parse

fn documentOpenMidParse() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body></body>");
    // A script-created parser, mid-run: its two elements and its cache hold
    // the block.
    try run(browser, "document.open(); document.write('<!doctype html><body>" ++ p ++ p ++ "<div>'); globalThis.kept = [...document.querySelectorAll('p')];");
    const block = try expectOneBlock(browser, "kept", 2, 3);
    // HTML "document open steps" replace that parser: its run ends here, and
    // its cache lets go. The elements script kept still hold the block.
    try run(browser, "document.open();");
    try testing.expect(try expectOneBlock(browser, "kept", 2, 2) == block);
    // The next run's cache is its own, and gone when that run finishes.
    try run(browser, "document.write('<!doctype html><body>" ++ p ++ "'); document.close(); globalThis.next = [...document.querySelectorAll('p')];");
    try testing.expect(try expectOneBlock(browser, "next", 1, 1) != block);
    _ = try expectOneBlock(browser, "kept", 2, 2);
}

test "A3 abort: document.open() replaces a parser mid-run - its cache lets go, the kept elements' block stays theirs" {
    try onFreshThread(documentOpenMidParse);
}

// ---------------------------------------------------------------------------
// A parser stopped by a script

fn documentWriteInAParserScript() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // The written element is made by the same run (the script's write
    // re-enters the page's parser): one block, and no cache holder after
    // the load.
    try loadPage(browser, "<!doctype html><body>" ++ p ++ "<script>document.write('" ++ p ++ "')</script>" ++ p ++ "</body>");
    try run(browser, "globalThis.kept = [...document.querySelectorAll('p')];");
    _ = try expectOneBlock(browser, "kept", 3, 3);
}

test "A3 abort: document.write in a parser's script shares with the run it re-enters" {
    try onFreshThread(documentWriteInAParserScript);
}

fn windowStopInAParserScript() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // window.stop() -> "stop loading" -> "abort a document": the parser is
    // aborted with its script still on the stack, and the rest of the input
    // is thrown away.
    try loadPage(browser, "<!doctype html><body>" ++ p ++ p ++ "<script>window.stop()</script><p id=after class=nd2k title=nd2t></p></body>");
    try run(browser, "if (document.getElementById('after')) throw new Error('window.stop() did not abort the parser'); globalThis.kept = [...document.querySelectorAll('p')];");
    _ = try expectOneBlock(browser, "kept", 2, 2);
}

test "A3 abort: window.stop() in a parser's script - the aborted run's cache lets go" {
    try onFreshThread(windowStopInAParserScript);
}

fn frameNavigatedAwayMidParse() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body><iframe id=f></iframe></body>");
    // The frame's document has a script-created parser, mid-run; the parent
    // keeps two of its elements.
    try run(browser,
        \\globalThis.old = document.getElementById('f').contentDocument;
        \\old.open();
    ++ "old.write('<!doctype html><body>" ++ p ++ p ++ "<div>');" ++
        \\globalThis.kept = [...old.querySelectorAll('p')];
    );
    const block = try expectOneBlock(browser, "kept", 2, 3);
    // Navigating the frame away destroys that document and aborts its
    // parser: the run's cache lets go.
    try run(browser, "document.getElementById('f').srcdoc = '<p>next';");
    try waitFor(browser, "document.getElementById('f').contentDocument !== old && document.getElementById('f').contentDocument.body?.textContent === 'next'");
    try testing.expect(try expectOneBlock(browser, "kept", 2, 2) == block);
}

test "A3 abort: a frame navigated away from mid-parse - the kept elements' block loses the parser's holder" {
    try onFreshThread(frameNavigatedAwayMidParse);
}

fn topLevelNavigatedAwayMidParse() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body></body>");
    try run(browser, "document.open(); document.write('<!doctype html><body>" ++ p ++ p ++ "<div>');");
    try testing.expectEqual(@as(u32, 1), try referencesOn(browser, "nd2t"));
    // The realm ends with its parser suspended mid-run: nothing keeps the
    // elements, so the run's block goes with its cache.
    try browser.navigate("about:blank", .window);
    try settle(browser);
    try expectNoBlockLeft(browser);
}

test "A3 abort: a top-level navigation away mid-parse frees the run's cache and its blocks" {
    try onFreshThread(topLevelNavigatedAwayMidParse);
}

// ---------------------------------------------------------------------------
// A fragment parse that fails

fn failedXmlParses() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body></body>");
    // innerHTML with an XML context: the XML fragment parser made two
    // elements sharing a block before the well-formedness error
    // ("SyntaxError", HTML 14.4 step 7).
    try run(browser,
        \\globalThis.xml = new DOMParser().parseFromString('<r><a/></r>', 'application/xml');
        \\let name = 'none';
    ++ "try { xml.documentElement.innerHTML = '" ++ xp ++ xp ++ "<oops'; } catch (e) { name = e.name; }" ++
        \\if (name !== 'SyntaxError') throw new Error('XML innerHTML threw ' + name);
        \\if (xml.documentElement.childElementCount !== 1) throw new Error('the failed parse changed the tree');
    );
    try expectNoBlockLeft(browser);
    // DOMParser on malformed XML. Crane follows Chrome and WebKit here
    // (xml_document_parser.zig insertErrorMessageBlock): the document keeps
    // what the run built before the error, beside the error report - so the
    // failed run's two elements live on, holding the block the run's cache
    // has let go of.
    try run(browser, "globalThis.failed = new DOMParser().parseFromString('<r>" ++ xp ++ xp ++ "<oops', 'application/xml');" ++
        \\if (!failed.querySelector('parsererror')) throw new Error('no parsererror in the failed document');
        \\globalThis.kept = [...failed.querySelectorAll('p')];
    );
    _ = try expectOneBlock(browser, "kept", 2, 2);
}

test "A3 abort: a failed XML fragment parse leaves no block behind; DOMParser on malformed XML leaves the kept elements' block theirs" {
    try onFreshThread(failedXmlParses);
}

// ---------------------------------------------------------------------------
// Template contents and declarative shadow roots; DOMParser and XML runs

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

fn templateContentsAndShadowRoots() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // The page's parser: a template's contents (another document) and a
    // declarative shadow root are the same run's.
    try loadPage(browser, "<!doctype html><body>" ++ templates ++ "</body>");
    try run(browser, five ++ "globalThis.loaded = five(document);");
    _ = try expectOneBlock(browser, "loaded", 5, 5);
    // The fragment parser (setHTMLUnsafe, innerHTML) and a document parse
    // with no script (Document.parseHTMLUnsafe): each its own run.
    try run(browser,
        \\const host = document.body.appendChild(document.createElement('div'));
    ++ "const html = '" ++ templates ++ "';" ++
        \\host.setHTMLUnsafe(html);
        \\globalThis.fromFragment = five(host);
        \\globalThis.parsed = Document.parseHTMLUnsafe(html);
        \\globalThis.fromDocument = five(parsed);
        \\const inner = document.body.appendChild(document.createElement('div'));
        \\inner.innerHTML = html;
        \\globalThis.fromInner = [...five(inner).slice(0, 3), ...inner.querySelector('#sh template').content.querySelectorAll('p')];
    );
    const loaded = try expectOneBlock(browser, "loaded", 5, 5);
    const fragment = try expectOneBlock(browser, "fromFragment", 5, 5);
    const document = try expectOneBlock(browser, "fromDocument", 5, 5);
    // innerHTML attaches no declarative shadow root: that template stays an
    // element, with its two `p` in its contents.
    const inner = try expectOneBlock(browser, "fromInner", 5, 5);
    try testing.expect(loaded != fragment and fragment != document and document != inner);
}

test "A3 abort: a template's contents and a declarative shadow root share with their run; its cache is gone after it" {
    try onFreshThread(templateContentsAndShadowRoots);
}

fn templateRunReplacedMidParse() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body></body>");
    // A script-created parser, left inside a template's contents after a
    // declarative shadow root.
    try run(browser, "document.open(); document.write('<!doctype html><body><div id=sh><template shadowrootmode=open>" ++ p ++ p ++ "</template></div><template id=t>" ++ p ++ p ++ "<div>');" ++
        \\globalThis.kept = [...document.getElementById('sh').shadowRoot.querySelectorAll('p'), ...document.getElementById('t').content.querySelectorAll('p')];
    );
    const block = try expectOneBlock(browser, "kept", 4, 5);
    try run(browser, "document.open();");
    try testing.expect(try expectOneBlock(browser, "kept", 4, 4) == block);
    try run(browser, "document.close();");
    _ = try expectOneBlock(browser, "kept", 4, 4);
}

test "A3 abort: a run replaced inside a template's contents, after a declarative shadow root - its cache lets go" {
    try onFreshThread(templateRunReplacedMidParse);
}

fn domParserAndXmlRuns() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body></body>");
    try run(browser, "globalThis.fromHTML = [...new DOMParser().parseFromString('" ++ p ++ p ++ "', 'text/html').querySelectorAll('p')];" ++
        "globalThis.fromXML = [...new DOMParser().parseFromString('<r>" ++ xp ++ xp ++ "</r>', 'application/xml').querySelectorAll('p')];" ++
        "globalThis.xml = new DOMParser().parseFromString('<r/>', 'application/xml'); xml.documentElement.innerHTML = '" ++ xp ++ xp ++ "';" ++
        "globalThis.fromXMLFragment = [...xml.querySelectorAll('p')];");
    const html = try expectOneBlock(browser, "fromHTML", 2, 2);
    const xml = try expectOneBlock(browser, "fromXML", 2, 2);
    const xml_fragment = try expectOneBlock(browser, "fromXMLFragment", 2, 2);
    try testing.expect(html != xml and xml != xml_fragment);
}

test "A3 abort: DOMParser's HTML and XML runs and an XML fragment parse each end with their cache gone" {
    try onFreshThread(domParserAndXmlRuns);
}
