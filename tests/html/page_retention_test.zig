//! Lane pageretention1: what an ended page leaves in its Browser's slab.
//!
//! Lanes unwrapped1 and abortsig1 made a page's nodes and AbortSignals give
//! their slab slots back when its realm ends. What they measured still
//! outliving a page - until the Browser ends, so `leaks --atExit` sees none
//! of it - was:
//!
//! 1. a [SameObject] child its owner keeps (same_object.KeptChild) and
//!    severs with its interface's destructor chain alone;
//! 2. a template's contents, which its template's teardown skips during a
//!    coordinated teardown;
//! 3. the realm's Window, its Location and one HTMLCollection the page's
//!    load makes for itself;
//! 4. a wrapped node of a detached wrapped tree, when the wrapper cache's
//!    end reaches the node before its root.
//!
//! Each test churns pages in one Browser and requires every type's live slab
//! slots after each page to be the first page's: a page's count must not
//! include the pages before it. The count is read from the slab by vtable
//! name, so an object torn down with its slot still issued counts. The
//! Browser runs on std.testing.allocator, so whatever is freed must be freed
//! exactly once, and each test runs on a thread of its own (tests/html is one
//! executable; a Browser's agent belongs to the thread that made it).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

/// Live slab slots by vtable name - with, for the report, how many of each
/// were ever wrapped and how many finished their teardown with the slot
/// still issued.
const Census = struct {
    names: [512][]const u8 = undefined,
    counts: [512]usize = undefined,
    wrapped: [512]usize = undefined,
    torn_down: [512]usize = undefined,
    len: usize = 0,

    fn of(browser: *browser_mod.Browser) Census {
        var census: Census = .{};
        var slab = browser.scope.slab.slabs;
        while (slab) |each| : (slab = each.next) {
            for (&each.slots) |*slot| {
                const instance: *runtime.Instance = @ptrCast(slot);
                if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
                census.add(instance.vtable.name, instance);
            }
        }
        return census;
    }

    fn add(self: *Census, name: []const u8, instance: *runtime.Instance) void {
        const k = for (self.names[0..self.len], 0..) |known, k| {
            if (std.mem.eql(u8, known, name)) break k;
        } else blk: {
            if (self.len == self.names.len) return;
            self.names[self.len] = name;
            self.counts[self.len] = 0;
            self.wrapped[self.len] = 0;
            self.torn_down[self.len] = 0;
            self.len += 1;
            break :blk self.len - 1;
        };
        self.counts[k] += 1;
        if (runtime.instance_lifecycle.wasWrapped(instance)) self.wrapped[k] += 1;
        if (runtime.instance_lifecycle.isCleanupStarted(instance)) self.torn_down[k] += 1;
    }

    fn count(self: *const Census, name: []const u8) usize {
        for (self.names[0..self.len], 0..) |known, k| {
            if (std.mem.eql(u8, known, name)) return self.counts[k];
        }
        return 0;
    }

    /// Print every type with more slots than in `first`; true if any.
    fn grewSince(self: *const Census, first: *const Census, page: usize) bool {
        var grew = false;
        for (self.names[0..self.len], 0..) |name, k| {
            if (stillRetained(name)) continue;
            const before = first.count(name);
            if (self.counts[k] > before) {
                std.debug.print("page {d}: {s} {d} -> {d} (wrapped {d}, torn down {d})\n", .{ page, name, before, self.counts[k], self.wrapped[k], self.torn_down[k] });
                grew = true;
            }
        }
        return grew;
    }
};

/// The one type an ended page still leaves: its Window (and every frame's).
/// TODO(Window slot, queued by the integrator for 0.1): a Window is held by
/// raw pointers across realms - an opener, a MessageEvent's source,
/// Navigation, Storage and Location back links, the iframe integration -
/// which read a torn-down Window safely today and would read whatever took a
/// returned slot. They become generation links (or counted references)
/// first; then the realm's end returns the Window's slot and this goes.
fn stillRetained(name: []const u8) bool {
    return std.mem.eql(u8, name, "Window");
}

