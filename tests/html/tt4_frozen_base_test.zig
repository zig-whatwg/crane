//! HTML 2.4.3 and 4.2.3: a base is frozen when it becomes first or its
//! href changes, while a document without one uses its current fallback.
const std = @import("std");
const Browser = @import("browser").Browser;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise(source: []const u8) !void {
    const allocator = std.testing.allocator;
    const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const page_url = "https://tt4.test/original/page.html";
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head></head><body></body>", .{ .base_url = page_url });
    const result = try page.evaluateScriptToString(source, allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("true", result);
}

fn onThread(source: []const u8) !void {
    const Run = struct {
        fn run(script: []const u8, failure: *?anyerror) void {
            exercise(script) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ source, &failure });
    thread.join();
    if (failure) |err| return err;
}

test "frozen base: removing the first chooses the second" {
    try onThread(
        \\const first = document.createElement('base'), second = document.createElement('base');
        \\first.href = '/first/'; second.href = '/second/';
        \\document.head.append(first, second);
        \\if (document.baseURI !== 'https://tt4.test/first/') throw Error(document.baseURI);
        \\first.remove();
        \\document.baseURI === 'https://tt4.test/second/'
    );
}

test "frozen base: changing a non-first href leaves the first effective" {
    try onThread(
        \\document.head.innerHTML = '<base href="/first/"><base href="/second/">';
        \\document.head.lastChild.href = '/changed/';
        \\document.baseURI === 'https://tt4.test/first/'
    );
}

test "frozen base: removing its ancestor chooses the remaining base" {
    try onThread(
        \\const ancestor = document.createElement('div'), first = document.createElement('base'), second = document.createElement('base');
        \\first.href = '/first/'; second.href = '/second/'; ancestor.append(first);
        \\document.body.append(ancestor, second);
        \\if (document.baseURI !== 'https://tt4.test/first/') throw Error(document.baseURI);
        \\ancestor.remove();
        \\document.baseURI === 'https://tt4.test/second/'
    );
}

test "frozen base: without a base the fallback follows pushState" {
    try onThread(
        \\history.pushState(null, '', '/changed/page.html');
        \\document.baseURI === 'https://tt4.test/changed/page.html'
    );
}

test "frozen base: pushState leaves a relative base frozen until href changes" {
    try onThread(
        \\const base = document.createElement('base'); base.href = 'child/'; document.head.append(base);
        \\history.pushState(null, '', '/changed/page.html');
        \\if (document.baseURI !== 'https://tt4.test/original/child/') throw Error(document.baseURI);
        \\if (base.href !== 'https://tt4.test/changed/child/') throw Error(base.href);
        \\base.href = 'child/';
        \\document.baseURI === 'https://tt4.test/changed/child/'
    );
}

test "frozen base: unrelated base removal refreezes against the current fallback like browsers" {
    // Golden rule 2, source-derived evidence (not a WPT/browser run):
    // Blink Document::ProcessBaseElement and WebKit Document::processBaseElement
    // recompute on base mutations. Gecko HTMLSharedElement::UnbindFromTree
    // likewise calls SetBaseURIUsingFirstBaseWithHref(doc, nullptr).
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/document.cc
    // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Document.cpp
    // https://github.com/mozilla-firefox/firefox/blob/main/dom/html/HTMLSharedElement.cpp
    try onThread(
        \\document.head.innerHTML = '<base href="child/"><base href="ignored/">';
        \\history.pushState(null, '', '/changed/page.html');
        \\if (document.baseURI !== 'https://tt4.test/original/child/') throw Error(document.baseURI);
        \\document.head.lastChild.remove();
        \\document.baseURI === 'https://tt4.test/changed/child/'
    );
}

test "frozen base: target changes refreeze as in Blink and WebKit" {
    // Golden rule 2, source-derived: Blink HTMLBaseElement::ParseAttribute
    // and WebKit HTMLBaseElement::attributeChanged reprocess both href and
    // target. Gecko HTMLSharedElement::AfterSetAttr updates only the target.
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/html_base_element.cc
    // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLBaseElement.cpp
    try onThread(
        \\const base = document.createElement('base'); base.href = 'child/'; document.head.append(base);
        \\history.pushState(null, '', '/changed/page.html');
        \\if (document.baseURI !== 'https://tt4.test/original/child/') throw Error(document.baseURI);
        \\base.target = '_self';
        \\document.baseURI === 'https://tt4.test/changed/child/'
    );
}

test "frozen base: invalid and forbidden hrefs leave a live fallback like WebKit and Gecko" {
    // Source-derived majority, no newer fallback rule: WebKit
    // Document::processBaseElement clears m_baseElementURL and updateBaseURL
    // follows fallbackBaseURL on setURL; Gecko SetBaseURI(nullptr) makes
    // Document::GetDocBaseURI return GetFallbackBaseURI. Blink freezes the
    // fallback for forbidden schemes, but not an invalid parse (Q11).
    try onThread(
        \\const base = document.createElement('base'); document.head.append(base);
        \\for (const href of ['http://[', 'data:text/plain,blocked', 'javascript:1']) {
        \\  history.replaceState(null, '', '/original/page.html');
        \\  base.setAttribute('href', href);
        \\  history.pushState(null, '', '/changed/page.html');
        \\  if (document.baseURI !== 'https://tt4.test/changed/page.html') throw Error(href + ' -> ' + document.baseURI);
        \\}
        \\true
    );
}

test "frozen base: shadow base mutations and host removal leave the document base frozen" {
    // HTML requires a base in a DOCUMENT tree. DOM removing steps also
    // visit shadow descendants with the removed host's old parent.
    try onThread(
        \\const base = document.createElement('base'); base.href = 'child/'; document.head.append(base);
        \\const host = document.createElement('div'); document.body.append(host);
        \\const shadow = host.attachShadow({mode:'open'});
        \\history.pushState(null, '', '/changed/page.html');
        \\shadow.innerHTML = '<base href="/shadow/">';
        \\shadow.firstChild.target = '_self';
        \\if (document.baseURI !== 'https://tt4.test/original/child/') throw Error(document.baseURI);
        \\host.remove();
        \\document.baseURI === 'https://tt4.test/original/child/'
    );
}

fn encodedBase() !void {
    // HTML set-frozen step 2 passes the document's character encoding to
    // the URL parser, just as base.href does. No script realm is needed.
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(allocator, &context);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setURL(document, "https://tt4.test/page.html");
    try dom.document_internals.setEncoding(document, "windows-1252");
    const base = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("base"), .notPassed());
    _ = try interfaces.Node.call_appendChild(document, base);
    try interfaces.HTMLBaseElement.set_href(base, "?q=é");
    const actual = try interfaces.Node.get_baseURI(document);
    defer allocator.free(actual);
    try std.testing.expectEqualStrings("https://tt4.test/page.html?q=%E9", actual);
}

