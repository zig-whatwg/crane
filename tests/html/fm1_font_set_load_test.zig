//! Font Loading 3 §3.2: ordered results and pending-load ownership.
const std = @import("std");
const Browser = @import("browser").Browser;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");
const a = std.testing.allocator;

const Observation = struct {
    realm: runtime.Context,
    outcome: enum { pending, fulfilled, rejected, dropped } = .pending,
    value: ?engine.Owned = null,
    failure: ?anyerror = null,

    fn deinit(self: *Observation) void {
        if (self.value) |value| value.release();
        self.value = null;
    }
    fn capture(self: *Observation, value: runtime.JSValue) void {
        self.value = engine.retainValue(self.realm, value) catch |err| {
            self.failure = err;
            return;
        };
    }
    fn fulfilled(data: ?*anyopaque, value: runtime.JSValue) void {
        const self: *Observation = @ptrCast(@alignCast(data.?));
        self.outcome = .fulfilled;
        self.capture(value);
    }
    fn rejected(data: ?*anyopaque, value: runtime.JSValue) void {
        const self: *Observation = @ptrCast(@alignCast(data.?));
        self.outcome = .rejected;
        self.capture(value);
    }
    fn dropped(data: ?*anyopaque) void {
        const self: *Observation = @ptrCast(@alignCast(data.?));
        self.outcome = .dropped;
    }
    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .rejected = rejected, .dropped = dropped };
};

fn documentFonts(browser: *Browser) !*runtime.Instance {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const value = try browser.evaluateScript("document");
    defer value.release();
    const document = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    return interfaces.Document.get_fonts(document);
}

fn face(realm: runtime.Context, family: []const u8, loaded: bool) !*runtime.Instance {
    const result = try interfaces.FontFace.call_constructor(realm, .initInterned(family), .{ .cssomstring = .initInterned("url(unused.woff2)") }, .{ .was_passed = false, .value = undefined });
    const state = dom.style.hooks.fontFaceOf(result) orelse return error.NoFace;
    // The fixture controls the existing owner's completion state. No fetch
    // or decoder is needed to test the Set's reaction and retention rules.
    state.status = if (loaded) .loaded else .loading;
    return result;
}

fn pump(browser: *Browser, observation: *Observation) !void {
    for (0..200) |_| {
        if (observation.failure) |err| return err;
        if (observation.outcome != .pending) return;
        _ = try browser.runEventLoopBlocking(5);
    }
    return error.FontSetLoadNeverSettled;
}

fn collect(realm: runtime.Context) !void {
    const Collect = struct {
        fn run(data: ?*anyopaque) void {
            const agent: *engine.Agent = @ptrCast(@alignCast(data.?));
            engine.requestGarbageCollection(agent);
            engine.requestGarbageCollection(agent);
        }
    };
    try engine.runInRealm(realm, Collect.run, realm.agent orelse return error.NoAgent);
}