/// Navigate (ending the page before, if any), load `html`, run `script`,
/// let its tasks run and collect what it let go of, so the counts are the
/// page's own.
fn openPage(browser: *browser_mod.Browser, html: []const u8, script: []const u8) !void {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = "about:blank" });
    page.runScript(script) catch |err| {
        std.debug.print("script failed: {s}\n", .{script});
        return err;
    };
    try settle(browser);
    try page.runScript("TestUtils.gc(); TestUtils.gc();");
    try settle(browser);
    const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
    defer testing.allocator.free(failed);
    if (failed.len != 0) {
        std.debug.print("page check failed: {s}\n", .{failed});
        return error.PageCheckFailed;
    }
}

/// Run the page's tasks until its script's asynchronous work is done: a
/// script that waits on something sets `globalThis.pending` and clears it
/// when that settles. Never a fixed delay (a loaded machine runs fewer
/// tasks in one); bounded at 10 s.
fn settle(browser: *browser_mod.Browser) !void {
    const page = browser.current_context orelse return error.NoPage;
    var waited: usize = 0;
    while (true) : (waited += 50) {
        _ = try browser.runEventLoopBlocking(50);
        const pending = try page.evaluateScriptToString("String(!!globalThis.pending)", testing.allocator);
        defer testing.allocator.free(pending);
        if (std.mem.eql(u8, pending, "false")) return;
        if (waited >= 10_000) {
            std.debug.print("the page's work never settled\n", .{});
            return error.PageNeverSettled;
        }
    }
}

/// Open `pages` pages of `html` running `script` each, and require every
/// type's slots after each page to be the first page's. The first page must
/// hold at least one slot of each type in `own` - a script that made none
/// of what it is about cannot pass.
fn churn(html: []const u8, script: []const u8, pages: usize, own: []const []const u8) !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();

    try openPage(browser, html, script);
    const first = Census.of(browser);
    for (own) |name| {
        if (first.count(name) == 0) {
            std.debug.print("the first page holds no {s}\n", .{name});
            return error.NothingMeasured;
        }
    }
    var grew = false;
    for (1..pages) |page| {
        try openPage(browser, html, script);
        const now = Census.of(browser);
        if (now.grewSince(&first, page + 1)) grew = true;
    }
    if (grew) return error.PageStorageRetained;
}

const empty_page = "<!doctype html><body></body>";

fn emptyPages() !void {
    // Nothing but the page itself: its Location, its document and what the
    // load makes for itself must go with it (its Window: `stillRetained`).
    try churn(empty_page, "globalThis.l = location.href;", 4, &.{ "Window", "Location" });
}

test "an ended page's Window, Location and load-time objects give back their slots" {
    try helpers.onFreshThread(emptyPages);
}

fn keptChildren() !void {
    // Every [SameObject] child an owner keeps with same_object.KeptChild,
    // read by script - some kept in globals until the page ends, some
    // dropped and collected with nothing else holding them.
    try churn(empty_page,
        \\const d = document.body.appendChild(document.createElement('div'));
        \\d.style.color = 'red';
        \\const host = document.body.appendChild(document.createElement('div'));
        \\const root = host.attachShadow({ mode: 'open' });
        \\const canvas = document.body.appendChild(document.createElement('canvas'));
        \\globalThis.kept = [document.styleSheets, document.fonts, getSelection(), root.styleSheets, canvas.getContext('2d')];
        \\if (document.all.length < 1) failed = 'no document.all';
        \\for (let i = 0; i < 20; ++i) document.createElement('span').style.color = 'blue';
    , 4, &.{ "StyleSheetList", "FontFaceSet", "Selection", "CSSStyleProperties", "HTMLAllCollection", "CanvasRenderingContext2D" });
}

test "an ended page's kept [SameObject] children give back their slots" {
    try helpers.onFreshThread(keptChildren);
}

