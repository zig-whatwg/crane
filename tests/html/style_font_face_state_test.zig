//! Font Loading 3 constructor, promise identity, setters and allocator lifetime.
const std = @import("std");
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");

fn fresh(comptime exercise: fn () anyerror!void) !void {
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

fn descriptors() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const face = try interfaces.FontFace.call_constructor(realm, .initInterned("Crane Font"), .{ .cssomstring = .initInterned("url(face.woff2)") }, .{
        .was_passed = true,
        .value = .{ .weight = .initInterned("300 700"), .unicodeRange = .initInterned("u+0041-005a") },
    });
    const generation = runtime.SlabAllocator.generationOf(face);
    defer face.releaseIfUnwrapped(generation);
    try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(face));
    var weight = try interfaces.FontFace.get_weight(face);
    defer weight.deinit(realm.allocator);
    try std.testing.expectEqualStrings("300 700", weight.asSlice());
    var ranges = try interfaces.FontFace.get_unicodeRange(face);
    defer ranges.deinit(realm.allocator);
    try std.testing.expectEqualStrings("U+41-5A", ranges.asSlice());
    try std.testing.expectError(error.SyntaxError, interfaces.FontFace.set_weight(face, .initInterned("bolder")));
    try interfaces.FontFace.set_weight(face, .initInterned("400"));
    var changed = try interfaces.FontFace.get_weight(face);
    defer changed.deinit(realm.allocator);
    try std.testing.expectEqualStrings("400", changed.asSlice());
    const promise: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(face) };
    defer promise.release();
    const again: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(face) };
    defer again.release();
    try std.testing.expect(engine.sameValue(realm, promise.borrow(), again.borrow()));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "FontFace validates descriptors without fetching and keeps one pending promise" {
    try fresh(descriptors);
}

fn invalidStyleInitial() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    // Integrator fontstyle probe: all three browsers return the initial
    // style for an invalid constructor descriptor, without throwing.
    const face = try interfaces.FontFace.call_constructor(realm, .initInterned("Invalid Style"), .{ .cssomstring = .initInterned("url(face.woff2)") }, .{
        .was_passed = true,
        .value = .{ .style = .initInterned("left") },
    });
    const generation = runtime.SlabAllocator.generationOf(face);
    defer face.releaseIfUnwrapped(generation);
    var style = try interfaces.FontFace.get_style(face);
    defer style.deinit(realm.allocator);
    try std.testing.expectEqualStrings("normal", style.asSlice());
    // This descriptor read-back ruling does not alter rejection/status.
    try std.testing.expectEqual(._error_, try interfaces.FontFace.get_status(face));
    const promise: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(face) };
    defer promise.release();
    const loaded: engine.Owned = .{ .value = try interfaces.FontFace.call_load(face) };
    defer loaded.release();
    try std.testing.expect(engine.sameValue(realm, promise.borrow(), loaded.borrow()));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
    try std.testing.expectError(error.SyntaxError, interfaces.FontFace.set_style(face, .initInterned("right")));
}

test "FontFace invalid constructor style retains its initial read-back and rejects loaded" {
    try fresh(invalidStyleInitial);
}

fn invalidSource() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const face = try interfaces.FontFace.call_constructor(realm, .initInterned("Crane Font"), .{ .cssomstring = .initInterned("not-a-src-descriptor") }, .{ .was_passed = false, .value = undefined });
    const generation = runtime.SlabAllocator.generationOf(face);
    defer face.releaseIfUnwrapped(generation);
    try std.testing.expectEqual(._error_, try interfaces.FontFace.get_status(face));
    const promise: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(face) };
    defer promise.release();
    const loaded: engine.Owned = .{ .value = try interfaces.FontFace.call_load(face) };
    defer loaded.release();
    try std.testing.expect(engine.sameValue(realm, promise.borrow(), loaded.borrow()));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "FontFace invalid source rejects the same promise without a fetch" {
    try fresh(invalidSource);
}

fn workerExclusion() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const saved = realm.realm_info;
    defer realm.realm_info = saved;
    // Both contexts reach this BrowserScope. The worker-exposed constructor
    // must leave the window-thread side table untouched (liaison Q16).
    realm.realm_info = .{ .context_type = .dedicated_worker };
    const face = try interfaces.FontFace.call_constructor(realm, .initInterned("Worker Face"), .{ .cssomstring = .initInterned("url(worker.woff2)") }, .{ .was_passed = false, .value = undefined });
    const generation = runtime.SlabAllocator.generationOf(face);
    defer face.releaseIfUnwrapped(generation);
    const Registry = runtime.InstanceRegistry(.font_face, dom.style.engine.resource_loading.font_loading.Face);
    try std.testing.expectEqual(@as(usize, 0), Registry.count(runtime.BrowserScope.ofInstance(face)));
    try std.testing.expect(face.getState(interfaces.FontFace.State).own._internal == null);
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "worker FontFace never registers in the window-thread table" {
    try fresh(workerExclusion);
}

