//! FontFaceSet native membership and weak Document source lifetime.
const std = @import("std");
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const doc_value = try browser.evaluateScript("document");
    defer doc_value.release();
    const document = engine.convertToPlatformObject(realm, doc_value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    const first = try interfaces.FontFace.call_constructor(realm, .initInterned("First"), .{ .cssomstring = .initInterned("url(first.woff2)") }, .{ .was_passed = false, .value = undefined });
    const first_generation = runtime.SlabAllocator.generationOf(first);
    defer first.releaseIfUnwrapped(first_generation);
    const second = try interfaces.FontFace.call_constructor(realm, .initInterned("Second"), .{ .cssomstring = .initInterned("url(second.woff2)") }, .{ .was_passed = false, .value = undefined });
    const second_generation = runtime.SlabAllocator.generationOf(second);
    defer second.releaseIfUnwrapped(second_generation);
    try std.testing.expect(set == try interfaces.FontFaceSet.call_add(set, first));
    _ = try interfaces.FontFaceSet.call_add(set, first);
    _ = try interfaces.FontFaceSet.call_add(set, second);
    try std.testing.expectEqual(@as(u32, 2), try interfaces.FontFaceSet.get_size(set));
    try std.testing.expect(try interfaces.FontFaceSet.call_delete(set, first));
    try std.testing.expect(!try interfaces.FontFaceSet.call_delete(set, first));
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    try interfaces.FontFaceSet.call_clear(set);
    try std.testing.expectEqual(@as(u32, 0), try interfaces.FontFaceSet.get_size(set));
    const ready: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
    defer ready.release();
    const again: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
    defer again.release();
    try std.testing.expect(engine.sameValue(realm, ready.borrow(), again.borrow()));
    try std.testing.expect(engine.typeOf(realm, ready.borrow()) == .object);
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "document fonts owns ordered membership and one ready promise without loading unused faces" {
    try fresh(exercise);
}

fn fresh(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                // The thread's own error: name it and its return trace, which
                // the test runner, seeing only `failure`, cannot.
                std.debug.print("style_font_set_state_test: {s}\n", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// Pump `browser`'s loop until its document's FontFaceSet is ready - the
/// settled environment the cases below assert, which waits for the window's
/// load and a rendering opportunity after it - at most 2 s. One fixed 30 ms
/// turn was the FLAKY TEST of feature-queue (row 122 D42): the frame clock's
/// first opportunity may come before the load (src/browser/rendering.zig).
fn untilFontsReady(browser: *browser_mod.Browser) !void {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        if (state.ready.fulfilled) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.FontsNeverReady;
}

fn loadingEnvironment() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = try interfaces.Document.initWith(std.testing.allocator, realm, .{ .ready_state = ._loading_ });
    const generation = runtime.SlabAllocator.generationOf(document);
    defer document.releaseIfUnwrapped(generation);
    const set = try interfaces.Document.get_fonts(document);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
    defer promise.release();
    state.environmentReady();
    try std.testing.expect(!state.ready.fulfilled);
    const style = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
    const resources = style.resourceState() orelse return error.NoResourceState;
    resources.pending = false;
    dom.document_lifecycle.parsingStopped(document);
    try std.testing.expectEqual(._interactive_, try interfaces.Document.get_readyState(document));
    // Readiness only schedules the next resource-selection turn. It neither
    // resolves the promise nor runs author code inside readystatechange.
    try std.testing.expect(resources.pending);
    try std.testing.expect(!state.ready.fulfilled);
    state.environmentReady();
    try std.testing.expect(!state.ready.fulfilled);
    resources.pending = false;
    state.environmentReady();
    try std.testing.expect(!state.ready.fulfilled); // Q50: interactive is still pending.
}

test "font ready waits while the document loads and readiness schedules a resource turn" {
    try fresh(loadingEnvironment);
}

fn readyAfterRendering() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(30);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    try std.testing.expectEqual(._complete_, try interfaces.Document.get_readyState(document));
    const set = try interfaces.Document.get_fonts(document);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
    defer promise.release();
    try std.testing.expect(!state.ready.fulfilled);
    dom.style.engine.resource_loading.updateRendering(document);
    try std.testing.expect(state.ready.fulfilled);
    try std.testing.expect(state.ready.capability == null);
    try std.testing.expect(!dom.style.engine.resource_loading.hasPending(document));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "an empty completed document resolves fonts ready at its next resource turn" {
    try fresh(readyAfterRendering);
}

fn usedTextSelection() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        "<!doctype html><style>" ++
            "@font-face{font-family:Used;src:url(http://127.0.0.1:65533/used);font-weight:400}" ++
            "@font-face{font-family:Used;src:url(http://127.0.0.1:65533/bold);font-weight:700}" ++
            "@font-face{font-family:Other;src:url(http://127.0.0.1:65533/other)}" ++
            "</style><body><span style='font-family:Used;font-weight:400'>A</span>" ++
            "<span style='display:none;font-family:Other'>A</span></body>",
        .{ .base_url = "about:blank" },
    );
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    // Rendering discovers CSS fonts even if script never requested fonts.
    dom.style.engine.resource_loading.updateRendering(document);
    const set = try interfaces.Document.get_fonts(document);
    _ = try interfaces.FontFaceSet.get_size(set);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    try std.testing.expectEqual(@as(usize, 3), state.members.items.len);
    dom.style.engine.resource_loading.updateRendering(document);
    try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(state.members.items[0].face.instance));
    try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(state.members.items[1].face.instance));
    try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(state.members.items[2].face.instance));
    try std.testing.expectEqual(.loading, state.status);
    dom.document_fetches.abortAll(realm);
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "rendering starts the font used by visible text without loading other weights or hidden text" {
    try fresh(usedTextSelection);
}