fn templateContents() !void {
    // Parsed templates (their contents never read), a script-made one and
    // one whose content script reads: each template's contents and its
    // owner document's go with the page.
    try churn("<!doctype html><body>" ++ ("<template><div><span>a</span></div></template>" ** 30) ++ "</body>",
        \\const t = document.createElement('template');
        \\t.innerHTML = '<p>x</p><p>y</p>';
        \\document.body.appendChild(t);
        \\globalThis.content = document.querySelector('template').content;
        \\if (content.firstChild.localName !== 'div') failed = 'no content';
    , 4, &.{ "HTMLTemplateElement", "DocumentFragment" });
}

test "an ended page's template contents give back their slots" {
    try helpers.onFreshThread(templateContents);
}

fn detachedWrappedTrees() !void {
    // Detached trees script holds until the page ends - a wrapped root with
    // wrapped and unwrapped descendants - whichever of a tree's entries the
    // wrapper cache's end reaches first.
    try churn(empty_page,
        \\globalThis.trees = [];
        \\for (let i = 0; i < 50; ++i) {
        \\  const root = document.createElement('section');
        \\  root.innerHTML = '<div><p><b>x</b></p></div><em>y</em>';
        \\  trees.push([root, root.querySelector('b'), root.firstChild]);
        \\}
    , 4, &.{"HTMLElement"});
}

test "an ended page's detached wrapped trees give back their slots" {
    try helpers.onFreshThread(detachedWrappedTrees);
}

fn framesRemovedTouched() !void {
    // Frames made, their documents read from the page, and removed in it.
    try churn(empty_page,
        \\for (let i = 0; i < 2; ++i) {
        \\  const f = document.body.appendChild(document.createElement('iframe'));
        \\  f.contentWindow.document.body.textContent = 'x';
        \\  f.remove();
        \\}
    , 4, &.{"Window"});
}

test "frames removed in their page give back their slots" {
    try helpers.onFreshThread(framesRemovedTouched);
}

fn framesRemovedUntouched() !void {
    // Frames made and removed, nothing of them read.
    try churn(empty_page,
        \\for (let i = 0; i < 2; ++i) document.body.appendChild(document.createElement('iframe')).remove();
    , 4, &.{"Window"});
}

test "frames removed untouched give back their slots" {
    try helpers.onFreshThread(framesRemovedUntouched);
}

fn framesAtPageEnd() !void {
    // Frames still in the page when it ends, their documents read.
    try churn(empty_page,
        \\for (let i = 0; i < 2; ++i) document.body.appendChild(document.createElement('iframe')).contentWindow.document.body.textContent = 'x';
    , 4, &.{"Window"});
}

test "frames alive at their page's end give back their slots" {
    try helpers.onFreshThread(framesAtPageEnd);
}

fn createdDocuments() !void {
    // Documents script makes, their kept children read: held until the
    // page ends, and dropped in it.
    try churn(empty_page,
        \\globalThis.docs = [];
        \\for (let i = 0; i < 10; ++i) {
        \\  const d = document.implementation.createHTMLDocument('t');
        \\  const p = new DOMParser().parseFromString('<p>x</p>', 'text/html');
        \\  const parts = [d.styleSheets, d.all, d.fonts, p.styleSheets, d.body.style, p.body.attributes];
        \\  if (i % 2) docs.push(d, p, parts);
        \\}
    , 4, &.{ "StyleSheetList", "Document" });
}

test "documents script makes give back their kept children's slots" {
    try helpers.onFreshThread(createdDocuments);
}

fn attributeMaps() !void {
    // NamedNodeMaps of elements in the document, of detached elements and
    // of collected ones.
    try churn(empty_page,
        \\globalThis.maps = [];
        \\for (let i = 0; i < 20; ++i) {
        \\  const e = document.body.appendChild(document.createElement('div'));
        \\  e.setAttribute('a', i);
        \\  maps.push(e.attributes);
        \\  const d = document.createElement('span');
        \\  d.setAttribute('b', i);
        \\  if (i % 2) maps.push(d.attributes); else d.attributes.length;
        \\}
    , 4, &.{"NamedNodeMap"});
}