fn ordered() !void {
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const set = try documentFonts(browser);
    const first = try face(realm, "FM1First", true);
    const first_generation = runtime.SlabAllocator.generationOf(first);
    defer first.releaseIfUnwrapped(first_generation);
    const second = try face(realm, "FM1Second", true);
    const second_generation = runtime.SlabAllocator.generationOf(second);
    defer second.releaseIfUnwrapped(second_generation);
    _ = try interfaces.FontFaceSet.call_add(set, second);
    _ = try interfaces.FontFaceSet.call_add(set, first);
    // Loading 3 §3.1 steps 6/8, Blink FontFaceSet::load and liaison Q24:
    // preserve requested family order, including repeated matching faces.
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1First, FM1Second, FM1First"), .{ .was_passed = true, .value = .initInterned("A") }) };
    defer promise.release();
    var observation: Observation = .{ .realm = realm };
    defer observation.deinit();
    try engine.reactToPromise(realm, promise.borrow(), &Observation.steps, &observation);
    // Membership no longer keeps either face: only the pending result does.
    try std.testing.expect(try interfaces.FontFaceSet.call_delete(set, first));
    try std.testing.expect(try interfaces.FontFaceSet.call_delete(set, second));
    try collect(realm);
    try pump(browser, &observation);
    try std.testing.expectEqual(.fulfilled, observation.outcome);
    const results = try engine.convertToSequenceOfObjects(realm, observation.value.?.borrow(), a);
    defer {
        for (results) |result| result.release();
        a.free(results);
    }
    try std.testing.expectEqual(@as(usize, 3), results.len);
    for (results, [_]*runtime.Instance{ first, second, first }, [_]u64{ first_generation, second_generation, first_generation }) |result, expected, generation| {
        const actual = engine.convertToPlatformObject(realm, result.borrow()) orelse return error.NoReturnedFace;
        try std.testing.expect(actual == expected);
        try std.testing.expectEqual(generation, runtime.SlabAllocator.generationOf(actual));
        try std.testing.expectEqual(._loaded_, try interfaces.FontFace.get_status(actual));
    }
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "font set load retains ordered faces after membership removal and garbage collection" {
    try fresh(ordered);
}

fn emptyAndSyntax() !void {
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const set = try documentFonts(browser);
    for ([_][]const u8{ "16px MissingFamily", "inherit", "not a font" }, 0..) |font, index| {
        const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned(font), .{ .was_passed = false, .value = undefined }) };
        defer promise.release();
        var observation: Observation = .{ .realm = realm };
        defer observation.deinit();
        try engine.reactToPromise(realm, promise.borrow(), &Observation.steps, &observation);
        // Blink/WebKit resolve the empty match inline; Gecko Promise::All
        // does likewise. A microtask checkpoint alone observes it (Q24).
        try engine.performMicrotaskCheckpoint(realm.agent orelse return error.NoAgent);
        if (index == 0) try std.testing.expectEqual(.fulfilled, observation.outcome);
        try pump(browser, &observation);
        if (index == 0) {
            try std.testing.expectEqual(.fulfilled, observation.outcome);
            const results = try engine.convertToSequenceOfObjects(realm, observation.value.?.borrow(), a);
            defer {
                for (results) |result| result.release();
                a.free(results);
            }
            try std.testing.expectEqual(@as(usize, 0), results.len);
        } else {
            try std.testing.expectEqual(.rejected, observation.outcome);
            const name = try engine.getProperty(realm, observation.value.?.borrow(), "name");
            defer name.release();
            const text = try engine.convertToDOMString(realm, name.borrow(), a);
            defer a.free(text);
            try std.testing.expectEqualStrings("SyntaxError", text);
        }
    }
}

test "font set load returns an empty sequence or a rejected syntax promise" {
    try fresh(emptyAndSyntax);
}

fn synchronousStart() !void {
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const set = try documentFonts(browser);
    const item = try interfaces.FontFace.call_constructor(realm, .initInterned("FM1Synchronous"), .{ .cssomstring = .initInterned("local(FM1Uninstalled)") }, .{ .was_passed = false, .value = undefined });
    const generation = runtime.SlabAllocator.generationOf(item);
    defer item.releaseIfUnwrapped(generation);
    _ = try interfaces.FontFaceSet.call_add(set, item);
    try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(item));
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1Synchronous"), .{ .was_passed = false, .value = undefined }) };
    defer promise.release();
    engine.markPromiseAsHandled(realm, promise.borrow());
    // All three engines initiate the face loads inline, despite Loading 3
    // §3.2 step 4's queued task (Blink/WebKit/Gecko load; liaison Q24).
    try std.testing.expectEqual(._loading_, try interfaces.FontFace.get_status(item));
    try std.testing.expectEqual(._loading_, try interfaces.FontFaceSet.get_status(set));
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoSet;
    state.discard();
    // Teardown drops the unexecuted existing face-loading task and reactions.
}