fn settledReadyFlushesFontsOnly() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head></head><body></body>", .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(30);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    const before: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
    defer before.release();
    dom.style.engine.resource_loading.updateRendering(document);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    try std.testing.expect(state.ready.fulfilled);
    const mutation = try browser.evaluateScript(
        \\const style = document.createElement('style');
        \\style.textContent = '@font-face{font-family:Flush;src:url(http://127.0.0.1:65533/flush)}';
        \\document.head.append(style);
        \\const text = document.createElement('div'); text.textContent = 'A';
        \\text.style.cssText = 'font-family:Flush;background-image:url(http://127.0.0.1:65533/image)';
        \\document.body.append(text); true
    );
    mutation.release();
    const after: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
    defer after.release();
    try std.testing.expect(!engine.sameValue(realm, before.borrow(), after.borrow()));
    try std.testing.expectEqual(.loading, state.status);
    const style = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
    const resources = style.resourceState() orelse return error.NoResourceState;
    try std.testing.expectEqual(@as(usize, 0), resources.cache.count());
    try std.testing.expect(resources.pending);
    dom.document_fetches.abortAll(realm);
}

test "reading a settled ready after text insertion selects fonts without starting CSS images" {
    try fresh(settledReadyFlushesFontsOnly);
}

fn automaticFacePromiseIsLazy() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><style>@font-face{font-family:Unobserved;src:url(http://127.0.0.1:65533/unobserved)}@font-face{font-family:Observed;src:url(http://127.0.0.1:65533/observed)}</style><body></body>", .{ .base_url = "about:blank" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    const global = try browser.evaluateScript("globalThis.cr1AutoUnhandled=0; addEventListener('unhandledrejection',()=>cr1AutoUnhandled++); globalThis");
    defer global.release();
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    _ = try interfaces.FontFaceSet.get_size(set);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    const instance = state.members.items[0].face.instance;
    const face = dom.style.hooks.fontFaceOf(instance) orelse return error.NoFace;
    try std.testing.expect(!face.loaded.initialized);
    // An automatic native load is not a script read of loaded/load().
    try face.start();
    try std.testing.expect(!face.loaded.initialized);
    const observed_instance = state.members.items[1].face.instance;
    const observed_face = dom.style.hooks.fontFaceOf(observed_instance) orelse return error.NoFace;
    try observed_face.start();
    const pending: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(observed_instance) };
    defer pending.release();
    engine.markPromiseAsHandled(realm, pending.borrow());
    const pending_again: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(observed_instance) };
    defer pending_again.release();
    try std.testing.expect(engine.sameValue(realm, pending.borrow(), pending_again.borrow()));
    // Completion requires queued tasks and a transport pump; a single
    // timed loop can return before they finish on the shared build host.
    // Bound the wait, as the shared-font transport regression does.
    for (0..30) |_| {
        if (face.status != .loading and observed_face.status != .loading) break;
        _ = try browser.runEventLoopBlocking(100);
    }
    try std.testing.expectEqual(._error_, try interfaces.FontFace.get_status(instance));
    try std.testing.expect(!face.loaded.initialized);
    const late: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(instance) };
    defer late.release();
    // The late read must deliver the recorded rejection to script's catch.
    // Attach it in the first script turn after native access, before a
    // checkpoint, exactly as a synchronous loaded.catch() expression does.
    try engine.setProperty(realm, global.borrow(), "cr1LateLoaded", late.borrow());
    const reaction = try browser.evaluateScript("cr1LateLoaded.catch(e=>{globalThis.cr1LateFailure=e.name}); void 0");
    defer reaction.release();
    const again: engine.Owned = .{ .value = try interfaces.FontFace.call_load(instance) };
    defer again.release();
    try std.testing.expect(engine.sameValue(realm, late.borrow(), again.borrow()));
    try std.testing.expect(face.loaded.initialized);
    try std.testing.expect(!face.loaded.fulfilled);
    try std.testing.expect(face.loaded.capability == null);
    const settled: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(observed_instance) };
    defer settled.release();
    try std.testing.expect(engine.sameValue(realm, pending.borrow(), settled.borrow()));
    try std.testing.expectEqual(._error_, try interfaces.FontFace.get_status(observed_instance));
    _ = try browser.runEventLoopBlocking(30);
    const result = try page.evaluateScriptToString("cr1LateFailure+':'+cr1AutoUnhandled", std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("NetworkError:0", result);
}

test "automatic CSS face loading creates no unseen JS promise and a late loaded read keeps identity" {
    try fresh(automaticFacePromiseIsLazy);
}