test "attribute maps give back their slots" {
    try helpers.onFreshThread(attributeMaps);
}

fn syncXhrEvents() !void {
    // XHR events no listener wraps (readystatechange, progress, load).
    try churn(empty_page,
        \\globalThis.xhrs = [];
        \\for (let i = 0; i < 10; ++i) {
        \\  const x = new XMLHttpRequest();
        \\  x.open('GET', 'data:text/plain,hi', false);
        \\  x.send();
        \\  if (x.responseText !== 'hi') failed = 'xhr ' + x.status;
        \\  xhrs.push(x);
        \\}
    , 4, &.{"XMLHttpRequest"});
}

test "XHR events nothing listens to give back their slots" {
    try helpers.onFreshThread(syncXhrEvents);
}

fn templateOnly() !void {
    // Parsed templates whose contents nothing reads.
    try churn("<!doctype html><body>" ++ ("<template><div><span>a</span></div></template>" ** 30) ++ "</body>", "", 4, &.{"HTMLTemplateElement"});
}

test "parsed templates nothing reads give back their contents' slots" {
    try helpers.onFreshThread(templateOnly);
}

fn framesWithTemplatesRemoved() !void {
    // Frames whose documents hold templates, removed in the page: the
    // collector takes a removed frame's realm, and its realm's end then
    // tears the templates down.
    try churn(empty_page,
        \\for (let i = 0; i < 2; ++i) {
        \\  const f = document.body.appendChild(document.createElement('iframe'));
        \\  f.contentWindow.document.body.innerHTML = '<template><div><span>a</span></div></template>'.repeat(10);
        \\  f.remove();
        \\}
    , 4, &.{"Window"});
}

test "templates of frames removed in their page give back their contents' slots" {
    try helpers.onFreshThread(framesWithTemplatesRemoved);
}

// Children an owner keeps and frees whole (runtime.gc.releaseOwned): made
// where the owner's realm has no engine, so the hand-out's edge wraps
// nothing and no wrapper will ever free them. Their owner's teardown is
// their only exit.

const interfaces = @import("interfaces");
const dom = @import("dom");

fn liveSlots(names: []const []const u8) usize {
    const scope = runtime.BrowserScope.standalone() orelse return 0;
    var live: usize = 0;
    var slab = scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            for (names) |name| {
                if (std.mem.eql(u8, instance.vtable.name, name)) live += 1;
            }
        }
    }
    return live;
}

test "an owner with no engine realm frees the children it keeps whole, slots and all" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    try testing.expect(!context.hasEngine());

    const kept = [_][]const u8{ "StyleSheetList", "HTMLAllCollection", "FontFaceSet", "CSSStyleProperties", "NamedNodeMap" };
    const before = liveSlots(&kept);

    const document = try interfaces.Document.init(testing.allocator, &context);
    var document_live = true;
    defer if (document_live) dom.node_creation.destroyUninserted(document);
    try dom.document_internals.setDocumentType(document, .html);
    try dom.document_internals.setContentType(document, "text/html");
    _ = try interfaces.Document.get_styleSheets(document);
    _ = try interfaces.Document.get_all(document);
    _ = try interfaces.Document.get_fonts(document);
    const html = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("html"), .notPassed());
    _ = try interfaces.Node.call_appendChild(document, html);
    _ = try interfaces.HTMLElement.get_style(html);
    _ = try interfaces.Element.get_attributes(html);
    const detached = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("div"), .notPassed());
    var detached_live = true;
    defer if (detached_live) dom.node_creation.destroyUninserted(detached);
    _ = try interfaces.HTMLElement.get_style(detached);
    _ = try interfaces.Element.get_attributes(detached);
    try testing.expectEqual(before + kept.len + 2, liveSlots(&kept));

    detached_live = false;
    dom.node_creation.destroyUninserted(detached);
    document_live = false;
    dom.node_creation.destroyUninserted(document);
    try testing.expectEqual(before, liveSlots(&kept));
}