test "font set load starts matched faces before returning its promise" {
    try fresh(synchronousStart);
}

fn initiallyFailed() !void {
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const set = try documentFonts(browser);
    const item = try face(realm, "FM1AlreadyFailed", false);
    const generation = runtime.SlabAllocator.generationOf(item);
    defer item.releaseIfUnwrapped(generation);
    _ = try interfaces.FontFaceSet.call_add(set, item);
    const state = dom.style.hooks.fontFaceOf(item) orelse return error.NoFace;
    const face_promise = try state.loadedPromise();
    defer face_promise.release();
    engine.markPromiseAsHandled(realm, face_promise.borrow());
    try state.reject(.network);
    var original: Observation = .{ .realm = realm };
    defer original.deinit();
    try engine.reactToPromise(realm, face_promise.borrow(), &Observation.steps, &original);
    // Loading 3 §3.1 step 4, Blink Match and Gecko FindMatchingFontFaces
    // include failed members; rendering's UsedFonts filter does not (Q27).
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1AlreadyFailed"), .{ .was_passed = false, .value = undefined }) };
    defer promise.release();
    var failed: Observation = .{ .realm = realm };
    defer failed.deinit();
    try engine.reactToPromise(realm, promise.borrow(), &Observation.steps, &failed);
    try pump(browser, &original);
    try pump(browser, &failed);
    try std.testing.expectEqual(.rejected, original.outcome);
    try std.testing.expectEqual(.rejected, failed.outcome);
    try std.testing.expect(engine.sameValue(realm, original.value.?.borrow(), failed.value.?.borrow()));

    const unmatched: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1Unmatched"), .{ .was_passed = false, .value = undefined }) };
    defer unmatched.release();
    var empty: Observation = .{ .realm = realm };
    defer empty.deinit();
    try engine.reactToPromise(realm, unmatched.borrow(), &Observation.steps, &empty);
    try pump(browser, &empty);
    try std.testing.expectEqual(.fulfilled, empty.outcome);
    const results = try engine.convertToSequenceOfObjects(realm, empty.value.?.borrow(), a);
    defer {
        for (results) |result| result.release();
        a.free(results);
    }
    try std.testing.expectEqual(@as(usize, 0), results.len);
}

test "font set load rejects an already failed match and ignores unmatched failures" {
    try fresh(initiallyFailed);
}

fn failureAndDiscard() !void {
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const set = try documentFonts(browser);
    const pending = try face(realm, "FM1Pending", false);
    const generation = runtime.SlabAllocator.generationOf(pending);
    defer pending.releaseIfUnwrapped(generation);
    const root = try engine.retainValue(realm, .{ .instance = pending });
    defer root.release();
    _ = try interfaces.FontFaceSet.call_add(set, pending);
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1Pending"), .{ .was_passed = false, .value = undefined }) };
    defer promise.release();
    var observation: Observation = .{ .realm = realm };
    defer observation.deinit();
    try engine.reactToPromise(realm, promise.borrow(), &Observation.steps, &observation);
    _ = try browser.runEventLoopBlocking(5);
    try std.testing.expectEqual(.pending, observation.outcome);
    const state = dom.style.hooks.fontFaceOf(pending) orelse return error.NoFace;
    try state.reject(.network);
    try pump(browser, &observation);
    try std.testing.expectEqual(.rejected, observation.outcome);
    const name = try engine.getProperty(realm, observation.value.?.borrow(), "name");
    defer name.release();
    const text = try engine.convertToDOMString(realm, name.borrow(), a);
    defer a.free(text);
    try std.testing.expectEqualStrings("NetworkError", text);

    const waiting = try face(realm, "FM1Discarded", false);
    const waiting_generation = runtime.SlabAllocator.generationOf(waiting);
    defer waiting.releaseIfUnwrapped(waiting_generation);
    const waiting_root = try engine.retainValue(realm, .{ .instance = waiting });
    defer waiting_root.release();
    _ = try interfaces.FontFaceSet.call_add(set, waiting);
    const abandoned: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1Discarded"), .{ .was_passed = false, .value = undefined }) };
    defer abandoned.release();
    var discarded: Observation = .{ .realm = realm };
    defer discarded.deinit();
    try engine.reactToPromise(realm, abandoned.borrow(), &Observation.steps, &discarded);
    _ = try browser.runEventLoopBlocking(5);
    const set_state = dom.style.hooks.fontSetOf(set) orelse return error.NoSet;
    set_state.discard();
    try interfaces.FontFaceSet.call_clear(set);
    const waiting_state = dom.style.hooks.fontFaceOf(waiting) orelse return error.NoFace;
    waiting_state.status = .loaded;
    const loaded = try waiting_state.loadedPromise();
    defer loaded.release();
    for (0..5) |_| _ = try browser.runEventLoopBlocking(5);
    try std.testing.expectEqual(.pending, discarded.outcome);
    try collect(realm);
    // Browser teardown drops the observer and any remaining face reaction;
    // std.testing.allocator observes the cancellation record's reclamation.
}