fn explicitFontCancellation() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const face = try interfaces.FontFace.call_constructor(realm, .initInterned("Abort Font"), .{ .cssomstring = .initInterned("url(http://127.0.0.1:65533/abort.woff2)") }, .{ .was_passed = false, .value = undefined });
    const generation = runtime.SlabAllocator.generationOf(face);
    defer face.releaseIfUnwrapped(generation);
    const promise: engine.Owned = .{ .value = try interfaces.FontFace.call_load(face) };
    defer promise.release();
    try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(face));
    const internal = dom.style.hooks.fontFaceOf(face) orelse return error.NoFontState;
    try std.testing.expect(internal.loaded.capability != null);
    dom.document_fetches.abortAll(realm);
    try std.testing.expect(internal.loaded.capability == null);
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
    const again: engine.Owned = .{ .value = try interfaces.FontFace.get_loaded(face) };
    defer again.release();
    try std.testing.expect(engine.sameValue(realm, promise.borrow(), again.borrow()));
}

test "font realm discard releases pending capability and activity without changing promise identity" {
    try fresh(explicitFontCancellation);
}

const SharingCase = enum { same_source, different_metadata, cancel_one, document_abort, realm_discard, document_abort_cache_first, realm_discard_cache_first, request_metadata };

fn sharedFontRequests(comptime scenario: SharingCase) !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const first = try interfaces.FontFace.call_constructor(realm, .initInterned("Shared First"), .{ .cssomstring = .initInterned("url(http://127.0.0.1:65533/cr1-shared.woff2)") }, .{ .was_passed = false, .value = undefined });
    const first_generation = runtime.SlabAllocator.generationOf(first);
    defer first.releaseIfUnwrapped(first_generation);
    const second = try interfaces.FontFace.call_constructor(realm, .initInterned("Shared Second"), .{ .cssomstring = .initInterned("url(http://127.0.0.1:65533/cr1-shared.woff2)") }, .{ .was_passed = false, .value = undefined });
    const second_generation = runtime.SlabAllocator.generationOf(second);
    defer second.releaseIfUnwrapped(second_generation);
    if (scenario == .different_metadata) {
        const source = try dom.style.css.style_values.ResourceSource.create(std.testing.allocator, .{
            .base_url = "https://sheet.example/style.css",
            .referrer = "https://sheet.example/style.css",
            .referrer_policy = "origin",
        });
        defer source.unref();
        const face = dom.style.hooks.fontFaceOf(second) orelse return error.NoFaceState;
        _ = try face.descriptors.setProperty(.{ .allocator = std.testing.allocator, .resource_source = source }, "src", "url(http://127.0.0.1:65533/cr1-shared.woff2)", "");
    }
    const one: engine.Owned = .{ .value = try interfaces.FontFace.call_load(first) };
    defer one.release();
    const two: engine.Owned = .{ .value = try interfaces.FontFace.call_load(second) };
    defer two.release();
    // Create wrappers, then drop these native roots. Only each load's own
    // pending activity keeps its face through the collection below.
    const first_wrapper = try engine.retainValue(realm, .{ .instance = first });
    const second_wrapper = try engine.retainValue(realm, .{ .instance = second });
    const abort_document = scenario == .document_abort or scenario == .document_abort_cache_first;
    const cache_first = scenario == .document_abort_cache_first or scenario == .realm_discard_cache_first;
    const keep_for_abort = abort_document or scenario == .realm_discard or scenario == .realm_discard_cache_first;
    if (!keep_for_abort) {
        first_wrapper.release();
        second_wrapper.release();
    }
    defer if (keep_for_abort) {
        first_wrapper.release();
        second_wrapper.release();
    };
    // Two native face tasks initiate requests before an I/O pump. A probe
    // queued behind them observes the actual shared fetch count.
    const Probe = struct {
        browser: *browser_mod.Browser,
        first: *runtime.Instance,
        second: *runtime.Instance,
        count: ?usize = null,
        after_cancel: ?usize = null,
        clients_released: bool = false,
        font_request_options: bool = false,
        url_credentials: ?bool = null,
        fn run(context: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context orelse return));
            self.count = self.browser.agent_host.fetches.inFlight();
            if (scenario == .request_metadata) {
                const face = dom.style.hooks.fontFaceOf(self.first) orelse return;
                const load = face.load orelse return;
                const resource = load.resource orelse return;
                const handle = resource.handle orelse return;
                const request = handle.job.request;
                self.font_request_options = request.destination == .font and request.mode == .cors and request.credentials_mode == .same_origin;
                self.url_credentials = request.use_url_credentials;
            }
            if (scenario == .cancel_one) {
                const face = dom.style.hooks.fontFaceOf(self.first) orelse return;
                face.discard();
                self.after_cancel = self.browser.agent_host.fetches.inFlight();
                engine.requestGarbageCollection(self.browser.agent orelse return);
            }
            if (keep_for_abort) {
                const first_face = dom.style.hooks.fontFaceOf(self.first) orelse return;
                const second_face = dom.style.hooks.fontFaceOf(self.second) orelse return;
                const first_load = first_face.load orelse return;
                const second_load = second_face.load orelse return;
                if (cache_first) {
                    const style = dom.style.hooks.engineOf(first_load.document orelse return) orelse return;
                    const resources = style.resourceState() orelse return;
                    const cache = resources.fonts orelse return;
                    _ = cache.markAbort();
                    cache.abortMarked();
                }
                if (abort_document) {
                    _ = dom.document_fetches.abort(first_load.document orelse return);
                } else {
                    dom.document_fetches.abortAll(self.first.ctx);
                }
                self.after_cancel = self.browser.agent_host.fetches.inFlight();
                self.clients_released = !first_load.kept and !second_load.kept;
            }
        }
    };
    var probe: Probe = .{ .browser = browser, .first = first, .second = second };
    const loop = realm.getOptionalEventLoop() orelse return error.NoEventLoop;
    loop.queueTask(.{ .callback = Probe.run, .context = &probe });
    _ = try browser.runEventLoopBlocking(100);
    // chat shares CPU with other builds. Bound completion, without making
    // network failure depend on fitting every queued turn into one 100ms run.
    if (!keep_for_abort) for (0..30) |_| {
        if (try interfaces.FontFace.get_status(second) != ._loading_) break;
        _ = try browser.runEventLoopBlocking(100);
    };
    try std.testing.expectEqual(@as(?usize, if (scenario == .different_metadata) 2 else 1), probe.count);
    if (scenario == .request_metadata) {
        try std.testing.expect(probe.font_request_options);
        try std.testing.expectEqual(@as(?bool, true), probe.url_credentials);
    }
    if (keep_for_abort) {
        try std.testing.expectEqual(@as(?usize, 0), probe.after_cancel);
        try std.testing.expect(probe.clients_released);
        return;
    }
    if (scenario == .cancel_one) {
        try std.testing.expectEqual(@as(?usize, 1), probe.after_cancel);
    } else {
        try std.testing.expectEqual(._error_, try interfaces.FontFace.get_status(first));
    }
    try std.testing.expectEqual(._error_, try interfaces.FontFace.get_status(second));
}