// A frame's objects the parent page keeps across the frame's end: its
// document, a node of it, its Location and History - and a node of it the
// parent adopted into its own tree. Read after the frame's realm ended and
// after the parent churned impostors of the same types (each announcing
// itself): no crash, never an impostor's answer, and the adopted node - a
// node its tree still owns - untouched.

const frame_holders_script =
    \\globalThis.held = [];
    \\globalThis.reads = [];
    \\function hold(f) {
    \\  const w = f.contentWindow;
    \\  const d = f.contentDocument;
    \\  d.title = 'frame';
    \\  d.body.innerHTML = '<p id=p>frame</p>';
    \\  const adopted = document.body.appendChild(document.adoptNode(d.createElement('b')));
    \\  adopted.textContent = 'kept';
    \\  held.push({ d, node: d.getElementById('p'), loc: w.location, hist: w.history, adopted });
    \\}
    \\function churn() {
    \\  for (let i = 0; i < 4; ++i) {
    \\    const f = document.body.appendChild(document.createElement('iframe'));
    \\    f.contentDocument.title = 'impostor';
    \\    f.contentDocument.body.innerHTML = '<p>impostor</p>'.repeat(20);
    \\  }
    \\  for (let i = 0; i < 40; ++i) {
    \\    const d = document.implementation.createHTMLDocument('impostor');
    \\    d.body.innerHTML = '<p>impostor</p>';
    \\    document.body.appendChild(document.createElement('p')).textContent = 'impostor';
    \\  }
    \\}
    \\function readAll() {
    \\  for (const h of held) {
    \\    for (const [name, read] of [['title', () => h.d.title], ['node', () => h.node.textContent],
    \\        ['href', () => h.loc.href], ['length', () => h.hist.length], ['adopted', () => h.adopted.textContent]]) {
    \\      let out;
    \\      try { out = String(read()); } catch (e) { out = '!' + e.name; }
    \\      reads.push(name + '=' + out);
    \\      if (out.includes('impostor')) failed = 'an impostor answered: ' + name + '=' + out;
    \\    }
    \\    if (h.adopted.textContent !== 'kept') failed = 'the adopted node changed: ' + h.adopted.textContent;
    \\  }
    \\}
;

fn readsOf(browser: *browser_mod.Browser) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString("reads.join(' ')", testing.allocator);
}

fn removedFrameHolders() !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    for (0..3) |_| {
        try openPage(browser, empty_page, frame_holders_script ++
            \\for (let i = 0; i < 2; ++i) {
            \\  const f = document.body.appendChild(document.createElement('iframe'));
            \\  hold(f);
            \\  f.remove();
            \\}
            \\TestUtils.gc(); TestUtils.gc();
        );
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript("churn(); TestUtils.gc(); readAll();");
        try settle(browser);
        const reads = try readsOf(browser);
        defer testing.allocator.free(reads);
        std.debug.print("removed frame, held: {s}\n", .{reads});
        const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
        defer testing.allocator.free(failed);
        if (failed.len != 0) {
            std.debug.print("{s}\n", .{failed});
            return error.PageCheckFailed;
        }
    }
}

test "a removed frame's document, node, Location and History read safely from the parent" {
    try helpers.onFreshThread(removedFrameHolders);
}

fn navigatedFrameHolders() !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    for (0..3) |_| {
        try openPage(browser, empty_page, frame_holders_script ++
            \\globalThis.frames_ = [];
            \\globalThis.pending = 2;
            \\for (let i = 0; i < 2; ++i) {
            \\  const f = document.body.appendChild(document.createElement('iframe'));
            \\  hold(f);
            \\  frames_.push(f);
            \\  f.onload = () => { if (f.contentDocument.body.textContent === 'next') --pending; };
            \\  f.srcdoc = '<p>next</p>';
            \\}
        );
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript(
            \\if (frames_[0].contentDocument === held[0].d) failed = 'the frame did not navigate';
            \\TestUtils.gc(); churn(); TestUtils.gc(); readAll();
        );
        try settle(browser);
        const reads = try readsOf(browser);
        defer testing.allocator.free(reads);
        std.debug.print("navigated frame, held: {s}\n", .{reads});
        const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
        defer testing.allocator.free(failed);
        if (failed.len != 0) {
            std.debug.print("{s}\n", .{failed});
            return error.PageCheckFailed;
        }
    }
}