test "frozen base: URL query uses the document character encoding" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            encodedBase() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// Count completed recomputations without adding production instrumentation.
/// A valid first base[href] stays connected: each recomputation copies its
/// serialization before freeing the current buffer. The observer recognizes
/// that buffer through the owning hook. It does not count no-href attempts
/// that allocate nothing, and is disabled before document teardown.
const RecomputeObserver = struct {
    child: std.mem.Allocator,
    document: ?*runtime.Instance = null,
    replacements: usize = 0,

    fn currentURL(document: *runtime.Instance) ?[]const u8 {
        // Keep the regression executable on BASE, which had no frozen state.
        // It then observes zero replacements and fails the first count of one.
        if (comptime @hasDecl(dom.document_internals, "getFrozenBaseURL")) {
            return dom.document_internals.getFrozenBaseURL(document);
        }
        return null;
    }

    fn allocator(self: *RecomputeObserver) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *RecomputeObserver = @ptrCast(@alignCast(ctx));
        return self.child.rawAlloc(len, alignment, ra);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *RecomputeObserver = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(memory, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *RecomputeObserver = @ptrCast(@alignCast(ctx));
        return self.child.rawRemap(memory, alignment, new_len, ra);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *RecomputeObserver = @ptrCast(@alignCast(ctx));
        if (self.document) |document| {
            if (currentURL(document)) |current| {
                if (memory.ptr == current.ptr and memory.len == current.len) self.replacements += 1;
            }
        }
        self.child.rawFree(memory, alignment, ra);
    }

    fn expect(self: *RecomputeObserver, count: usize) !void {
        try std.testing.expectEqual(count, self.replacements);
        const current = currentURL(self.document.?) orelse return error.MissingFrozenBaseURL;
        try std.testing.expectEqualStrings("https://tt4.test/first/", current);
        self.replacements = 0;
    }
};