fn usedCompositeAndGeneratedText() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        "<!doctype html><style>" ++
            "@font-face{font-family:Straße;src:url(http://127.0.0.1:65533/early-a);unicode-range:U+41}" ++
            "@font-face{font-family:Straße;src:url(http://127.0.0.1:65533/b);unicode-range:U+42}" ++
            "@font-face{font-family:Straße;src:url(http://127.0.0.1:65533/late-a);unicode-range:U+41}" ++
            "@font-face{font-family:Straße;src:url(http://127.0.0.1:65533/italic);font-style:italic}" ++
            "@font-face{font-family:Straße;src:url(http://127.0.0.1:65533/bold);font-weight:700}" ++
            "@font-face{font-family:'Pseudo, Font';src:url(http://127.0.0.1:65533/pseudo);unicode-range:U+43-44}" ++
            "#generated::before{font-family:'Pseudo, Font';content:'C'}" ++
            "#generated::after{font-family:'Pseudo, Font';content:attr(data-letter)}" ++
            "</style><body><span style='font-family:STRASSE'>AB</span><i id=generated data-letter=D></i></body>",
        .{ .base_url = "about:blank" },
    );
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    dom.style.engine.resource_loading.updateRendering(document);
    const set = try interfaces.Document.get_fonts(document);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    try std.testing.expectEqual(@as(usize, 6), state.members.items.len);
    for ([_]bool{ false, true, true, false, false, true }, 0..) |loading, index| {
        try std.testing.expectEqual(loading, (try interfaces.FontFace.get_status(state.members.items[index].face.instance)) == ._loading_);
    }
    dom.document_fetches.abortAll(realm);
}

test "used fonts fold family names and select reverse composite ranges and generated text" {
    try fresh(usedCompositeAndGeneratedText);
}

fn namedEmojiAndFangsong() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        "<!doctype html><style>" ++
            "@font-face{font-family:'emoji';src:url(http://127.0.0.1:65533/named-emoji)}" ++
            "@font-face{font-family:'fangsong';src:url(http://127.0.0.1:65533/named-fangsong)}" ++
            "</style><body><span style='font-family:emoji'>A</span><span style='font-family:fangsong'>B</span></body>",
        .{ .base_url = "about:blank" },
    );
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    dom.style.engine.resource_loading.updateRendering(document);
    const set = try interfaces.Document.get_fonts(document);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    try std.testing.expectEqual(@as(usize, 2), state.members.items.len);
    // Q64/Q55: row119(e) owns the shared list correction. Q41's corrected
    // three-browser ruling makes emoji/fangsong ordinary named families.
    // Pin the exact current gap; the shared fix enables the target checks.
    const gap = dom.style.css.properties.isGenericFamily("emoji");
    try std.testing.expectEqual(gap, dom.style.css.properties.isGenericFamily("fangsong"));
    for (state.members.items) |member| {
        const actual = try interfaces.FontFace.get_status(member.face.instance);
        const expected: @TypeOf(actual) = if (gap) ._unloaded_ else ._loading_;
        try std.testing.expectEqual(expected, actual);
    }
    dom.document_fetches.abortAll(realm);
}

test "emoji and fangsong used families follow the shared row119 named-family correction" {
    try fresh(namedEmojiAndFangsong);
}

fn pendingStylesheet() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head></head><body></body>", .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(30);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript(
        \\globalThis.cr1FontOrder = []; globalThis.cr1ReadyDone = false;
        \\const cr1Link = document.createElement('link'); cr1Link.rel = 'stylesheet';
        \\cr1Link.href = 'data:text/css,body%7Bcolor:green%7D';
        \\cr1Link.onload = () => cr1FontOrder.push('sheet:' + cr1ReadyDone);
        \\document.head.append(cr1Link);
        \\document.fonts.ready.then(() => {cr1ReadyDone = true; cr1FontOrder.push('ready');});
        \\document
    );
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    try std.testing.expect(dom.style_sheet_owners.delaysLoadEvent(document));
    dom.style.engine.resource_loading.updateRendering(document);
    try std.testing.expect(!state.ready.fulfilled);
    _ = try browser.runEventLoopBlocking(120);
    try std.testing.expect(state.ready.fulfilled);
    const observed = try browser.evaluateScript("JSON.stringify(cr1FontOrder) === '[\"sheet:false\",\"ready\"]'");
    defer observed.release();
    try std.testing.expect(engine.toBoolean(realm, observed.borrow()));
}

test "font ready waits for stylesheet load events and the subsequent resource turn" {
    try fresh(pendingStylesheet);
}

fn absentFontSet() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = try interfaces.Document.initWith(std.testing.allocator, realm, .{ .ready_state = ._loading_ });
    const generation = runtime.SlabAllocator.generationOf(document);
    defer document.releaseIfUnwrapped(generation);
    const style = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
    const Registry = runtime.InstanceRegistry(.font_face_set, dom.style.engine.resource_loading.font_loading.Set);
    const scope = runtime.BrowserScope.ofInstance(document);
    try std.testing.expectEqual(@as(usize, 0), Registry.count(scope));
    try std.testing.expect(style.resourceState() == null);
    dom.document_lifecycle.finishWithoutParser(document);
    _ = try browser.runEventLoopBlocking(30);
    try std.testing.expectEqual(._complete_, try interfaces.Document.get_readyState(document));
    // No font registry, promise, member vector or resource Rare allocation
    // accompanies readiness when no caller has requested document.fonts.
    try std.testing.expectEqual(@as(usize, 0), Registry.count(scope));
    try std.testing.expect(scope.existingTable(.font_face_set, Registry.Table) == null);
    try std.testing.expect(style.resourceState() == null);
}