test "a navigated frame's old document, node, Location and History read safely from the parent" {
    try helpers.onFreshThread(navigatedFrameHolders);
}

// A URL's query object (its searchParams, made with the URL) and a
// MessageChannel's ports: children their owner frees - whole, when no
// wrapper reached them.

fn urlQueryObjects() !void {
    // URLs made and dropped - their searchParams never read, read and
    // dropped - and some kept until the page ends.
    try churn(empty_page,
        \\globalThis.kept = [];
        \\for (let i = 0; i < 50; ++i) new URL('http://a.test/?q=' + i);
        \\for (let i = 0; i < 20; ++i) { const u = new URL('http://a.test/?r=' + i); if (u.searchParams.get('r') !== String(i)) failed = 'read'; }
        \\for (let i = 0; i < 5; ++i) kept.push(new URL('http://a.test/?k=' + i));
        \\for (let i = 0; i < 5; ++i) kept.push(new URL('http://a.test/?s=' + i).searchParams);
    , 4, &.{ "URL", "URLSearchParams" });
}

test "URLs' query objects give back their slots" {
    try helpers.onFreshThread(urlQueryObjects);
}

fn queryObjectOutlivesItsUrl() !void {
    // Script keeps `url.searchParams` and drops the URL: the URL is collected
    // and its teardown runs; impostors take whatever slots it freed. The
    // query object script holds is cut from its URL: it never reaches the
    // URL's freed state, and no impostor answers for it.
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    for (0..3) |_| {
        try openPage(browser, empty_page,
            \\globalThis.held = (() => new URL('http://a.test/?x=1').searchParams)();
            \\TestUtils.gc(); TestUtils.gc();
        );
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript(
            \\globalThis.impostors = [];
            \\for (let i = 0; i < 200; ++i) impostors.push(new URL('http://impostor.test/?impostor=' + i), new URLSearchParams('impostor=1'));
            \\let appended, text;
            \\try { held.append('y', '2'); appended = 'appended'; } catch (e) { appended = '!' + e.name; }
            \\try { text = held.toString(); } catch (e) { text = '!' + e.name; }
            \\if (String(text).includes('impostor')) failed = 'an impostor answered: ' + text;
            \\for (let i = 0; i < impostors.length; ++i) {
            \\  const s = impostors[i].toString();
            \\  if (s.includes('y=2')) failed = 'an impostor was updated: ' + s;
            \\}
            \\globalThis.readout = appended + ' ' + text;
        );
        try settle(browser);
        const readout = try page.evaluateScriptToString("readout", testing.allocator);
        defer testing.allocator.free(readout);
        std.debug.print("a query object whose URL went: {s}\n", .{readout});
        const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
        defer testing.allocator.free(failed);
        if (failed.len != 0) {
            std.debug.print("{s}\n", .{failed});
            return error.PageCheckFailed;
        }
    }
}

test "a query object script keeps outlives its collected URL safely" {
    try helpers.onFreshThread(queryObjectOutlivesItsUrl);
}

fn messageChannels() !void {
    // Channels made and dropped: port1 read (and used), port2 never - and
    // some kept, whole or by one port, until the page ends.
    try churn(empty_page,
        \\globalThis.kept = [];
        \\for (let i = 0; i < 30; ++i) { const c = new MessageChannel(); if (i % 3 === 0) c.port1.postMessage('x'); }
        \\for (let i = 0; i < 5; ++i) kept.push(new MessageChannel());
        \\for (let i = 0; i < 5; ++i) kept.push(new MessageChannel().port2);
        \\TestUtils.gc(); TestUtils.gc();
    , 4, &.{ "MessageChannel", "MessagePort" });
}