test "font set load propagates face failure and discards pending reactions at teardown" {
    try fresh(failureAndDiscard);
}

fn allocationFailures() !void {
    var failing = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
    const browser = try Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const doc_value = try browser.evaluateScript("document");
    defer doc_value.release();
    const document = engine.convertToPlatformObject(realm, doc_value.borrow()) orelse return error.NoDocument;
    const agent = realm.agent orelse return error.NoAgent;
    var reached_failure = false;
    for (0..1024) |offset| {
        // Recreate the set outside the failing interval, so earlier rounds
        // cannot hide the new pending-list allocation through retained capacity.
        const set = try interfaces.FontFaceSet.initWith(failing.allocator(), realm, .{ .font_document = document });
        const set_generation = runtime.SlabAllocator.generationOf(set);
        defer set.releaseIfUnwrapped(set_generation);
        const set_root = try engine.retainValue(realm, .{ .instance = set });
        defer set_root.release();
        inline for (.{ "FM1One", "FM1Two", "FM1Three" }) |family| {
            const item = try face(realm, family, true);
            const generation = runtime.SlabAllocator.generationOf(item);
            defer item.releaseIfUnwrapped(generation);
            _ = try interfaces.FontFaceSet.call_add(set, item);
        }
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + offset;
        var promise: ?engine.Owned = null;
        var operation_error: ?anyerror = null;
        if (interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1One, FM1Two, FM1Three"), .{ .was_passed = false, .value = undefined })) |value| {
            promise = .{ .value = value };
            engine.markPromiseAsHandled(realm, value);
        } else |err| operation_error = err;
        engine.performMicrotaskCheckpoint(agent) catch {};
        _ = browser.runEventLoopBlocking(1) catch {};
        const induced = failing.has_induced_failure;
        failing.fail_index = std.math.maxInt(usize);
        defer if (promise) |value| value.release();
        if (operation_error) |err| if (err != error.OutOfMemory) return err;
        try engine.performMicrotaskCheckpoint(agent);
        _ = try browser.runEventLoopBlocking(5);
        const state = dom.style.hooks.fontSetOf(set) orelse return error.NoSet;
        if (!induced) {
            try std.testing.expect(reached_failure);
            var observation: Observation = .{ .realm = realm };
            defer observation.deinit();
            try engine.reactToPromise(realm, (promise orelse return error.NoPromise).borrow(), &Observation.steps, &observation);
            try pump(browser, &observation);
            try std.testing.expectEqual(.fulfilled, observation.outcome);
            const results = try engine.convertToSequenceOfObjects(realm, observation.value.?.borrow(), a);
            defer {
                for (results) |result| result.release();
                a.free(results);
            }
            try std.testing.expectEqual(@as(usize, 3), results.len);
            state.discard();
            try interfaces.FontFaceSet.call_clear(set);
            return;
        }
        reached_failure = true;
        // A failure may have left reactions pending on an already-created
        // face promise. Discard must detach them without freeing their data
        // before their eventual fulfilled/rejected/dropped callback.
        state.discard();
        try interfaces.FontFaceSet.call_clear(set);
        try collect(realm);
    }
    return error.FontLoadAllocationSweepDidNotEnd;
}