fn countElement(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

fn destroyIfDetached(node: *runtime.Instance) void {
    if ((interfaces.Node.get_parentNode(node) catch null) == null) dom.node_creation.destroyUninserted(node);
}

fn countRecomputations() !void {
    var observer: RecomputeObserver = .{ .child = std.testing.allocator };
    const allocator = observer.allocator();
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(allocator, &context);
    defer interfaces.Document.deinit(document);
    defer observer.document = null;
    try dom.document_internals.setURL(document, "https://tt4.test/page.html");
    const root = try countElement(document, "html");
    defer destroyIfDetached(root);
    _ = try interfaces.Node.call_appendChild(document, root);
    const first = try countElement(document, "base");
    defer destroyIfDetached(first);
    try interfaces.HTMLBaseElement.set_href(first, "https://tt4.test/first/");
    _ = try interfaces.Node.call_appendChild(root, first);

    observer.document = document;
    const later = try countElement(document, "base");
    defer destroyIfDetached(later);
    _ = try interfaces.Node.call_appendChild(root, later);
    try observer.expect(1);

    // A later base still recomputes, but the walk stops at the first href.
    // Every expect also pins that first URL, even when the later href differs.
    try interfaces.HTMLBaseElement.set_href(later, "https://tt4.test/later/");
    try observer.expect(1);
    try interfaces.Element.call_removeAttribute(later, runtime.DOMString.initInterned("href"));
    try observer.expect(1);
    try interfaces.HTMLBaseElement.set_target(later, runtime.DOMString.initInterned("_self"));
    try observer.expect(1);
    try interfaces.Element.call_removeAttribute(later, runtime.DOMString.initInterned("target"));
    try observer.expect(1);
    try interfaces.Element.call_setAttribute(later, runtime.DOMString.initInterned("data-tt4"), .{ .domstring = runtime.DOMString.initInterned("value") });
    try observer.expect(0);
    try interfaces.Element.call_removeAttribute(later, runtime.DOMString.initInterned("data-tt4"));
    try observer.expect(0);
    _ = try interfaces.Node.call_removeChild(root, later);
    try observer.expect(1);

    const ordinary = try countElement(document, "div");
    defer destroyIfDetached(ordinary);
    _ = try interfaces.Node.call_appendChild(root, ordinary);
    try observer.expect(0);
    try interfaces.Element.call_setAttribute(ordinary, runtime.DOMString.initInterned("href"), .{ .domstring = runtime.DOMString.initInterned("unused") });
    try observer.expect(0);
    try interfaces.Element.call_setAttribute(ordinary, runtime.DOMString.initInterned("target"), .{ .domstring = runtime.DOMString.initInterned("_self") });
    try observer.expect(0);
    _ = try interfaces.Node.call_removeChild(root, ordinary);
    try observer.expect(0);

    const subtree = try countElement(document, "div");
    defer destroyIfDetached(subtree);
    const child = try countElement(document, "span");
    defer destroyIfDetached(child);
    _ = try interfaces.Node.call_appendChild(subtree, child);
    const text = try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned("text"));
    defer destroyIfDetached(text);
    _ = try interfaces.Node.call_appendChild(child, text);
    try observer.expect(0);
    _ = try interfaces.Node.call_appendChild(root, subtree);
    try observer.expect(0);
    _ = try interfaces.Node.call_removeChild(root, subtree);
    try observer.expect(0);
}

test "frozen base: only base lifecycle and href or target mutations recompute once" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            countRecomputations() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