test "document readiness without a font set allocates no font or resource state" {
    try fresh(absentFontSet);
}

fn cssConnectedFaces() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head><style id=fonts>@font-face {font-family: Connected; src: url(http://127.0.0.1:65533/face.woff2); font-weight: 400}</style></head><body></body>", .{ .base_url = "about:blank" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    const face = state.members.items[0].face.instance;
    // The caller keeps the old face while the stylesheet stops owning it.
    const held = try engine.retainValue(realm, .{ .instance = face });
    defer held.release();
    try std.testing.expect(!try interfaces.FontFaceSet.call_delete(set, face));
    try interfaces.FontFaceSet.call_clear(set);
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    const edited = try browser.evaluateScript("document.getElementById('fonts').sheet.cssRules[0].style.fontWeight = '600'; true");
    edited.release();
    var weight = try interfaces.FontFace.get_weight(face);
    defer weight.deinit(realm.allocator);
    try std.testing.expectEqualStrings("600", weight.asSlice());
    try interfaces.FontFace.set_weight(face, .initInterned("700"));
    const reflected = try browser.evaluateScript("document.getElementById('fonts').sheet.cssRules[0].style.fontWeight === '700'");
    defer reflected.release();
    try std.testing.expect(engine.toBoolean(realm, reflected.borrow()));
    const removed = try browser.evaluateScript("const cr1Style = document.getElementById('fonts'); cr1Style.remove(); document.head.append(cr1Style); true");
    removed.release();
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    try std.testing.expect(state.members.items[0].face.instance != face);
    // Reinsertion cannot restore the old face's CSS connection.
    _ = try interfaces.FontFaceSet.call_add(set, face);
    try std.testing.expectEqual(@as(u32, 2), try interfaces.FontFaceSet.get_size(set));
    try std.testing.expect(state.members.items[1].face.instance == face);
    try std.testing.expect(try interfaces.FontFaceSet.call_delete(set, face));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "CSS-connected font descriptors reflect both ways and reconnection creates a new face" {
    try fresh(cssConnectedFaces);
}

fn replacingCssSource() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head><style id=fonts>@font-face {font-family: Original; src: url(old.woff2); font-weight: 500}</style></head><body></body>", .{ .base_url = "http://127.0.0.1:65533/" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    const old_face = state.members.items[0].face.instance;
    const held = try engine.retainValue(realm, .{ .instance = old_face });
    defer held.release();
    const changed = try browser.evaluateScript("const cr1Rule = document.getElementById('fonts').sheet.cssRules[0]; cr1Rule.style.src = 'url(new.woff2)'; cr1Rule.style.fontWeight = '900'; true");
    changed.release();
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    try std.testing.expect(state.members.items[0].face.instance != old_face);
    var previous = try interfaces.FontFace.get_weight(old_face);
    defer previous.deinit(realm.allocator);
    try std.testing.expectEqualStrings("500", previous.asSlice());
    var current = try interfaces.FontFace.get_weight(state.members.items[0].face.instance);
    defer current.deinit(realm.allocator);
    try std.testing.expectEqualStrings("900", current.asSlice());
    _ = try interfaces.FontFaceSet.call_add(set, old_face);
    try std.testing.expect(try interfaces.FontFaceSet.call_delete(set, old_face));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "a CSS src edit creates a new face and leaves the disconnected face's descriptors intact" {
    try fresh(replacingCssSource);
}

fn readoptedFontSheet() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript(
        \\globalThis.cr1AdoptedFontSheet = new CSSStyleSheet();
        \\cr1AdoptedFontSheet.replaceSync('@font-face {font-family: Adopted; src: local(Adopted); font-weight: 500}');
        \\document.adoptedStyleSheets = [cr1AdoptedFontSheet];
        \\document
    );
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    const old_face = state.members.items[0].face.instance;
    const held = try engine.retainValue(realm, .{ .instance = old_face });
    defer held.release();
    const kept = try browser.evaluateScript(
        \\document.adoptedStyleSheets = [cr1AdoptedFontSheet, cr1AdoptedFontSheet];
        \\document.adoptedStyleSheets = [cr1AdoptedFontSheet];
        \\const cr1FontHost = document.createElement('div'); document.body.append(cr1FontHost);
        \\const cr1FontShadow = cr1FontHost.attachShadow({mode:'open'});
        \\cr1FontShadow.adoptedStyleSheets = [cr1AdoptedFontSheet];
        \\cr1FontShadow.adoptedStyleSheets = [];
        \\true
    );
    kept.release();
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    try std.testing.expect(state.members.items[0].face.instance == old_face);
    const readopted = try browser.evaluateScript(
        \\document.adoptedStyleSheets = [];
        \\document.adoptedStyleSheets = [cr1AdoptedFontSheet];
        \\cr1AdoptedFontSheet.cssRules[0].style.fontWeight = '900';
        \\true
    );
    readopted.release();
    try std.testing.expectEqual(@as(u32, 1), try interfaces.FontFaceSet.get_size(set));
    try std.testing.expect(state.members.items[0].face.instance != old_face);
    var previous = try interfaces.FontFace.get_weight(old_face);
    defer previous.deinit(realm.allocator);
    try std.testing.expectEqualStrings("500", previous.asSlice());
    var current = try interfaces.FontFace.get_weight(state.members.items[0].face.instance);
    defer current.deinit(realm.allocator);
    try std.testing.expectEqualStrings("900", current.asSlice());
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "unadopting and readopting a font sheet creates a new face without severing retained or shadow adoptions" {
    try fresh(readoptedFontSheet);
}

fn connectedDescriptorAllocations() !void {
    const fonts = dom.style.engine.resource_loading.font_loading;
    if (comptime !@hasDecl(fonts.Face, "connect")) return error.MissingFontConnection;
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const first = try interfaces.FontFace.init(std.testing.allocator, realm);
    const first_generation = runtime.SlabAllocator.generationOf(first);
    defer first.releaseIfUnwrapped(first_generation);
    const second = try interfaces.FontFace.init(std.testing.allocator, realm);
    const second_generation = runtime.SlabAllocator.generationOf(second);
    defer second.releaseIfUnwrapped(second_generation);
    const Exercise = struct {
        fn run(a: std.mem.Allocator, left: *runtime.Instance, right: *runtime.Instance, replace_text: bool) !void {
            const sheet = try dom.style.SheetRecord.create(a, "@font-face {font-family: Atomic; src: local(Atomic); font-weight: 400}", .{});
            defer sheet.unref();
            const rules = try sheet.rulesWith(.{ .allocator = a });
            const rule = rules.items[0];
            const one = dom.style.hooks.fontFaceOf(left) orelse return error.NoFaceState;
            const two = dom.style.hooks.fontFaceOf(right) orelse return error.NoFaceState;
            // Each trial owns all of its snapshots through the fail allocator;
            // the two registry blocks themselves survive between trials.
            one.allocator = a;
            defer {
                one.deinit();
                one.* = fonts.Face.init(left);
            }
            two.allocator = a;
            defer {
                two.deinit();
                two.* = fonts.Face.init(right);
            }
            try one.connect(rule);
            try two.connect(rule);
            if (replace_text) {
                rule.data.font_face.setCssText(.{ .allocator = a }, "font-family: Atomic; src: local(Atomic); font-weight: 600") catch |err| {
                    try unchanged(rule, one, two);
                    return err;
                };
            } else {
                _ = rule.data.font_face.setProperty(.{ .allocator = a }, "font-weight", "600", "") catch |err| {
                    try unchanged(rule, one, two);
                    return err;
                };
            }
            try std.testing.expectEqualStrings("600", fonts.descriptorValue(&rule.data.font_face.block, "font-weight"));
            try std.testing.expectEqualStrings("600", one.getDescriptor("font-weight"));
            try std.testing.expectEqualStrings("600", two.getDescriptor("font-weight"));
        }
        fn unchanged(rule: *dom.style.Rule, one: *fonts.Face, two: *fonts.Face) !void {
            try std.testing.expectEqualStrings("400", fonts.descriptorValue(&rule.data.font_face.block, "font-weight"));
            try std.testing.expectEqualStrings("400", one.getDescriptor("font-weight"));
            try std.testing.expectEqualStrings("400", two.getDescriptor("font-weight"));
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Exercise.run, .{ first, second, false });
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Exercise.run, .{ first, second, true });
}

test "connected descriptor edits are atomic for every allocation failure and release both face snapshots" {
    try fresh(connectedDescriptorAllocations);
}

fn trustedSetEvents() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(30);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    dom.style.engine.resource_loading.updateRendering(document);
    const listeners = try browser.evaluateScript(
        \\globalThis.cr1SetEvents = [];
        \\globalThis.cr1SetActualEvents = [];
        \\globalThis.cr1SetOrder = [];
        \\for (const type of ['loading', 'loadingdone', 'loadingerror'])
        \\  document.fonts.addEventListener(type, event => {
        \\    cr1SetOrder.push(type);
        \\    cr1SetActualEvents.push(event);
        \\    cr1SetEvents.push(type + ':' + (event === undefined ? 'undefined' : event.isTrusted));
        \\  });
        \\true
    );
    listeners.release();
    const face = try interfaces.FontFace.call_constructor(realm, .initInterned("Absent"), .{ .cssomstring = .initInterned("local(cr1-intentionally-missing-font)") }, .{ .was_passed = false, .value = undefined });
    const generation = runtime.SlabAllocator.generationOf(face);
    defer face.releaseIfUnwrapped(generation);
    _ = try interfaces.FontFaceSet.call_add(set, face);
    const loaded: engine.Owned = .{ .value = try interfaces.FontFace.call_load(face) };
    defer loaded.release();
    const second = try interfaces.FontFace.call_constructor(realm, .initInterned("Absent Second"), .{ .cssomstring = .initInterned("local(cr1-intentionally-missing-font-second)") }, .{ .was_passed = false, .value = undefined });
    const second_generation = runtime.SlabAllocator.generationOf(second);
    defer second.releaseIfUnwrapped(second_generation);
    _ = try interfaces.FontFaceSet.call_add(set, second);
    const second_loaded: engine.Owned = .{ .value = try interfaces.FontFace.call_load(second) };
    defer second_loaded.release();
    const ready_reaction = try browser.evaluateScript("document.fonts.ready.then(() => cr1SetOrder.push('ready')); true");
    ready_reaction.release();
    _ = try browser.runEventLoopBlocking(150);
    for (0..30) |_| {
        const complete = try browser.evaluateScript("cr1SetEvents.length === 3");
        const done = engine.toBoolean(realm, complete.borrow());
        complete.release();
        if (done) break;
        _ = try browser.runEventLoopBlocking(100);
    }
    const events = try browser.evaluateScript("JSON.stringify(cr1SetEvents)");
    defer events.release();
    const text = try engine.convertToDOMString(realm, events.borrow(), std.testing.allocator);
    defer std.testing.allocator.free(text);
    const order = try browser.evaluateScript("JSON.stringify(cr1SetOrder)");
    defer order.release();
    const order_text = try engine.convertToDOMString(realm, order.borrow(), std.testing.allocator);
    defer std.testing.allocator.free(order_text);
    try std.testing.expectEqualStrings("[\"loading\",\"ready\",\"loadingdone\",\"loadingerror\"]", order_text);

    const registered = try browser.evaluateScript("typeof FontFaceSetLoadEvent !== 'undefined'");
    defer registered.release();
    if (!engine.toBoolean(realm, registered.borrow())) {
        // Q40/Q55: interface_bindings.zig:58 currently skip-lists this
        // interface. Pin only that exact gap, never a missing dispatch or
        // wrong order. Registration automatically enables every target
        // assertion below: trusted event objects and frozen ordered faces.
        try std.testing.expectEqualStrings("[\"loading:undefined\",\"loadingdone:undefined\",\"loadingerror:undefined\"]", text);
        return;
    }
    try std.testing.expectEqualStrings("[\"loading:true\",\"loadingdone:true\",\"loadingerror:true\"]", text);
    const details = try browser.evaluateScript(
        \\cr1SetActualEvents.every((event, index) =>
        \\  event instanceof FontFaceSetLoadEvent &&
        \\  event.type === ['loading', 'loadingdone', 'loadingerror'][index] &&
        \\  Array.isArray(event.fontfaces) && Object.isFrozen(event.fontfaces) &&
        \\  event.fontfaces === event.fontfaces && event.fontfaces.length === (index === 2 ? 2 : 0))
    );
    defer details.release();
    try std.testing.expect(engine.toBoolean(realm, details.borrow()));
    const faces = try browser.evaluateScript("cr1SetActualEvents[2].fontfaces");
    defer faces.release();
    const members = try engine.convertToSequenceOfObjects(realm, faces.borrow(), std.testing.allocator);
    defer {
        for (members) |member| member.release();
        std.testing.allocator.free(members);
    }
    try std.testing.expectEqual(@as(usize, 2), members.len);
    try std.testing.expect(engine.convertToPlatformObject(realm, members[0].borrow()).? == face);
    try std.testing.expect(engine.convertToPlatformObject(realm, members[1].borrow()).? == second);
}

test "font set dispatches trusted loading done and error events in task order" {
    try fresh(trustedSetEvents);
}

fn controlFontText() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        "<!doctype html><style>" ++
            "@font-face{font-family:Control;src:url(http://127.0.0.1:65533/control-A);unicode-range:U+41}" ++
            "@font-face{font-family:Control;src:url(http://127.0.0.1:65533/control-B);unicode-range:U+42}" ++
            "@font-face{font-family:Control;src:url(http://127.0.0.1:65533/control-space);unicode-range:U+20}" ++
            "textarea{font-family:Control}</style><body><textarea id=t>A</textarea></body>",
        .{ .base_url = "about:blank" },
    );
    const mutation = try browser.evaluateScript("document.getElementById('t').value='B';");
    defer mutation.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    dom.style.engine.resource_loading.updateRendering(document);
    const set = try interfaces.Document.get_fonts(document);
    _ = try interfaces.FontFaceSet.get_size(set);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    try std.testing.expectEqual(@as(usize, 3), state.members.items.len);
    // Q62's three-browser agreement: raw/default child A is not rendered
    // after setting value B. U+0020 selects the control's line metrics.
    try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(state.members.items[0].face.instance));
    try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(state.members.items[1].face.instance));
    try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(state.members.items[2].face.instance));
    dom.document_fetches.abortAll(realm);
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "a textarea uses its current value and first available font, never stale child text" {
    try fresh(controlFontText);
}