test "font set load success failure and discarded partial reactions survive every allocation failure" {
    try fresh(allocationFailures);
}

fn callbackAllocationFailure() !void {
    var failing = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
    defer failing.fail_index = std.math.maxInt(usize);
    const browser = try Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = realm.agent orelse return error.NoAgent;
    const set = try documentFonts(browser);
    const first = try face(realm, "FM1Callback", false);
    const first_generation = runtime.SlabAllocator.generationOf(first);
    defer first.releaseIfUnwrapped(first_generation);
    const first_root = try engine.retainValue(realm, .{ .instance = first });
    defer first_root.release();
    const later = try face(realm, "FM1Later", false);
    const later_generation = runtime.SlabAllocator.generationOf(later);
    defer later.releaseIfUnwrapped(later_generation);
    const later_root = try engine.retainValue(realm, .{ .instance = later });
    defer later_root.release();
    _ = try interfaces.FontFaceSet.call_add(set, first);
    _ = try interfaces.FontFaceSet.call_add(set, later);
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1Callback, FM1Later"), .{ .was_passed = false, .value = undefined }) };
    defer promise.release();
    var observation: Observation = .{ .realm = realm };
    defer observation.deinit();
    try engine.reactToPromise(realm, promise.borrow(), &Observation.steps, &observation);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoSet;
    try std.testing.expectEqual(@as(usize, 1), state.pending_loads.items.len);
    const first_state = dom.style.hooks.fontFaceOf(first) orelse return error.NoFace;
    first_state.status = .loaded;
    const first_loaded = try first_state.loadedPromise();
    defer first_loaded.release();
    // Q40: allocation of the ordered fulfillment storage happens inside
    // the first reaction. OOM abandons the record without inventing a reason.
    failing.has_induced_failure = false;
    failing.fail_index = failing.alloc_index;
    engine.performMicrotaskCheckpoint(agent) catch {};
    const induced = failing.has_induced_failure;
    failing.fail_index = std.math.maxInt(usize);
    try std.testing.expect(induced);
    try std.testing.expectEqual(@as(usize, 0), state.pending_loads.items.len);
    try std.testing.expectEqual(.pending, observation.outcome);
    try interfaces.FontFaceSet.call_clear(set);
    const later_state = dom.style.hooks.fontFaceOf(later) orelse return error.NoFace;
    later_state.status = .loaded;
    const later_loaded = try later_state.loadedPromise();
    defer later_loaded.release();
    try engine.performMicrotaskCheckpoint(agent);
    try std.testing.expectEqual(@as(usize, 0), state.pending_loads.items.len);
    try std.testing.expectEqual(.pending, observation.outcome);
    state.discard();
    // Browser deinit drops the pending observer; the late face reaction
    // has already released the detached record, checked by testing.allocator.
}

test "allocation failure inside a font reaction detaches the record and makes later reactions inert" {
    try fresh(callbackAllocationFailure);
}

