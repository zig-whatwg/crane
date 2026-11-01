//! Font Loading3 §3.2 and WebIDL current-realm results (row131 Q45–Q50).
//! Engine-source observations belong in native tests until browser probing.
const std = @import("std");
const Browser = @import("browser").Browser;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");
const a = std.testing.allocator;

fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    std.debug.print("FM1 realm fixture script error in {s}: {s}\n", .{ info.filename, info.message });
}

fn fresh(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            body() catch |err| {
                if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

fn text(browser: *Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, a);
}

fn expectScript(browser: *Browser, source: []const u8, expected: []const u8) !void {
    const actual = try text(browser, source);
    defer a.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

fn waitFor(browser: *Browser, predicate: []const u8) !void {
    for (0..200) |_| {
        const actual = try text(browser, predicate);
        const ready = std.mem.eql(u8, actual, "true");
        a.free(actual);
        if (ready) return;
        _ = try browser.runEventLoopBlocking(5);
    }
    return error.ForeignFontResultNeverSettled;
}

fn openFrame() !*Browser {
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions("https://fm1-realm.test/", .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = "https://fm1-realm.test/" });
    try expectScript(browser,
        \\globalThis.fm1FrameReady = false;
        \\globalThis.fm1Frame = document.createElement('iframe');
        \\fm1Frame.onload = () => { fm1FrameReady = true; };
        \\fm1Frame.srcdoc = '<!doctype html><body>';
        \\document.body.append(fm1Frame);
        \\'setup'
    , "setup");
    try waitFor(browser, "fm1FrameReady");
    return browser;
}

fn documentFonts(browser: *Browser) !*runtime.Instance {
    const page = browser.current_context orelse return error.NoPage;
    return interfaces.Document.get_fonts(page.document_instance orelse return error.NoDocument);
}

fn frameRealm(browser: *Browser, realm: runtime.Context) !runtime.Context {
    const value = try browser.evaluateScript("fm1Frame.contentDocument");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoFrameDocument;
    return document.ctx;
}

fn makeFace(realm: runtime.Context, family: []const u8, source: []const u8) !*runtime.Instance {
    return interfaces.FontFace.call_constructor(realm, .initInterned(family), .{ .cssomstring = .initInterned(source) }, .{ .was_passed = false, .value = undefined });
}

fn parentStillWorks(browser: *Browser, realm: runtime.Context) !void {
    try expectScript(browser,
        \\globalThis.fm1ParentWorked = false;
        \\document.fonts.load('16px FM1NoSuchParentFamily').then(v => {
        \\  fm1ParentWorked = v.length === 0 && Object.getPrototypeOf(v) === Array.prototype;
        \\});
        \\'started'
    , "started");
    try engine.performMicrotaskCheckpoint(realm.agent orelse return error.NoAgent);
    try expectScript(browser, "fm1ParentWorked", "true");
}

fn crossRealmResults() !void {
    const browser = try openFrame();
    defer browser.deinit();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const set = try documentFonts(browser);
    const item = try makeFace(realm, "FM1NativeRealm", "url(unused.woff2)");
    const generation = runtime.SlabAllocator.generationOf(item);
    defer item.releaseIfUnwrapped(generation);
    const face_root = try engine.retainValue(realm, .{ .instance = item });
    defer face_root.release();
    {
        const global = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis" }, "fm1-owner-face.js", null, .{ .report = report });
        defer global.release();
        try engine.setProperty(realm, global.value, "fm1OwnerFace", .{ .instance = item });
    }
    const face = dom.style.hooks.fontFaceOf(item) orelse return error.NoFace;
    // Q17's native fixture controls completion, with no fetch or decoder.
    face.status = .loading;
    _ = try interfaces.FontFaceSet.call_add(set, item);
    try expectScript(browser,
        \\globalThis.fm1Empty = false;
        \\globalThis.fm1Syntax = false;
        \\globalThis.fm1Loaded = false;
        \\globalThis.fm1Failure = '';
        \\(() => {
        \\  const foreign = fm1Frame.contentWindow;
        \\  const load = foreign.FontFaceSet.prototype.load;
        \\  const ownerFace = fm1OwnerFace;
        \\  if (ownerFace.family !== 'FM1NativeRealm') throw new Error('Wrong owner face');
        \\  const empty = load.call(document.fonts, '16px FM1NoSuchRealmFamily');
        \\  const syntax = load.call(document.fonts, 'inherit');
        \\  const pending = load.call(document.fonts, '16px FM1NativeRealm', 'A');
        \\  empty.then(v => { fm1Empty = Object.getPrototypeOf(v) === foreign.Array.prototype && v.length === 0; }, e => { fm1Failure = e.name; });
        \\  syntax.then(() => { fm1Failure = 'SyntaxResolved'; }, e => { fm1Syntax = e.name === 'SyntaxError' && Object.getPrototypeOf(e) === foreign.DOMException.prototype; });
        \\  pending.then(v => { fm1Loaded = Object.getPrototypeOf(v) === foreign.Array.prototype && v.length === 1 && v[0] === ownerFace && Object.getPrototypeOf(v[0]) === FontFace.prototype; }, e => { fm1Failure = e.name; });
        \\  return [empty, syntax, pending].every(p => Object.getPrototypeOf(p) === foreign.Promise.prototype) ? 'ok' : 'WrongPromiseRealm';
        \\})()
    , "ok");
    face.status = .loaded;
    const loaded = try face.loadedPromise();
    defer loaded.release();
    try waitFor(browser, "fm1Empty && fm1Syntax && fm1Loaded");
    try expectScript(browser, "fm1Failure", "");
}

test "font set load creates borrowed-operation results in that operation's realm" {
    try fresh(crossRealmResults);
}

fn retiredResultRealm() !void {
    const browser = try openFrame();
    defer browser.deinit();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const foreign = try frameRealm(browser, realm);
    const set = try documentFonts(browser);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoSet;
    const item = try makeFace(realm, "FM1RetiredResult", "url(unused.woff2)");
    const generation = runtime.SlabAllocator.generationOf(item);
    defer item.releaseIfUnwrapped(generation);
    const root = try engine.retainValue(realm, .{ .instance = item });
    defer root.release();
    const face = dom.style.hooks.fontFaceOf(item) orelse return error.NoFace;
    face.status = .loading;
    _ = try interfaces.FontFaceSet.call_add(set, item);
    try expectScript(browser,
        \\globalThis.fm1RetiredOutcome = 'pending';
        \\globalThis.fm1RetiredPending = fm1Frame.contentWindow.FontFaceSet.prototype.load.call(document.fonts, '16px FM1RetiredResult', 'A');
        \\fm1RetiredPending.then(() => { fm1RetiredOutcome = 'fulfilled'; }, () => { fm1RetiredOutcome = 'rejected'; });
        \\'started'
    , "started");
    try std.testing.expectEqual(@as(usize, 1), state.pending_loads.items.len);
    try expectScript(browser, "fm1Frame.remove(); 'removed'", "removed");
    _ = try browser.runEventLoopBlocking(20);
    // Q50 / selection_range_realm_end_test: removal first detaches. The
    // result promise keeps that realm; this native end models page teardown.
    try std.testing.expect(foreign.hasEngine());
    try std.testing.expectEqual(@as(usize, 1), state.pending_loads.items.len);
    engine.destroyWindowRealm(foreign, .navigable_destroyed);
    try std.testing.expect(!foreign.hasEngine());
    try std.testing.expect(realm.hasEngine());
    face.status = .loaded;
    const loaded = try face.loadedPromise();
    defer loaded.release();
    try engine.performMicrotaskCheckpoint(realm.agent orelse return error.NoAgent);
    try std.testing.expectEqual(@as(usize, 0), state.pending_loads.items.len);
    try expectScript(browser, "fm1RetiredOutcome", "pending");
    try parentStillWorks(browser, realm);
    // Detached record + pending result + working owner pin abandonment.
    // Debug ownership and the in-process leaks gate cover exact-once handles.
}

test "font set load abandons a retired result realm while its parent owner survives" {
    try fresh(retiredResultRealm);
}

const RetireLaterFace = struct {
    parent: runtime.Context,
    foreign: runtime.Context,
    calls: usize = 0,
    retired: bool = false,
    parent_live: bool = false,

    fn steps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *@This() = @ptrCast(@alignCast(data.?));
        self.calls += 1;
        // Q50: the iframe was removed and its detach task already ran.
        // This ends only the later face's realm during the earlier resolve.
        engine.destroyWindowRealm(self.foreign, .navigable_destroyed);
        self.retired = !self.foreign.hasEngine();
        self.parent_live = self.parent.hasEngine();
        return .undefined;
    }
};