fn sharedFontRequest() !void {
    try sharedFontRequests(.same_source);
}

test "distinct font faces share one document-owned resource request" {
    try fresh(sharedFontRequest);
}

test "font resources with different request provenance never alias" {
    try fresh(struct {
        fn run() !void {
            try sharedFontRequests(.different_metadata);
        }
    }.run);
}

test "cancelling one shared font client leaves the other loading through collection" {
    try fresh(struct {
        fn run() !void {
            try sharedFontRequests(.cancel_one);
        }
    }.run);
}

test "document abort terminates the shared font request and releases both clients" {
    try fresh(struct {
        fn run() !void {
            try sharedFontRequests(.document_abort);
            try sharedFontRequests(.document_abort_cache_first);
        }
    }.run);
}

test "realm discard terminates the shared font request and releases both clients" {
    try fresh(struct {
        fn run() !void {
            try sharedFontRequests(.realm_discard);
            try sharedFontRequests(.realm_discard_cache_first);
        }
    }.run);
}

test "font requests set the CSS Values CORS credentials and URL credentials flag" {
    // CSS Fonts 4 §4.8.2 invokes CSS Values 4 §4.5.4, step 3. Inspect
    // the actual in-flight Fetch request before network pumping, including
    // the flag HTTP authentication uses to retry URL-provided credentials.
    try fresh(struct {
        fn run() !void {
            try sharedFontRequests(.request_metadata);
        }
    }.run);
}