fn controlUserEdits() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        "<!doctype html><style>" ++
            "@font-face{font-family:InputEdit;src:url(http://127.0.0.1:65533/input-edit);unicode-range:U+42}" ++
            "@font-face{font-family:AreaEdit;src:url(http://127.0.0.1:65533/area-edit);unicode-range:U+42}" ++
            "</style><body><input id=i value=A style='font-family:InputEdit'>" ++
            "<textarea id=t style='font-family:AreaEdit'>A</textarea></body>",
        .{ .base_url = "about:blank" },
    );
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    dom.style.engine.resource_loading.updateRendering(document);
    const set = try interfaces.Document.get_fonts(document);
    _ = try interfaces.FontFaceSet.get_size(set);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    const style = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
    const resources = style.resourceState() orelse return error.NoResourceState;
    dom.style.engine.resource_loading.updateRendering(document);
    for ([_][]const u8{ "i", "t" }, 0..) |id, index| {
        dom.style.engine.resource_loading.updateRendering(document);
        try std.testing.expect(!resources.pending);
        try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(state.members.items[index].face.instance));
        const element = (try interfaces.Document.call_getElementById(document, .initInterned(id))) orelse return error.NoControl;
        try std.testing.expect(try dom.form_controls.userEdit(element, .{ .text = "B", .selection_start = 1, .selection_end = 1 }));
        try std.testing.expect(resources.pending);
        // The native owner asks for a turn; it never starts the fetch itself.
        try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(state.members.items[index].face.instance));
        dom.style.engine.resource_loading.updateRendering(document);
        try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(state.members.items[index].face.instance));
    }
    dom.document_fetches.abortAll(realm);
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "input and textarea native user edits defer newly used font requests to rendering" {
    try fresh(controlUserEdits);
}