fn retiredLaterFace() !void {
    const browser = try openFrame();
    defer browser.deinit();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const foreign = try frameRealm(browser, realm);
    // Q58: keep the detached realm without a face that document discard
    // would retire before this test's synchronous recheck can see it.
    const foreign_keep = try browser.evaluateScript("fm1Frame.contentWindow.FontFace");
    defer foreign_keep.release();
    const set = try documentFonts(browser);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoSet;
    const first = try makeFace(realm, "FM1FirstBeforeRetirement", "url(unused.woff2)");
    const first_generation = runtime.SlabAllocator.generationOf(first);
    defer first.releaseIfUnwrapped(first_generation);
    const first_root = try engine.retainValue(realm, .{ .instance = first });
    defer first_root.release();
    {
        const global = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis" }, "fm1-first-face.js", null, .{ .report = report });
        defer global.release();
        try engine.setProperty(realm, global.value, "fm1FirstFace", .{ .instance = first });
    }
    const first_state = dom.style.hooks.fontFaceOf(first) orelse return error.NoFace;
    first_state.status = .loaded;
    _ = try interfaces.FontFaceSet.call_add(set, first);
    try expectScript(browser, "fm1Frame.remove(); 'removed'", "removed");
    _ = try browser.runEventLoopBlocking(20);
    try std.testing.expect(foreign.hasEngine());
    const second = try makeFace(foreign, "FM1ForeignRetirement", "url(unused.woff2)");
    const second_generation = runtime.SlabAllocator.generationOf(second);
    defer if (foreign.hasEngine()) second.releaseIfUnwrapped(second_generation);
    const second_root = try engine.retainValue(realm, .{ .instance = second });
    defer second_root.release();
    const second_state = dom.style.hooks.fontFaceOf(second) orelse return error.NoFace;
    try std.testing.expect(!second_state.retired);
    try std.testing.expect(second.ctx == foreign);
    second_state.status = .loading;
    _ = try interfaces.FontFaceSet.call_add(set, second);
    const third = try makeFace(realm, "FM1LiveAfterRetirement", "local(FM1UnavailableLocal)");
    const third_generation = runtime.SlabAllocator.generationOf(third);
    defer third.releaseIfUnwrapped(third_generation);
    const third_root = try engine.retainValue(realm, .{ .instance = third });
    defer third_root.release();
    const third_state = dom.style.hooks.fontFaceOf(third) orelse return error.NoFace;
    _ = try interfaces.FontFaceSet.call_add(set, third);
    try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(third));
    var probe: RetireLaterFace = .{ .parent = realm, .foreign = foreign };
    const callback: engine.BuiltinFunction = .{ .steps = RetireLaterFace.steps, .data = &probe };
    try engine.defineBuiltinFunction(realm, "fm1RetireLaterFace", 0, &callback);
    try expectScript(browser,
        \\globalThis.fm1ForeignOutcome = 'pending';
        \\(() => {
        \\  const first = fm1FirstFace;
        \\  if (first.family !== 'FM1FirstBeforeRetirement') throw new Error('Wrong first face');
        \\  Object.defineProperty(first, 'then', { get() { fm1RetireLaterFace(); return undefined; } });
        \\  globalThis.fm1ForeignPending = document.fonts.load('16px FM1FirstBeforeRetirement, FM1ForeignRetirement, FM1LiveAfterRetirement', 'A');
        \\  fm1ForeignPending.then(() => { fm1ForeignOutcome = 'fulfilled'; }, () => { fm1ForeignOutcome = 'rejected'; });
        \\  return 'started';
        \\})()
    , "started");
    try std.testing.expectEqual(@as(usize, 1), probe.calls);
    try std.testing.expect(probe.retired and probe.parent_live);
    try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(third));
    try std.testing.expectEqual(@as(usize, 0), state.pending_loads.items.len);
    const third_promise = try third_state.loadedPromise();
    defer third_promise.release();
    if (comptime engine.capabilities.promise_rejection_tracking != .unsupported)
        try std.testing.expect(engine.promiseIsHandled(realm, third_promise.borrow()));
    // Q48: the live face's stored promise is still consumed by wait-for-all,
    // even though the outer operation abandoned before attaching reactions.
    try third_state.reject(.network);
    try engine.performMicrotaskCheckpoint(realm.agent orelse return error.NoAgent);
    if (comptime engine.capabilities.promise_rejection_tracking != .unsupported)
        try std.testing.expect(engine.promiseIsHandled(realm, third_promise.borrow()));
    try expectScript(browser, "fm1ForeignOutcome", "pending");
    try parentStillWorks(browser, realm);
}

test "font set load skips an ended foreign face and still starts and handles later live faces" {
    try fresh(retiredLaterFace);
}