fn deinitPending() !void {
    const fonts = dom.style.engine.resource_loading.font_loading;
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const set = try documentFonts(browser);
    const set_root = try engine.retainValue(realm, .{ .instance = set });
    defer set_root.release();
    const item = try face(realm, "FM1Deinitialized", false);
    const generation = runtime.SlabAllocator.generationOf(item);
    defer item.releaseIfUnwrapped(generation);
    const face_root = try engine.retainValue(realm, .{ .instance = item });
    defer face_root.release();
    _ = try interfaces.FontFaceSet.call_add(set, item);
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1Deinitialized"), .{ .was_passed = false, .value = undefined }) };
    defer promise.release();
    var observation: Observation = .{ .realm = realm };
    defer observation.deinit();
    try engine.reactToPromise(realm, promise.borrow(), &Observation.steps, &observation);
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoSet;
    try std.testing.expectEqual(@as(usize, 1), state.pending_loads.items.len);
    const document = state.liveDocument() orelse return error.NoDocument;
    // Test-only reset (row131 Q14/Q42): pin deinit's pending branch without
    // destroying a live wrapper or creating a second state on this owner.
    // Restore exactly the window state established by FontFaceSet.initOwn.
    state.deinit();
    state.* = fonts.Set.init(set, document);
    try state.ready.ensure(set);
    state.environmentChanged();
    try std.testing.expectEqual(@as(usize, 0), state.pending_loads.items.len);
    const face_state = dom.style.hooks.fontFaceOf(item) orelse return error.NoFace;
    face_state.status = .loaded;
    const loaded = try face_state.loadedPromise();
    defer loaded.release();
    try engine.performMicrotaskCheckpoint(realm.agent orelse return error.NoAgent);
    try std.testing.expectEqual(.pending, observation.outcome);
    try std.testing.expectEqual(@as(usize, 0), state.pending_loads.items.len);
    // Normal generated destruction now sees an ordinary empty set; Browser
    // teardown drops the pending observer under the leak-checking allocator.
}

test "font set deinit cancels a pending load before a late face fulfillment" {
    try fresh(deinitPending);
}

fn unwrappedOwner() !void {
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const set = try interfaces.FontFaceSet.init(a, realm);
    const set_generation = runtime.SlabAllocator.generationOf(set);
    defer set.releaseIfUnwrapped(set_generation);
    const item = try face(realm, "FM1UnwrappedOwner", false);
    const generation = runtime.SlabAllocator.generationOf(item);
    defer item.releaseIfUnwrapped(generation);
    const face_root = try engine.retainValue(realm, .{ .instance = item });
    defer face_root.release();
    _ = try interfaces.FontFaceSet.call_add(set, item);
    // Q44: traceChild defers a real child edge for an unwrapped owner;
    // add established both membership invariants through its public API.
    try std.testing.expect(!engine.hasWrapper(set));
    const promise: engine.Owned = .{ .value = try interfaces.FontFaceSet.call_load(set, .initInterned("16px FM1UnwrappedOwner"), .{ .was_passed = false, .value = undefined }) };
    defer promise.release();
    try std.testing.expect(engine.hasWrapper(set));
    var set_root: ?engine.Owned = try engine.retainValue(realm, .{ .instance = set });
    defer if (set_root) |root| root.release();
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoSet;
    try std.testing.expectEqual(@as(usize, 1), state.pending_loads.items.len);
    var observation: Observation = .{ .realm = realm };
    defer observation.deinit();
    try engine.reactToPromise(realm, promise.borrow(), &Observation.steps, &observation);
    const face_state = dom.style.hooks.fontFaceOf(item) orelse return error.NoFace;
    face_state.status = .loaded;
    const loaded = try face_state.loadedPromise();
    defer loaded.release();
    try pump(browser, &observation);
    try std.testing.expectEqual(.fulfilled, observation.outcome);
    try std.testing.expectEqual(@as(usize, 0), state.pending_loads.items.len);
    set_root.?.release();
    set_root = null;
    try collect(realm);
    // A surviving counted keep would stop this standalone Set's collection.
    try std.testing.expect(runtime.SlabAllocator.generationOf(set) != set_generation);
}

test "font set load wraps a native owner before taking and ending its pending keep" {
    try fresh(unwrappedOwner);
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