fn neverStyledControlsAfterReady() !void {
    for ([_][]const u8{ "input", "textarea" }) |tag| {
        const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML(
            "<!doctype html><style>" ++
                "@font-face{font-family:LateControl;src:url(http://127.0.0.1:65533/late-A);unicode-range:U+41}" ++
                "@font-face{font-family:LateControl;src:url(http://127.0.0.1:65533/late-B);unicode-range:U+42}" ++
                "input,textarea{font-family:LateControl}</style><body></body>",
            .{ .base_url = "about:blank" },
        );
        errdefer std.debug.print("style_font_set_state_test: neverStyledControlsAfterReady <{s}>\n", .{tag});
        try untilFontsReady(browser);
        const realm = browser.getRealm() orelse return error.NoRealm;
        const value = try browser.evaluateScript("document");
        defer value.release();
        const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
        const set = try interfaces.Document.get_fonts(document);
        _ = try interfaces.FontFaceSet.get_size(set);
        const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
        const ready: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
        defer ready.release();
        dom.style.engine.resource_loading.updateRendering(document);
        try std.testing.expect(state.ready.fulfilled);
        try std.testing.expectEqual(@as(usize, 2), state.members.items.len);
        const style = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
        const resources = style.resourceState() orelse return error.NoResourceState;
        try std.testing.expect(!resources.pending);

        const script = try std.fmt.allocPrint(std.testing.allocator, "document.body.appendChild(document.createElement('{s}'));", .{tag});
        defer std.testing.allocator.free(script);
        const element_value = try browser.evaluateScript(script);
        defer element_value.release();
        const element = engine.convertToPlatformObject(realm, element_value.borrow()) orelse return error.NoControl;
        try std.testing.expect(dom.style.element_style.existingOf(element) == null);
        // Insertion already schedules the first selection. A value write
        // before that selection must not lose its pending rendering turn.
        try std.testing.expect(resources.pending);
        if (std.mem.eql(u8, tag, "input")) {
            try interfaces.HTMLInputElement.set_value(element, .initInterned("B"));
        } else {
            try interfaces.HTMLTextAreaElement.set_value(element, .initInterned("B"));
        }
        try std.testing.expect(dom.style.element_style.existingOf(element) == null);
        try std.testing.expect(resources.pending);
        for (state.members.items) |member|
            try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(member.face.instance));

        // Q48's settled-ready flush performs CSS Fonts 4 §5.2 selection
        // using the current control value, even before its first render.
        const after: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
        defer after.release();
        try std.testing.expect(dom.style.element_style.existingOf(element) != null);
        try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(state.members.items[0].face.instance));
        try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(state.members.items[1].face.instance));
        dom.document_fetches.abortAll(realm);
        try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
    }
}