test "message channels give back their ports' slots" {
    try helpers.onFreshThread(messageChannels);
}

fn portOutlivesItsChannel() !void {
    // Script keeps port1, listening, and drops the channel: the channel is
    // collected and frees port2, which script never read; impostor ports -
    // each announcing a message it hears - take whatever slots it freed.
    // port1's messages then go nowhere (its peer is gone: the channel is
    // disentangled), and no impostor hears them.
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    for (0..3) |_| {
        try openPage(browser, empty_page,
            \\globalThis.heard = [];
            \\(() => {
            \\  const c = new MessageChannel();
            \\  globalThis.port1 = c.port1;
            \\  port1.onmessage = e => heard.push('port1 heard ' + e.data);
            \\  port1.addEventListener('close', () => heard.push('close'));
            \\})();
            \\TestUtils.gc(); TestUtils.gc();
        );
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript(
            \\globalThis.impostors = [];
            \\for (let i = 0; i < 100; ++i) {
            \\  const c = new MessageChannel();
            \\  c.port1.onmessage = e => { failed = 'an impostor heard ' + e.data; };
            \\  c.port2.onmessage = e => { failed = 'an impostor heard ' + e.data; };
            \\  impostors.push(c);
            \\}
            \\port1.postMessage('after');
            \\port1.close();
            \\globalThis.pending = 1;
            \\setTimeout(() => { pending = 0; }, 0);
        );
        try settle(browser);
        const heard = try page.evaluateScriptToString("heard.join(',')", testing.allocator);
        defer testing.allocator.free(heard);
        std.debug.print("a port whose channel went: [{s}]\n", .{heard});
        const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
        defer testing.allocator.free(failed);
        if (failed.len != 0) {
            std.debug.print("{s}\n", .{failed});
            return error.PageCheckFailed;
        }
    }
}

test "a port script keeps outlives its collected channel safely" {
    try helpers.onFreshThread(portOutlivesItsChannel);
}

fn transferredPortOutlivesItsChannel() !void {
    // port1 goes to a dedicated worker, which posts on it in a loop while
    // the page drops the channel and collects - the channel freeing port2,
    // which script never read, on the page's thread while the worker's
    // thread posts to it. Six rounds.
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    for (0..6) |_| {
        try openPage(browser, empty_page,
            \\globalThis.reports = [];
            \\globalThis.pending = 1;
            \\(() => {
            \\  const c = new MessageChannel();
            \\  const source = "let port, n = 0; onmessage = e => { port = e.ports[0];" +
            \\    " port.addEventListener('close', () => postMessage('close after ' + n));" +
            \\    " (function loop() { if (n < 400) { port.postMessage(n++); setTimeout(loop, 0); } else postMessage('done ' + n); })(); };";
            \\  globalThis.worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
            \\  worker.onmessage = e => { reports.push(e.data); if (String(e.data).startsWith('done')) pending = 0; };
            \\  worker.onerror = () => { failed = 'worker error'; pending = 0; };
            \\  worker.postMessage('port', [c.port1]);
            \\})();
            \\(function collect(k) { TestUtils.gc(); if (k < 200 && pending) setTimeout(() => collect(k + 1), 0); })(0);
        );
        const page = browser.current_context orelse return error.NoPage;
        const reports = try page.evaluateScriptToString("reports.join(',')", testing.allocator);
        defer testing.allocator.free(reports);
        std.debug.print("a transferred port whose channel went: [{s}]\n", .{reports});
        if (std.mem.indexOf(u8, reports, "done 400") == null) return error.WorkerDidNotFinish;
    }
}

test "a port transferred to a worker outlives its collected channel safely" {
    try helpers.onFreshThread(transferredPortOutlivesItsChannel);
}