test "new controls keep their first font selection pending after a settled ready" {
    try fresh(neverStyledControlsAfterReady);
}

fn controlStyleLifetimes() !void {
    const Case = enum { inline_uncomputed, style_before_first_value, cloned, reset, retyped, detached_reconnected, adopted_reconnected, hidden_revealed };
    for ([_][]const u8{ "input", "textarea" }) |tag| {
        for (std.enums.values(Case)) |case| {
            if (case == .retyped and std.mem.eql(u8, tag, "textarea")) continue;
            const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.NoPage;
            try page.loadHTML(
                "<!doctype html><style>" ++
                    "@font-face{font-family:ControlLife;src:url(http://127.0.0.1:65533/control-life-B);unicode-range:U+42}" ++
                    "input,textarea{font-family:ControlLife}</style><body></body>",
                .{ .base_url = "about:blank" },
            );
            errdefer std.debug.print("style_font_set_state_test: controlStyleLifetimes <{s}> {s}\n", .{ tag, @tagName(case) });
            try untilFontsReady(browser);
            const realm = browser.getRealm() orelse return error.NoRealm;
            const value = try browser.evaluateScript("document");
            defer value.release();
            const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
            const set = try interfaces.Document.get_fonts(document);
            _ = try interfaces.FontFaceSet.get_size(set);
            const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
            const ready: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
            defer ready.release();
            dom.style.engine.resource_loading.updateRendering(document);
            try std.testing.expect(state.ready.fulfilled);
            try std.testing.expectEqual(@as(usize, 1), state.members.items.len);
            const face = state.members.items[0].face.instance;

            // defaultValue leaves a textarea's lazy raw-value state absent;
            // computing style before its first value write must still let
            // that later write invalidate used-font selection.
            const initial_value = if (case == .style_before_first_value) "defaultValue" else "value";
            const setup = switch (case) {
                .cloned => "getComputedStyle(cr1LateControl).fontFamily;" ++
                    "globalThis.cr1ControlSource=cr1LateControl;" ++
                    "cr1LateControl=cr1ControlSource.cloneNode(true);cr1ControlSource.remove();" ++
                    "document.body.append(cr1LateControl);",
                .reset => "cr1LateControl.defaultValue='B';",
                else => "",
            };
            const script = try std.fmt.allocPrint(std.testing.allocator, "globalThis.cr1LateControl=document.createElement('{s}');" ++
                "cr1LateControl.{s}='A';document.body.append(cr1LateControl);{s}cr1LateControl;", .{ tag, initial_value, setup });
            defer std.testing.allocator.free(script);
            const element_value = try browser.evaluateScript(script);
            defer element_value.release();
            const element = engine.convertToPlatformObject(realm, element_value.borrow()) orelse return error.NoControl;
            try std.testing.expect(dom.style.element_style.existingOf(element) == null);
            const preparation = try browser.evaluateScript(switch (case) {
                .inline_uncomputed => "cr1LateControl.style.fontFamily='ControlLife';",
                .hidden_revealed => "cr1LateControl.style.display='none';",
                .style_before_first_value, .cloned, .reset, .retyped, .detached_reconnected, .adopted_reconnected => "void 0;",
            });
            preparation.release();
            if (case == .inline_uncomputed) {
                const inline_state = dom.style.element_style.existingOf(element) orelse return error.NoInlineState;
                try std.testing.expect(inline_state.cached == null);
            } else {
                dom.style.engine.resource_loading.updateRendering(document);
                try std.testing.expect(state.ready.fulfilled);
                try std.testing.expect(dom.style.element_style.existingOf(element) != null);
                const detach = try browser.evaluateScript(switch (case) {
                    .detached_reconnected => "cr1LateControl.remove();",
                    .adopted_reconnected => "globalThis.cr1OtherDocument=document.implementation.createHTMLDocument('other');cr1OtherDocument.adoptNode(cr1LateControl);",
                    .style_before_first_value, .cloned, .reset, .hidden_revealed => "void 0;",
                    .retyped => "cr1LateControl.type='password';cr1LateControl.type='text';",
                    .inline_uncomputed => unreachable,
                });
                detach.release();
                if (case == .adopted_reconnected)
                    try std.testing.expect((try interfaces.Node.get_ownerDocument(element)) != document);
                if (case == .retyped) {
                    // Discharge the type attribute's own invalidation. The
                    // next font turn must come from the value write itself.
                    dom.style.engine.resource_loading.updateRendering(document);
                    const style = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
                    try std.testing.expect(!(style.resourceState() orelse return error.NoResourceState).pending);
                }
            }
            try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(face));
            if (case == .reset) {
                dom.form_controls.reset(element);
            } else if (std.mem.eql(u8, tag, "input")) {
                try interfaces.HTMLInputElement.set_value(element, .initInterned("B"));
            } else {
                try interfaces.HTMLTextAreaElement.set_value(element, .initInterned("B"));
            }
            try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(face));
            if (case == .detached_reconnected or case == .adopted_reconnected or case == .hidden_revealed) {
                // A detached or hidden control does not request its new font.
                // Adoption keeps the Element-owned style state alive too.
                dom.style.engine.resource_loading.updateRendering(document);
                try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(face));
                try std.testing.expect(dom.style.element_style.existingOf(element) != null);
                const reconnect = try browser.evaluateScript(switch (case) {
                    .detached_reconnected, .adopted_reconnected => "document.body.append(cr1LateControl);",
                    .hidden_revealed => "cr1LateControl.style.display='';",
                    .inline_uncomputed, .style_before_first_value, .cloned, .reset, .retyped => unreachable,
                });
                reconnect.release();
                try std.testing.expect((try interfaces.Node.get_ownerDocument(element)) == document);
            }
            // CSS Fonts 4 §5.2 selects B only once the current control text
            // participates again; reading settled ready performs that flush.
            const after: engine.Owned = .{ .value = try interfaces.FontFaceSet.get_ready(set) };
            defer after.release();
            try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(face));
            dom.document_fetches.abortAll(realm);
            try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
        }
    }
}

test "control font selection preserves first-write, clone, reset, type and style lifetimes" {
    try fresh(controlStyleLifetimes);
}
