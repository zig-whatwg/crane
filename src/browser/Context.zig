//! Context - one page navigation
//!
//! A page's realm - its Window's - made in the Browser's agent, which every
//! navigation shares, and what the page has beyond its interfaces: its
//! document, navigator, location and performance objects, its timers and
//! animation frames, and host script evaluation (the WPT harness, WebDriver,
//! the REPL). The realm is made and ended through the engine protocol
//! (`@import("engine")`): this file names no engine.
//!
//! ## Specification References
//!
//! - HTML Standard: Browsing contexts https://html.spec.whatwg.org/multipage/document-sequences.html
//! - HTML Standard: Window object https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-window-object
//! - HTML Standard: Creating a new realm https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-new-javascript-realm

const std = @import("std");
const log = std.log.scoped(.browser_context);
const engine = @import("engine");
const clock = @import("clock");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const fetch = @import("fetch");

const storage_mod = @import("storage/Storage.zig");
const cookiestore = @import("cookiestore");
const Storage = storage_mod.Storage;
const navigation = @import("navigation.zig");
const impls = @import("impls");

// Threadlocal state cleanup modules
const dom_mod = @import("dom");
const html_mod = @import("html");
const mutation_observer_algorithms = dom_mod.mutation_observer_algorithms;
const instance_lifecycle = runtime.instance_lifecycle;

// Timer support
const TimerInterface = runtime.TimerInterface;
const TimerId = runtime.TimerId;
const TimerCallback = runtime.TimerCallback;
const typed_callback = runtime.typed_callback;
const SelfContainedWorkCallback = typed_callback.SelfContainedWorkCallback;

// ============================================================================
// Thread-local storage for timer interface (mirrors browser_context.zig pattern)
// ============================================================================

threadlocal var current_timer_interface: ?TimerInterface = null;
threadlocal var current_allocator: ?std.mem.Allocator = null;
threadlocal var timer_contexts: ?std.AutoHashMap(TimerId, *WindowTimerCallback) = null;

// ============================================================================
// Animation frames
// ============================================================================
//
// https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#animation-frames
//
// Crane paints nothing, but requestAnimationFrame is an EVENT LOOP feature, not
// a paint feature: its callbacks run in the "update the rendering" step, which a
// headless engine still performs. WPT uses rAF as the standard "wait one frame"
// idiom, so a stubbed rAF does not fail tests - it HANGS them for the full
// timeout. The WebIDL binding (impls/Window.zig call_requestAnimationFrame)
// discarded its callback and returned 0, which reached ~90 worklist sources.
//
// A frame is a BATCH, which is why this cannot be one timer per callback:
// documents run in container tree order and each snapshots its callbacks in
// registration order when its turn starts. New callbacks for that document
// wait; an earlier parent can still add a callback for a later child turn.

/// ~60Hz. The spec leaves the rate to the implementation.
const FRAME_INTERVAL_MS: u64 = 16;

const AnimationFrameEntry = struct {
    handle: u32,
    /// OWNED: the engine handed it over with requestAnimationFrame. Released
    /// once the callback has run, once it has been cancelled, or at teardown.
    callback: runtime.JSValue,
    /// The realm of the requestAnimationFrame that registered the callback:
    /// each Window has its own map of animation frame callbacks, so the
    /// callback runs, and reports what it throws, in the window it came from.
    /// Not owned: the context manager keeps a realm until teardown, and a
    /// destroyed window's entries go with it (windowDestroyed).
    realm: runtime.Context,
    /// Window reuse must not move the old Document's callback map to its
    /// successor. Borrowed identity, checked by slab generation before use.
    target_document: ?*runtime.Instance = null,
    target_document_generation: u64 = 0,
    cancelled: bool = false,
    /// Removed from the callback map immediately before invocation. The local
    /// batch continues to own its callback until the invocation returns.
    consumed: bool = false,

    fn deinit(self: *AnimationFrameEntry) void {
        releaseValue(self.takeCallback());
    }

    fn takeCallback(self: *AnimationFrameEntry) runtime.JSValue {
        const callback = self.callback;
        self.callback = .undefined;
        self.consumed = true;
        return callback;
    }
};

const AnimationFrameState = struct {
    /// Each document's callback map, interleaved in registration order. Its
    /// entries stay pending until that document's turn snapshots its handles.
    pending: std.ArrayListUnmanaged(AnimationFrameEntry) = .empty,
    /// The single timer driving the next frame, if one is scheduled.
    timer_id: ?TimerId = null,
    /// The batch currently being run, borrowed from animationFrameHandler's
    /// stack for the duration of the loop. cancelAnimationFrame has to be able
    /// to reach it: per HTML's "run the animation frame callbacks", cancelling
    /// from INSIDE a callback must still suppress a later callback in the SAME
    /// frame, and those entries are no longer in `pending`.
    running: []AnimationFrameEntry = &.{},
    /// Borrowed stack identity for the entire rendering turn, including gaps
    /// between document batches. Replaced state never inherits the identity.
    dispatch_token: ?*const u8 = null,
    /// Handles are their own space, not the timer id space: per spec
    /// cancelAnimationFrame(someTimeoutId) must do nothing.
    next_handle: u32 = 1,
};

threadlocal var animation_frames: ?AnimationFrameState = null;

const AnimationFrameDisposition = enum { ready, deferred, terminal };

/// A rendering turn captures documents, including ones with no callback yet.
/// These identities are borrowed; before each turn, resolve the navigable id
/// again and check both slab generations without dereferencing an old realm.
const AnimationFrameDocument = struct {
    navigable_id: u64,
    window: *runtime.Instance,
    window_generation: u64,
    document: *runtime.Instance,
    document_generation: u64,
    realm: runtime.Context,

    fn current(self: AnimationFrameDocument) bool {
        const navigable = html_mod.window.BrowsingContext.byId(self.navigable_id) orelse return false;
        if (navigable.is_closed or navigable.orphaned) return false;
        if (navigable.active_window != @as(?*anyopaque, @ptrCast(self.window)) or
            navigable.active_document != @as(?*anyopaque, @ptrCast(self.document))) return false;
        if (runtime.SlabAllocator.generationOf(self.window) != self.window_generation) return false;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return false;
        return self.window.ctx == self.realm and self.realm.hasEngine() and
            !instance_lifecycle.isCleanupStarted(self.window) and
            !instance_lifecycle.isCleanupStarted(self.document);
    }
};

/// Reserve storage before moving any callback owner. Snapshot only THIS
/// document's handles when its turn starts (HTML run-animation-callbacks 1–2).
/// Parent callbacks can therefore register callbacks for a later child turn.
fn takeAnimationFrameBatch(
    allocator: std.mem.Allocator,
    state: *AnimationFrameState,
    realm: runtime.Context,
) error{OutOfMemory}!std.ArrayListUnmanaged(AnimationFrameEntry) {
    var count: usize = 0;
    for (state.pending.items) |entry| if (entry.realm == realm) {
        count += 1;
    };
    var batch: std.ArrayListUnmanaged(AnimationFrameEntry) = .empty;
    errdefer batch.deinit(allocator);
    try batch.ensureTotalCapacity(allocator, count);
    var index: usize = 0;
    while (index < state.pending.items.len) {
        if (state.pending.items[index].realm == realm) {
            batch.appendAssumeCapacity(state.pending.orderedRemove(index));
        } else index += 1;
    }
    return batch;
}

/// Terminal owners cannot be invoked by any future rendering opportunity.
/// A live hidden/inactive/blocked document keeps its owners until a later turn.
fn retireAnimationFrameCallbacks(state: *AnimationFrameState) void {
    var index: usize = 0;
    while (index < state.pending.items.len) {
        const entry = state.pending.items[index];
        if (entry.cancelled or animationFrameRealmIsTerminal(entry.realm) or animationFrameTargetReplaced(entry)) {
            var removed = state.pending.orderedRemove(index);
            removed.deinit();
        } else index += 1;
    }
}

/// HTML update-rendering steps 2–3 collect and filter all documents before JS.
/// The no-callback documents matter: an earlier parent turn can add their
/// first callback. Documents created during a callback wait until next frame.
fn collectAnimationFrameDocuments(
    allocator: std.mem.Allocator,
    seed: runtime.Context,
) error{OutOfMemory}!std.ArrayListUnmanaged(AnimationFrameDocument) {
    const contexts = html_mod.window.BrowsingContext.liveContexts();
    var documents: std.ArrayListUnmanaged(AnimationFrameDocument) = .empty;
    errdefer documents.deinit(allocator);
    try documents.ensureTotalCapacity(allocator, contexts.len);
    const loop = seed.getOptionalEventLoop();
    for (contexts) |navigable| {
        if (navigable.is_closed or navigable.orphaned) continue;
        const window: *runtime.Instance = @ptrCast(@alignCast(navigable.active_window orelse continue));
        if (runtime.SlabAllocator.generationOf(window) == runtime.SlabAllocator.dead_generation) continue;
        if (instance_lifecycle.isCleanupStarted(window)) continue;
        const realm = window.ctx;
        const document_loop = realm.getOptionalEventLoop();
        if (loop) |expected| {
            const actual = document_loop orelse continue;
            if (actual.ptr != expected.ptr or actual.vtable != expected.vtable) continue;
        } else if (document_loop != null or realm.agent != seed.agent) continue;
        if (documentDispositionForAnimationFrame(realm) != .ready) continue;
        const document: *runtime.Instance = @ptrCast(@alignCast(navigable.active_document orelse continue));
        documents.appendAssumeCapacity(.{
            .navigable_id = navigable.id,
            .window = window,
            .window_generation = runtime.SlabAllocator.generationOf(window),
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
            .realm = realm,
        });
    }
    // No script runs while sorting, so the live navigable tree is stable.
    std.mem.sort(AnimationFrameDocument, documents.items, {}, animationFrameDocumentLessThan);
    return documents;
}

fn animationFrameDocumentLessThan(_: void, a: AnimationFrameDocument, b: AnimationFrameDocument) bool {
    var left = html_mod.window.BrowsingContext.byId(a.navigable_id) orelse return false;
    var right = html_mod.window.BrowsingContext.byId(b.navigable_id) orelse return false;
    var left_depth: usize = 0;
    var right_depth: usize = 0;
    var left_root = left;
    while (left_root.parent) |parent| : (left_depth += 1) left_root = parent;
    var right_root = right;
    while (right_root.parent) |parent| : (right_depth += 1) right_root = parent;
    // HTML permits arbitrary order between unrelated top-level documents.
    if (left_root != right_root) return left_root.id < right_root.id;
    const original_left_depth = left_depth;
    const original_right_depth = right_depth;
    while (left_depth > right_depth) : (left_depth -= 1) left = left.parent.?;
    while (right_depth > left_depth) : (right_depth -= 1) right = right.parent.?;
    if (left == right) return original_left_depth < original_right_depth;
    while (left.parent != right.parent) {
        left = left.parent.?;
        right = right.parent.?;
    }
    const parent = left.parent orelse return left.id < right.id;
    const document: *runtime.Instance = @ptrCast(@alignCast(parent.active_document orelse return left.id < right.id));
    const left_container: *runtime.Instance = @ptrCast(@alignCast(left.container orelse return left.id < right.id));
    const right_container: *runtime.Instance = @ptrCast(@alignCast(right.container orelse return left.id < right.id));
    return shadowIncludingContainerOrder(document, left_container, right_container) orelse (left.id < right.id);
}

/// Visit a host's shadow tree (including closed roots) before its light tree.
/// Pure IDL getters and the owning Element hook; no JS getters or allocations.
fn shadowIncludingContainerOrder(root: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance) ?bool {
    var node = root;
    while (true) {
        if (node == a) return true;
        if (node == b) return false;
        if (dom_mod.shadow_hosts.rootForHost(node)) |shadow| {
            node = shadow;
            continue;
        }
        if (interfaces.Node.get_firstChild(node) catch null) |child| {
            node = child;
            continue;
        }
        while (true) {
            if (node == root) return null;
            if (interfaces.Node.get_nextSibling(node) catch null) |sibling| {
                node = sibling;
                break;
            }
            if (interfaces.Node.get_parentNode(node) catch null) |parent| {
                node = parent;
            } else if (std.mem.eql(u8, node.vtable.name, "ShadowRoot")) {
                const host = interfaces.ShadowRoot.get_host(node) catch return null;
                if (interfaces.Node.get_firstChild(host) catch null) |child| {
                    node = child;
                    break;
                }
                node = host;
            } else return null;
        }
    }
}

test "per-document frame batches include parent additions but defer their own additions" {
    const allocator = std.testing.allocator;
    var parent = try runtime.ContextData.init(allocator, .{});
    defer parent.deinit();
    var child = try runtime.ContextData.init(allocator, .{});
    defer child.deinit();
    var state: AnimationFrameState = .{};
    defer state.pending.deinit(allocator);
    try state.pending.appendSlice(allocator, &.{
        .{ .handle = 1, .callback = .{ .number = 1 }, .realm = &child },
        .{ .handle = 2, .callback = .{ .number = 2 }, .realm = &parent },
    });
    var parent_batch = try takeAnimationFrameBatch(allocator, &state, &parent);
    defer parent_batch.deinit(allocator);
    try std.testing.expectEqual(@as(u32, 2), parent_batch.items[0].handle);
    try state.pending.append(allocator, .{ .handle = 3, .callback = .{ .number = 3 }, .realm = &child });
    var child_batch = try takeAnimationFrameBatch(allocator, &state, &child);
    defer child_batch.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), child_batch.items.len);
    try std.testing.expectEqual(@as(u32, 1), child_batch.items[0].handle);
    try std.testing.expectEqual(@as(u32, 3), child_batch.items[1].handle);
    try state.pending.append(allocator, .{ .handle = 4, .callback = .{ .number = 4 }, .realm = &child });
    try std.testing.expectEqual(@as(usize, 1), state.pending.items.len);
    try std.testing.expectEqual(@as(u32, 4), state.pending.items[0].handle);
    // Three distinct owners moved once; the new child owner remains pending.
    try std.testing.expectEqual(@as(f64, 6), parent_batch.items[0].callback.number + child_batch.items[0].callback.number + child_batch.items[1].callback.number);
}

test "per-document frame reserve failure leaves every owner and handle pending" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var state: AnimationFrameState = .{};
    defer state.pending.deinit(allocator);
    try state.pending.append(allocator, .{ .handle = 7, .callback = .{ .number = 17 }, .realm = &realm });
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, takeAnimationFrameBatch(failing.allocator(), &state, &realm));
    try std.testing.expectEqual(@as(usize, 1), state.pending.items.len);
    try std.testing.expectEqual(@as(u32, 7), state.pending.items[0].handle);
    try std.testing.expectEqual(@as(f64, 17), state.pending.items[0].callback.number);
    var batch = try takeAnimationFrameBatch(allocator, &state, &realm);
    defer batch.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), state.pending.items.len);
    try std.testing.expectEqual(@as(usize, 1), batch.items.len);
}

test "terminal frame requests advance handles without retaining owners" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    const saved_allocator = current_allocator;
    const saved_frames = animation_frames;
    defer {
        current_allocator = saved_allocator;
        animation_frames = saved_frames;
    }
    current_allocator = allocator;
    animation_frames = .{};
    defer animation_frames.?.pending.deinit(allocator);
    try std.testing.expectEqual(AnimationFrameDisposition.terminal, documentDispositionForAnimationFrame(&realm));
    try std.testing.expectEqual(@as(u32, 1), requestAnimationFrame(&realm, .undefined));
    try std.testing.expectEqual(@as(u32, 2), requestAnimationFrame(&realm, .undefined));
    try std.testing.expectEqual(@as(usize, 0), animation_frames.?.pending.items.len);
    try std.testing.expect(animation_frames.?.timer_id == null);
    // An entry accepted before its realm ended is retired as well.
    try animation_frames.?.pending.append(allocator, .{ .handle = 3, .callback = .undefined, .realm = &realm });
    retireAnimationFrameCallbacks(&animation_frames.?);
    try std.testing.expectEqual(@as(usize, 0), animation_frames.?.pending.items.len);
}

test "animation frame callback owner is released exactly once after transfer" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var state: AnimationFrameState = .{};
    defer state.pending.deinit(allocator);
    try state.pending.append(allocator, .{ .handle = 7, .callback = .{ .number = 17 }, .realm = &realm });
    var batch = try takeAnimationFrameBatch(allocator, &state, &realm);
    defer batch.deinit(allocator);
    const Counter = struct {
        fn release(count: *usize, value: runtime.JSValue) void {
            if (value == .number) {
                std.debug.assert(value.number == 17);
                count.* += 1;
            }
        }
    };
    var released: usize = 0;
    Counter.release(&released, batch.items[0].takeCallback());
    Counter.release(&released, batch.items[0].takeCallback());
    try std.testing.expectEqual(@as(usize, 1), released);
    try std.testing.expect(batch.items[0].consumed);
    try std.testing.expect(batch.items[0].callback == .undefined);
    try std.testing.expectEqual(@as(usize, 0), state.pending.items.len);
}

test "frame cancellation reaches pending and running maps without canceling a consumed handle" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var state: AnimationFrameState = .{};
    defer state.pending.deinit(allocator);
    var running = [_]AnimationFrameEntry{
        .{ .handle = 1, .callback = .undefined, .realm = &realm, .consumed = true },
        .{ .handle = 2, .callback = .undefined, .realm = &realm },
    };
    state.running = &running;
    try state.pending.append(allocator, .{ .handle = 3, .callback = .undefined, .realm = &realm });
    cancelAnimationFrameIn(&state, &realm, 1);
    try std.testing.expect(!running[0].cancelled);
    cancelAnimationFrameIn(&state, &realm, 2);
    try std.testing.expect(running[1].cancelled);
    cancelAnimationFrameIn(&state, &realm, 3);
    retireAnimationFrameCallbacks(&state);
    try std.testing.expectEqual(@as(usize, 0), state.pending.items.len);
}

test "callable removed Window is terminal but a live navigable awaiting its document is deferred" {
    const allocator = std.testing.allocator;
    var dummy_engine: u32 = 0;
    var realm = try runtime.ContextData.init(allocator, .{ .engine_ctx = &dummy_engine });
    defer realm.deinit();
    // No engine operation reaches the fake context. These objects are only
    // read as runtime identities, and no slab-generation check is needed.
    var window: runtime.Instance = undefined;
    const record = try runtime.Realm.init(allocator, .{ .global_object = &window });
    defer record.deinit();
    realm.setRealm(record);
    defer realm.clearRealm();
    const navigable = try html_mod.window.BrowsingContext.init(allocator);
    defer navigable.deinit();
    navigable.active_window = &window;
    try std.testing.expectEqual(AnimationFrameDisposition.deferred, documentDispositionForAnimationFrame(&realm));
    navigable.is_closed = true;
    try std.testing.expectEqual(AnimationFrameDisposition.terminal, documentDispositionForAnimationFrame(&realm));
    navigable.is_closed = false;
    navigable.orphaned = true;
    try std.testing.expectEqual(AnimationFrameDisposition.terminal, documentDispositionForAnimationFrame(&realm));
    navigable.orphaned = false;
    navigable.active_window = null;
    try std.testing.expectEqual(AnimationFrameDisposition.terminal, documentDispositionForAnimationFrame(&realm));
    try std.testing.expect(realm.hasEngine());
}

test "frame document collection reserve failure leaves callback owners untouched" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    const navigable = try html_mod.window.BrowsingContext.init(allocator);
    defer navigable.deinit();
    var state: AnimationFrameState = .{};
    defer state.pending.deinit(allocator);
    try state.pending.append(allocator, .{ .handle = 7, .callback = .{ .number = 17 }, .realm = &realm });
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, collectAnimationFrameDocuments(failing.allocator(), &realm));
    try std.testing.expectEqual(@as(usize, 1), state.pending.items.len);
    try std.testing.expectEqual(@as(f64, 17), state.pending.items[0].callback.number);
    try std.testing.expectEqual(@as(u32, 7), state.pending.items[0].handle);
}

test "whole frame dispatch token survives empty document batches and detects replaced state" {
    const saved_frames = animation_frames;
    defer animation_frames = saved_frames;
    var token: u8 = 0;
    animation_frames = .{ .dispatch_token = &token };
    try std.testing.expect(animation_frames.?.running.len == 0);
    try std.testing.expect(animationFrameDispatchState(&token) != null);
    animation_frames = .{};
    try std.testing.expect(animationFrameDispatchState(&token) == null);
}

test "frame document identities reject replacement and slab reuse of the same address" {
    // This test needs a fresh per-thread slab, independent of earlier files'
    // Browser/V8 startup. No engine operation reaches the fake engine pointer.
    const Worker = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
        fn body() !void {
            const allocator = std.testing.allocator;
            runtime.SlabAllocator.init(allocator);
            defer runtime.SlabAllocator.deinit();
            var dummy_engine: u32 = 0;
            var realm = try runtime.ContextData.init(allocator, .{ .engine_ctx = &dummy_engine });
            defer realm.deinit();
            const vtable: runtime.VTable = .{ .name = "Window", .deinit = null, .methods_ptr = &dummy_engine };
            const slab = runtime.SlabAllocator.get();
            const window = try slab.alloc(&vtable);
            defer slab.free(window);
            window.ctx = &realm;
            const original = try slab.alloc(&vtable);
            var original_alive = true;
            defer if (original_alive) slab.free(original);
            original.ctx = &realm;
            const replacement = try slab.alloc(&vtable);
            defer slab.free(replacement);
            replacement.ctx = &realm;
            const record = try runtime.Realm.init(allocator, .{ .global_object = window });
            defer record.deinit();
            realm.setRealm(record);
            defer realm.clearRealm();
            const navigable = try html_mod.window.BrowsingContext.init(allocator);
            defer navigable.deinit();
            navigable.active_window = window;
            navigable.active_document = original;
            const document: AnimationFrameDocument = .{
                .navigable_id = navigable.id,
                .window = window,
                .window_generation = runtime.SlabAllocator.generationOf(window),
                .document = original,
                .document_generation = runtime.SlabAllocator.generationOf(original),
                .realm = &realm,
            };
            const callback: AnimationFrameEntry = .{
                .handle = 1,
                .callback = .undefined,
                .realm = &realm,
                .target_document = original,
                .target_document_generation = document.document_generation,
            };
            try std.testing.expect(document.current());
            try std.testing.expect(!animationFrameTargetReplaced(callback));
            navigable.active_document = replacement;
            try std.testing.expect(!document.current());
            try std.testing.expect(animationFrameTargetReplaced(callback));
            navigable.active_document = original;
            slab.free(original);
            original_alive = false;
            const reused = try slab.alloc(&vtable);
            defer slab.free(reused);
            reused.ctx = &realm;
            try std.testing.expect(reused == original);
            try std.testing.expect(!document.current());
            try std.testing.expect(animationFrameTargetReplaced(callback));
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Worker.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// Captured when the timer interface is installed, which is context setup - close
/// enough to the spec's time origin, and it avoids taking an hr_time dependency
/// here. rAF timestamps are therefore ms since context setup, monotonic and
/// comparable to each other, which is what the frame tests assert.
threadlocal var animation_frame_origin_ms: i64 = 0;

// ============================================================================
// HTML timer initialisation steps (HTML Standard s8.6)
// ============================================================================
//
// setTimeout/setInterval do NOT schedule the delay the author asked for. The spec
// runs "timer initialisation steps" first:
//
//   3. If timeout is less than 0, then set timeout to 0.
//   5. If nesting level is greater than 5, and timeout is less than 4, then set
//      timeout to 4.
//
// and the timer being scheduled records `nesting level + 1`, so a chain of
// self-rescheduling timers is throttled to 4ms once it is more than five deep.
//
// Crane already had a correct implementation of this in
// src/html/event_loop/timers.zig (MIN_NESTED_DELAY_MS, NESTING_LEVEL_THRESHOLD,
// setTimerInternal). It is DEAD CODE - nothing references its TimerManager. The live
// path is this file -> the thread-local TimerInterface -> the Browser's event loop
// (browser/event_loop.zig) -> runtime.native_timer,
// which applied no clamping whatsoever. So the clamp is implemented here, at the
// setTimeout boundary, which is where the spec puts it: initialisation runs before
// the timer is handed to any scheduler.
//
// Thread-local because the nesting level belongs to the agent, and one agent is one
// thread with one isolate.

// HTML §8.6's nesting and clamp live in `runtime.timer`, shared with the worker
// binding - which previously had no clamp at all. Aliases, not a second copy: two
// definitions of a spec constant is how the two paths diverged in the first place.
const clampTimeout = runtime.timer.clampTimeout;

/// Restore the timer nesting level at the start of the microtask checkpoint.
///
/// A plain `defer` around the callback restores too late. The engine drains the
/// microtask queue when the JS call stack empties - which happens INSIDE the
/// callback's invocation - so a microtask queued by a timer callback would still
/// observe the task's nesting level and have its sub-4ms timeout clamped.
///
/// Microtasks run FIFO, so enqueueing this BEFORE invoking the callback puts it
/// ahead of anything the callback enqueues. That lands the reset exactly on the
/// spec boundary: a setTimeout called synchronously from the callback nests one
/// deeper, while one scheduled from a microtask does not inherit the level at all.
/// The checkpoint runs between tasks, so the level there is 0 by definition.
fn resetNestingMicrotask(_: ?*anyopaque) void {
    runtime.timer.nesting_level = 0;
}

/// Give back a value the engine handed over (OWNED).
fn releaseValue(value: runtime.JSValue) void {
    engine.releaseValue(.{ .value = value });
}

/// The Window whose realm `realm` is: its realm record's global object.
fn realmWindow(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global = record.global_object orelse return null;
    return @ptrCast(@alignCast(global));
}

/// HTML "report an exception" for the Window `host`, with the error
/// information the engine extracted (step 2): an ErrorEvent at it,
/// `window.onerror`.
fn reportToWindow(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const window: *runtime.Instance = @ptrCast(@alignCast(host orelse return));
    const extracted = runtime.ErrorInfo{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = html_mod.report_exception.reportErrorInfo(window, &extracted, .{});
}

/// "Report an exception" for `realm`'s Window, as the engine's reporter.
fn windowReporter(realm: runtime.Context) engine.Reporter {
    return .{ .report = reportToWindow, .host = realmWindow(realm) };
}

/// Invoke a timer or animation frame callback, reporting what it throws.
///
/// HTML's timer initialization steps and "run the animation frame callbacks"
/// invoke the callback with "report": an exception is REPORTED for the
/// global - an ErrorEvent at the Window, `window.onerror` - not printed and
/// dropped. The callback this value is the WindowProxy. (For animation frames
/// the spec gives none, so a strict callback should see undefined; the
/// WindowProxy is what this binding has always passed, and is kept.)
fn invokeReporting(realm: runtime.Context, callback: runtime.JSValue, args: []const runtime.JSValue) void {
    // BORROWED: the timer or frame entry keeps the function. No callback
    // context was recorded when it was converted.
    const function = engine.CallbackFunction{ .function = .{ .value = callback }, .context = null };
    const completion = engine.invokeCallbackFunction(realm, &function, .global_this, args, .{ .report = windowReporter(realm) }) catch |err| {
        log.debug("a timer or animation frame callback was not invoked: {}", .{err});
        return;
    };
    switch (completion) {
        .normal, .throw => |value| value.release(),
    }
}

/// "Clean up after running script" at the end of a timer or frame task: the
/// microtask checkpoint of the agent `realm` belongs to.
fn performMicrotaskCheckpoint(realm: runtime.Context) void {
    engine.performMicrotaskCheckpoint(realm.agent orelse return) catch {};
}

/// Set the current timer interface
pub fn setTimerInterface(timer: TimerInterface, allocator: std.mem.Allocator) void {
    current_timer_interface = timer;
    current_allocator = allocator;
    // Initialize timer contexts map if needed
    if (timer_contexts == null) {
        timer_contexts = std.AutoHashMap(TimerId, *WindowTimerCallback).init(allocator);
    }
    animation_frame_origin_ms = clock.monotonicMillis();
}

/// Get the current timer interface
pub fn getTimerInterface() ?TimerInterface {
    return current_timer_interface;
}

/// Clear the timer interface reference and clean up ALL pending timer contexts
/// This properly cancels libuv timers to prevent handle accumulation
pub fn clearTimerInterface() void {
    // Clean up any remaining timer contexts (both one-shot and intervals)
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // Cancel the timer at the libuv level to prevent callback from firing
            // and to properly clean up the libuv timer handle.
            //
            // The result is deliberately discarded: this is context teardown, so the
            // timer manager is going away with us and every wrapper must be freed
            // here or leak. Unlike unregisterTimerContext there is no later callback
            // to hand ownership to.
            if (current_timer_interface) |timer| {
                _ = timer.clearTimeout(wrapper.getData().current_timer_id);
            }
            destroyTimer(wrapper);
        }
        map.deinit();
        timer_contexts = null;
    }

    // Animation frames: cancel the frame timer and drop the pending batch.
    if (animation_frames) |*state| {
        if (state.timer_id) |id| {
            if (current_timer_interface) |timer| _ = timer.clearTimeout(id);
        }
        // The handler owns its running batch. Teardown only cancels it; the
        // handler releases each callback exactly once when it reaches it.
        for (state.running) |*entry| entry.cancelled = true;
        // Every pending entry still owns its callback.
        for (state.pending.items) |*entry| entry.deinit();
        if (current_allocator) |alloc| state.pending.deinit(alloc);
        animation_frames = null;
    }

    // (The window operations the page's realm installed end with the realm:
    // destroyWindowRealm.)
    current_timer_interface = null;
    current_allocator = null;
}

/// The window's native operations, as the engine binds them: the host's
/// steps behind setTimeout, setInterval, their clears, and the animation
/// frame methods (see `runtime.WindowOperations`).
const window_operations = runtime.WindowOperations{
    .initializeTimer = initializeTimer,
    .clearTimer = clearTimer,
    .requestAnimationFrame = requestAnimationFrame,
    .cancelAnimationFrame = cancelAnimationFrame,
    .windowDestroyed = clearWindowState,
};

/// The hooks the browser layer owns (src/dom), installed once, at process
/// start, by crane.Process (docs/instances.md): a removed frame's document
/// takes its window's timers and animation frames with it, while its realm
/// lives on (HTMLIFrameElement asks, through dom.window_documents).
pub fn installHooks() void {
    @import("dom").window_documents.install(.{ .destroyed = clearWindowState });
    @import("dom").idle_periods.installLoop(@import("event_loop.zig").EventLoop.idle_period_hooks);
}

/// A frame's document is being destroyed, and with it its window's map of
/// active timers (HTML "unloading document cleanup steps": clear window's map
/// of active timers) and its map of animation frame callbacks. Without this a
/// removed frame's timers kept firing, and a destroyed one's fired into a
/// window whose state was freed.
fn clearWindowState(realm: runtime.Context) void {
    // The unloading document cleanup steps other specifications define (the
    // File API's: the window's blob URL entries leave the store).
    dom_mod.unloading_cleanup.run(realm);

    if (timer_contexts) |*map| {
        var doomed: std.ArrayListUnmanaged(TimerId) = .empty;
        defer if (current_allocator) |alloc| doomed.deinit(alloc);
        var iter = map.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.getData().realm != realm) continue;
            const alloc = current_allocator orelse break;
            doomed.append(alloc, entry.key_ptr.*) catch break;
        }
        // Not while iterating: unregistering removes from the map.
        for (doomed.items) |id| unregisterTimerContext(id);
    }

    if (animation_frames) |*state| {
        // The batch in progress sees its own entries through `running`; one
        // of this window's is skipped rather than removed from under the loop.
        for (state.running) |*entry| {
            if (entry.realm == realm) entry.cancelled = true;
        }
        var i: usize = 0;
        while (i < state.pending.items.len) {
            const entry = state.pending.items[i];
            if (entry.realm == realm) {
                var removed = state.pending.orderedRemove(i);
                removed.deinit();
            } else i += 1;
        }
    }
}

/// Clear ALL pending timer contexts but keep the timer interface
/// This is used during test isolation to cancel timers without tearing down the interface
pub fn clearPendingTimers() void {
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // Cancel the timer at the libuv level
            if (current_timer_interface) |timer| {
                _ = timer.clearTimeout(wrapper.getData().current_timer_id);
            }
            destroyTimer(wrapper);
        }
        map.clearRetainingCapacity();
    }
}

/// Schedule `wrapper`'s first run and enter it in the map of active timers
/// under the id returned to script. Null when either fails, in which case
/// the wrapper has been freed.
///
/// The id is the manager's id for this FIRST run, and it stays the timer's id
/// for its whole life: an interval's repeats get new manager ids, but the timer
/// initialization steps run again "given ... id", so clearInterval must keep
/// working with the id setInterval returned. It used to be re-keyed to each
/// repeat's manager id, so after the first repeat clearInterval(id) found
/// nothing and the interval ran until the page went away.
fn scheduleTimer(timer: TimerInterface, wrapper: *WindowTimerCallback, delay_ms: u64) ?TimerId {
    const map = if (timer_contexts) |*m| m else {
        destroyTimer(wrapper);
        return null;
    };
    const id = timer.setTimeout(delay_ms, WindowTimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
    if (id == 0) {
        destroyTimer(wrapper);
        return null;
    }
    wrapper.getData().id = id;
    wrapper.getData().current_timer_id = id;
    map.put(id, wrapper) catch {
        // Untracked, it could never be cleared or cleaned up. Cancel before
        // freeing: a scheduled timer holds the wrapper.
        _ = timer.clearTimeout(id);
        destroyTimer(wrapper);
        return null;
    };
    return id;
}

/// Unregister a timer context (cancels and destroys it)
///
/// Timer IDs are looked up in the map and nowhere else. Passing script's number
/// straight to the manager, as clearTimeout used to, cancelled whatever manager
/// timer had that id - an animation frame, an AbortSignal timeout.
fn unregisterTimerContext(timer_id: TimerId) void {
    if (timer_contexts) |*map| {
        if (map.fetchRemove(timer_id)) |kv| {
            const wrapper = kv.value;
            // Mark as cancelled so interval callbacks know to stop rescheduling.
            // This must happen before anything else: it is the only signal that
            // reaches a callback we could not cancel.
            wrapper.getData().cancelled = true;

            // Cancel at the libuv level so the callback cannot fire.
            //
            // The thread-local TimerInterface belongs to the realm calling
            // clearTimeout, which is NOT necessarily the realm that scheduled the
            // timer. Cross-realm, the id is unknown to this manager and nothing is
            // cancelled - clearTimeout used to return void, so that silent miss was
            // invisible and the wrapper was freed anyway. The armed timer then fired
            // on freed memory and destroyed it a second time: a double free, and a
            // 0xaa-poisoned segfault in destroyChildContext just after.
            //
            // So the wrapper is only freed when cancellation is CONFIRMED. Otherwise
            // ownership passes to the callback, which sees `cancelled` and destroys
            // it when it fires.
            const cancelled = if (current_timer_interface) |timer|
                timer.clearTimeout(wrapper.getData().current_timer_id)
            else
                false;

            // Never free a wrapper whose callback is on the stack - that handler
            // still reads `data` after the callback returns and frees it itself.
            if (cancelled and !wrapper.getData().executing) destroyTimer(wrapper);
        }
    }
}

// ============================================================================
// Window timers
// ============================================================================

/// Everything one setTimeout or setInterval needs when it fires. The handler
/// and the arguments are OWNED engine handles - handed over by the binding -
/// and `release` returns them all. A timer used to hold its realm's context
/// as a handle too, which kept that page's whole heap alive until the timer
/// was freed; the realm is now the runtime.Context, which holds nothing.
const WindowTimerData = struct {
    /// The converted TimerHandler: a callable, or the string ToString made of
    /// anything else when setTimeout was called.
    handler: runtime.WindowTimerHandler,
    /// `any... arguments`, passed to a Function handler on every run. OWNED
    /// handles, in a slice from the wrapper's allocator.
    arguments: []runtime.JSValue,
    /// The realm the timer was set in - the Window whose method was called.
    /// Not owned: the context manager keeps a realm until teardown, and a
    /// destroyed window's timers go with it (clearWindowState).
    realm: runtime.Context,
    /// Whether this is an interval (repeating) timer - affects cleanup
    is_interval: bool,
    /// The timeout after conversion and step 4 (negative becomes 0), before
    /// the nesting clamp: an interval re-runs the timer initialization steps
    /// with it, and each repeat clamps afresh.
    timeout_ms: i64 = 0,
    /// The id setTimeout/setInterval returned, and this timer's key in
    /// `timer_contexts`. Stable for the timer's life (see scheduleTimer).
    id: TimerId = 0,
    /// The manager's id for the pending run. An interval gets a new one per repeat.
    current_timer_id: TimerId = 0,
    /// For intervals: whether the interval has been cancelled
    cancelled: bool = false,
    /// This timer's nesting level, per the timer initialisation steps. While its
    /// callback runs, `runtime.timer.nesting_level` is set to this, so timers created inside
    /// nest one deeper and eventually trip the 4ms clamp.
    nesting_level: u32 = 0,
    /// True while this timer's callback is on the stack.
    ///
    /// A callback may cancel ITSELF - `clearInterval(id)` from inside the interval
    /// is ordinary JS, and testharness cleanups do it routinely. The handler is
    /// still executing on this wrapper at that moment, and destroys it again when
    /// the callback returns, so an unconditional free in unregisterTimerContext is
    /// a double free (and the freed wrapper's context pointer then surfaced as a
    /// 0xaa-poisoned segfault in destroyChildContext).
    ///
    /// While this is set, the running handler owns the wrapper and is the only
    /// thing allowed to free it.
    executing: bool = false,

    /// Return every handle this timer owns. Only `destroyTimer` calls it.
    fn release(self: *WindowTimerData, allocator: std.mem.Allocator) void {
        switch (self.handler) {
            .function, .string => |handle| releaseValue(handle),
        }
        for (self.arguments) |argument| releaseValue(argument);
        allocator.free(self.arguments);
        self.arguments = &.{};
    }
};

/// Type-safe timer callback wrapper for window timers.
///
/// Uses SelfContainedWorkCallback to bundle the callback function and context data
/// together, providing compile-time type safety and eliminating manual
/// anyopaque casts in callback functions. The work callback variant stores
/// the allocator internally for no-argument destroy().
const WindowTimerCallback = SelfContainedWorkCallback(WindowTimerData);

/// Free a timer wrapper and every handle it owns. EVERY path that frees one
/// goes through here; `wrapper.destroy()` alone leaks the handles.
fn destroyTimer(wrapper: *WindowTimerCallback) void {
    wrapper.getData().release(wrapper.allocator);
    wrapper.destroy();
}

/// Timer initialization step 8's task, steps 8.3-8.5: run the handler in the
/// timer's realm, at the timer's nesting level. A task runs from the event
/// loop, so the realm is entered for it.
fn runTimerTask(data: *WindowTimerData) void {
    engine.runTaskInRealm(data.realm, runTimerSteps, data) catch |err| {
        log.debug("a timer's task did not run: {}", .{err});
    };
}

fn runTimerSteps(opaque_data: ?*anyopaque) void {
    const data: *WindowTimerData = @ptrCast(@alignCast(opaque_data orelse return));

    // The "current timer nesting level" is this timer's level for the DURATION OF
    // THE CALLBACK ONLY, so timers the callback creates nest one deeper. It is
    // restored before the microtask checkpoint the caller performs: per HTML the
    // checkpoint runs after the task's callback returns, so a timer scheduled from a
    // microtask must NOT inherit the task's nesting level and must not be clamped to
    // 4ms. (wpt: html/webappapis/timers/timer-nesting-not-inherited-in-microtask.html)
    const saved_nesting = runtime.timer.nesting_level;
    runtime.timer.nesting_level = data.nesting_level;
    defer runtime.timer.nesting_level = saved_nesting;

    // Runs ahead of any microtask the callback enqueues; see resetNestingMicrotask.
    if (data.realm.agent) |agent| engine.queueMicrotask(agent, resetNestingMicrotask, null) catch {};

    // This handler owns the wrapper for the duration of the callback, so a
    // clearTimeout/clearInterval from inside it defers the free to us.
    data.executing = true;
    defer data.executing = false;

    switch (data.handler) {
        // Step 8.4: invoke handler given arguments and "report", with callback
        // this value set to thisArg (the WindowProxy).
        .function => |function| invokeReporting(data.realm, function, data.arguments),
        // Step 8.5: create a classic script from the string - with the
        // settings object's API base URL, for a Window its document's base
        // URL, which is also where its errors are reported from - and run it.
        .string => |source| {
            const window = realmWindow(data.realm) orelse return;
            // Step 10.8.2's CSP check ran at the call instead
            // (initializeTimer, a stated deviation): a handler here was
            // allowed then.
            const base_url = apiBaseUrl(data.realm, window);
            defer base_url.deinit();
            engine.runClassicScript(data.realm, .{ .string = source }, base_url.url, null, windowReporter(data.realm)) catch |err| switch (err) {
                // Reported for the Window already (step 8.3).
                error.ExceptionReported => {},
                else => log.debug("a timer's string handler did not run: {}", .{err}),
            };
        },
    }
}

/// A Window's API base URL: its document's base URL (HTML 8.1.3.2) - the
/// frozen base URL of its first `<base href>`, else the document's URL - and
/// for an about:blank document, the URL its realm was navigated to.
const ApiBaseUrl = struct {
    url: []const u8,
    /// Set when `url` is a copy the document's allocator made.
    allocator: ?std.mem.Allocator = null,

    fn deinit(self: ApiBaseUrl) void {
        if (self.allocator) |a| a.free(self.url);
    }
};

fn apiBaseUrl(realm: runtime.Context, window: *runtime.Instance) ApiBaseUrl {
    const fallback = ApiBaseUrl{ .url = realm.documentUrl() orelse "" };
    const document = interfaces.Window.get_document(window) catch return fallback;
    const base = interfaces.Node.get_baseURI(document) catch return fallback;
    if (base.len == 0 or std.mem.eql(u8, base, "about:blank")) {
        document.ctx.allocator.free(base);
        return fallback;
    }
    return .{ .url = base, .allocator = document.ctx.allocator };
}

/// Handler function for one-shot timer callbacks (invoked via SelfContainedCallback trampoline)
fn timerHandler(data: *WindowTimerData) void {
    // Step 8.9: remove global's map[id]. Before the run rather than after, so a
    // clearTimeout(id) from inside the callback finds nothing to free under us.
    if (timer_contexts) |*map| {
        _ = map.remove(data.id);
    }

    runTimerTask(data);

    // Run microtasks after the timer callback (per event loop semantics)
    performMicrotaskCheckpoint(data.realm);

    // Destroy the wrapper - this is a one-shot timer, so clean up after execution
    // Get the wrapper pointer from the data pointer (data is embedded in SelfContainedCallback)
    const wrapper: *WindowTimerCallback = @fieldParentPtr("data", data);
    destroyTimer(wrapper);
}

/// Handler function for interval callbacks (invoked via SelfContainedCallback trampoline)
fn intervalHandler(data: *WindowTimerData) void {
    const wrapper: *WindowTimerCallback = @fieldParentPtr("data", data);

    // Check if interval was cancelled
    if (data.cancelled) {
        // unregisterTimerContext could not confirm cancellation (cross-realm), so it
        // left the wrapper alive and handed ownership here. Free it now - this is the
        // last time the timer system will reference it.
        return destroyTimer(wrapper);
    }

    runTimerTask(data);

    // Run microtasks after the timer callback
    performMicrotaskCheckpoint(data.realm);

    // Steps 8.6-8.8: still in the map - not cleared by the callback or its
    // microtasks - so run the timer initialization steps again, given the
    // same id. Step 3 there: the running task is this timer's, so its nesting
    // level is this one's, and step 5 clamps with it; step 9 nests one deeper.
    if (!data.cancelled) {
        if (getTimerInterface()) |timer| {
            const delay: u64 = @intCast(clampTimeout(data.timeout_ms, data.nesting_level));
            data.nesting_level +|= 1;
            const new_timer_id = timer.setTimeout(delay, WindowTimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
            if (new_timer_id != 0) {
                // The id script holds stays the key; only the pending run changes.
                data.current_timer_id = new_timer_id;
                return;
            }
        }
    }

    // Cancelled, or it could not be rescheduled: this was its last run.
    if (timer_contexts) |*map| {
        if (map.get(data.id) == wrapper) _ = map.remove(data.id);
    }
    destroyTimer(wrapper);
}

/// The timer initialization steps for setTimeout and setInterval, after the
/// engine's WebIDL conversion (`runtime.WindowOperations.initializeTimer`).
/// `handler` and every element of `arguments` are handed over.
///
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#timer-initialisation-steps
fn initializeTimer(realm: runtime.Context, handler: runtime.WindowTimerHandler, timeout: i32, arguments: []const runtime.JSValue, repeat: bool) i32 {
    // Owned until the timer takes them.
    var owned = true;
    defer if (owned) {
        switch (handler) {
            .function, .string => |handle| releaseValue(handle),
        }
        for (arguments) |argument| releaseValue(argument);
    };

    // Not in the spec, stated: a string handler is checked by CSP here, at
    // the call, and not by step 10.8.2 when the timer fires
    // (EnsureCSPDoesNotBlockStringCompilation(realm, « », handler, handler,
    // timer, « », handler), whose EvalError the spec reports for the
    // global). An enforced policy that blocks it reports its violation and
    // the call returns 0, scheduling nothing and reporting no exception; a
    // report-only one reports and the timer is set. That is what all three
    // engines do - Blink's DOMTimer::setTimeout/setInterval (IsAllowed:
    // ContentSecurityPolicy::AllowEval, kReport, kWillNotThrowException,
    // then `return 0`), Gecko's nsGlobalWindowInner::SetTimeoutOrInterval
    // (CSPEvalChecker::CheckForWindow: GetAllowsEval, LogViolationDetails,
    // `return 0`) and WebKit's LocalDOMWindow::setTimeout/setInterval
    // (ContentSecurityPolicy::allowEval, `return 0`) - and what WPT asserts:
    // unsafe-eval/eval-scripts-set{Timeout,Interval}-blocked.sub.html expect
    // the id 0, and files that call setTimeout(string) under such a policy
    // expect no error event (the spec's report made testharness end them
    // in ERROR). A blocked interval is thereby checked once, as the engines
    // do. (Step 1's Trusted Types step is not run yet: a TrustedScript
    // reaches here already a string.)
    switch (handler) {
        .function => {},
        .string => |source| if (realmWindow(realm)) |window| {
            const text = engine.convertToDOMString(realm, source, window.ctx.allocator) catch return 0;
            defer window.ctx.allocator.free(text);
            if (!html_mod.code_generation.timerHandlerAllowed(window, text)) return 0;
        },
    }

    const timer = getTimerInterface() orelse return 0;
    const allocator = current_allocator orelse return 0;

    // Step 3: this timer's nesting level is one deeper than the running
    // task's, if that task is a timer's; 0 otherwise.
    const nesting = runtime.timer.nesting_level;
    // Step 4: a negative timeout is 0.
    const timeout_ms: i64 = @max(timeout, 0);

    const kept = allocator.dupe(runtime.JSValue, arguments) catch return 0;
    const wrapper = WindowTimerCallback.create(allocator, if (repeat) &intervalHandler else &timerHandler, .{
        .handler = handler,
        .arguments = kept,
        .realm = realm,
        .is_interval = repeat,
        .timeout_ms = timeout_ms,
        // Steps 9-10.
        .nesting_level = nesting + 1,
    }) catch {
        allocator.free(kept);
        return 0;
    };
    // The wrapper owns them now; destroyTimer releases them.
    owned = false;

    // Step 5: the 4ms clamp past nesting level 5. Steps 11-14: schedule, and
    // return the id.
    const delay: u64 = @intCast(clampTimeout(timeout_ms, nesting));
    const id = scheduleTimer(timer, wrapper, delay) orelse return 0;
    return @intCast(@as(u32, @truncate(id)));
}

/// clearTimeout(id) and clearInterval(id): one algorithm, "clear the timer
/// with id from the map of setTimeout and setInterval IDs", so either clears
/// either kind.
fn clearTimer(realm: runtime.Context, id: i32) void {
    if (id <= 0) return;
    // The map, and nothing but the map, decides what an id names - and it is
    // THIS window's map: an id another window's timer holds names nothing
    // here. The function's realm is the window whose method this is.
    const map = if (timer_contexts) |*m| m else return;
    const wrapper = map.get(@intCast(id)) orelse return;
    if (wrapper.getData().realm != realm) return;
    unregisterTimerContext(@intCast(id));
}

/// Context type for determining which globals to register
pub const ContextType = enum {
    /// Window context (for HTML pages)
    window,
    /// Dedicated worker context
    worker,
    /// Shared worker context
    shared_worker,
    /// Service worker context
    service_worker,
};

/// One page navigation: its realm - a Window's - made in the Browser's agent,
/// which every navigation shares.
pub const Context = struct {
    allocator: std.mem.Allocator,
    /// The agent the page's realm lives in: the Browser's (BORROWED).
    agent: *engine.Agent,
    /// The page's realm, a Window's; null only while it is being made.
    realm: ?runtime.Context = null,
    /// Storage subsystem (shared across navigations)
    storage: *Storage,
    /// The Browser's cookie jar (BORROWED): the page's top-level browsing
    /// context gets it as its Window is made.
    cookie_jar: ?*cookiestore.CookieJar,
    /// Current URL
    url: []const u8,
    /// Context type
    context_type: ContextType,
    /// Whether context is ready for execution
    initialized: bool,
    /// The Browser's timers and event loop, shared by all its pages
    /// (BORROWED); the realm records both.
    timer: ?runtime.TimerInterface,
    event_loop: ?runtime.EventLoop,
    /// Make the realm from the engine's snapshot, when the agent has one.
    from_snapshot: bool,
    /// The Browser's scope and its loop's cross-thread inbox, which the realm
    /// carries (runtime.ContextData.browser_scope, .task_sink). BORROWED.
    browser_scope: ?*runtime.BrowserScope = null,
    task_sink: ?*runtime.TaskSink = null,

    // Singleton instances for cleanup
    window_instance: ?*runtime.Instance = null,
    document_instance: ?*runtime.Instance = null,
    navigator_instance: ?*runtime.Instance = null,
    location_instance: ?*runtime.Instance = null,
    history_instance: ?*runtime.Instance = null,
    performance_instance: ?*runtime.Instance = null,

    // Debug counter for tracking context lifecycle
    var context_id_counter: u32 = 0;

    /// Make the page's realm in `agent` and give it what a page's Window has.
    ///
    /// `agent` is the Browser's agent and `event_loop` its event loop (whose
    /// timers the realm shares; browser/event_loop.zig). `from_snapshot`
    /// restores the realm from the engine's snapshot, when the agent was made
    /// from one; otherwise every interface is defined afresh.
    pub fn init(
        allocator: std.mem.Allocator,
        agent: anytype,
        storage: *Storage,
        cookie_jar: ?*cookiestore.CookieJar,
        url: []const u8,
        event_loop: anytype,
        context_type: ContextType,
        from_snapshot: bool,
        browser_scope: ?*runtime.BrowserScope,
    ) !*Context {
        context_id_counter += 1;
        log.debug("[Context.init] #{d}: {s}", .{ context_id_counter, url });

        const ctx = try allocator.create(Context);
        errdefer allocator.destroy(ctx);

        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        ctx.* = Context{
            .allocator = allocator,
            .agent = @ptrCast(agent),
            .storage = storage,
            .cookie_jar = cookie_jar,
            .url = url_copy,
            .context_type = context_type,
            .initialized = false,
            .timer = if (event_loop) |ev| ev.timerInterface() else null,
            .event_loop = if (event_loop) |ev| ev.eventLoop() else null,
            .from_snapshot = from_snapshot,
            .browser_scope = browser_scope,
            .task_sink = if (event_loop) |ev| ev.taskSink() else null,
        };

        try ctx.createRealm();
        return ctx;
    }

    /// HTML "create a new realm" for the page's Window (engine.createWindowRealm),
    /// then what a Window global has beyond its interfaces: its document,
    /// navigator, location and performance, its timers and animation frames.
    fn createRealm(self: *Context) !void {
        const realm = engine.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = self.allocator,
            .from_snapshot = self.from_snapshot,
            .timer = self.timer,
            .event_loop = self.event_loop,
            .origin = null,
            .create_global_object = createWindow,
            .host = self,
        }) catch |err| {
            log.debug("the page's realm was not made: {}", .{err});
            return error.ContextCreateFailed;
        };
        self.realm = realm;
        // The realm's Browser, and the inbox other threads post its tasks to.
        realm.browser_scope = self.browser_scope;
        realm.task_sink = self.task_sink;

        // __internal and GLOBAL, before the singletons stored in __internal.
        self.setupGlobalAliases() catch |err| {
            log.debug("setupGlobalAliases failed: {} - continuing", .{err});
        };

        try self.registerBrowserGlobals(realm);

        // The timers this realm's Window sets run on the Browser's loop.
        if (self.timer) |timer| setTimerInterface(timer, self.allocator);

        self.initialized = true;
    }

    /// HTML "create a new realm", the customization for the global object: the
    /// page's Window, bound to `global_this` (BORROWED until the realm ends).
    fn createWindow(realm: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        const self: *Context = @ptrCast(@alignCast(host orelse return null));
        const window = interfaces.Window.init(self.allocator, realm) catch |err| {
            log.debug("the page's Window was not made: {}", .{err});
            return null;
        };
        self.window_instance = window;

        // HTML 7.3.1: the Window is its browsing context's active window -
        // what frames[index], contentWindow.parent and the WindowProxy's
        // [[GetOwnProperty]] read.
        if (impls.Window.getInternal(window)) |internal| {
            internal.browsing_context.setActiveWindow(@ptrCast(window));
            // The page's top-level browsing context has the Browser's
            // cookie jar; its frames reach it through it.
            internal.browsing_context.cookie_jar = self.cookie_jar;
        }
        // The global the Window is bound to, for cross-realm access.
        switch (global_this) {
            .handle => |h| impls.Window.setBoundV8Global(window, h.ptr),
            else => {},
        }
        return window;
    }

    fn registerBrowserGlobals(self: *Context, realm: runtime.Context) !void {
        const window = self.window_instance orelse return error.NotInitialized;
        const global: runtime.JSValue = .{ .instance = window };

        switch (self.context_type) {
            .window => try self.registerWindowGlobals(realm, global),
            .worker => try self.registerWorkerGlobals(realm, global),
            else => {},
        }

        // Register common globals (setTimeout, fetch, console, etc.)
        try registerCommonGlobals(realm);
    }

    /// The Window's singletons - Document, Navigator, Location, Performance -
    /// linked to it, and each stored in `__internal` as well (see
    /// setupGlobalAliases). History is made by Window.get_history on first
    /// use, linked to the window's browsing context, whose traversable keeps
    /// the session history (HTML 7.2.5).
    fn registerWindowGlobals(self: *Context, realm: runtime.Context, global: runtime.JSValue) !void {
        const internal = engine.getProperty(realm, global, "__internal") catch |err| {
            log.debug("__internal is not on the global: {}", .{err});
            return error.ObjectNotFound;
        };
        defer internal.release();

        const win = self.window_instance orelse return error.NotInitialized;

        // Document (__internal.document), with the Window and its document
        // each pointing at the other.
        const doc_instance = interfaces.Document.init(self.allocator, realm) catch |err| {
            log.debug("the document singleton was not made: {}", .{err});
            return;
        };
        self.document_instance = doc_instance;
        impls.Window.setDocument(win, doc_instance);
        impls.Document.setDefaultView(doc_instance, win);
        storeInternal(realm, internal.value, "document", doc_instance);

        // Navigator (__internal.navigator).
        const nav_instance = interfaces.Navigator.init(self.allocator, realm) catch |err| {
            log.debug("the navigator was not made: {}", .{err});
            return;
        };
        self.navigator_instance = nav_instance;
        impls.Window.setNavigator(win, nav_instance);
        storeInternal(realm, internal.value, "navigator", nav_instance);

        // Location (__internal.location), which knows its Window.
        const loc_instance = interfaces.Location.init(self.allocator, realm) catch |err| {
            log.debug("the location was not made: {}", .{err});
            return;
        };
        self.location_instance = loc_instance;
        impls.Window.setLocation(win, loc_instance);
        impls.Location.setWindow(loc_instance, win);
        storeInternal(realm, internal.value, "location", loc_instance);

        // Performance (__internal.performance).
        const perf_instance = interfaces.Performance.init(self.allocator, realm) catch |err| {
            log.debug("the performance object was not made: {}", .{err});
            return;
        };
        self.performance_instance = perf_instance;
        impls.Window.setPerformance(win, perf_instance);
        storeInternal(realm, internal.value, "performance", perf_instance);

        // HTML's HTMLDocument: "for historical reasons, Window objects must
        // also have a writable, configurable, non-enumerable property named
        // HTMLDocument whose value is the Document interface object."
        const document_interface = engine.getProperty(realm, global, "Document") catch return;
        defer document_interface.release();
        engine.defineOwnProperty(realm, global, "HTMLDocument", document_interface.value, .{
            .writable = true,
            .enumerable = false,
            .configurable = true,
        }) catch |err| log.debug("HTMLDocument was not defined: {}", .{err});
    }

    /// `__internal[name] = instance` - a plain object's data property, whose
    /// value the engine wraps.
    fn storeInternal(realm: runtime.Context, internal: runtime.JSValue, name: []const u8, instance: *runtime.Instance) void {
        engine.setProperty(realm, internal, name, .{ .instance = instance }) catch |err| {
            log.debug("__internal.{s} was not stored: {}", .{ name, err });
        };
    }

    /// A worker context's globals: `self`, and its WorkerNavigator.
    fn registerWorkerGlobals(self: *Context, realm: runtime.Context, global: runtime.JSValue) !void {
        engine.defineOwnProperty(realm, global, "self", global, .{
            .writable = true,
            .enumerable = true,
            .configurable = true,
        }) catch |err| log.debug("self was not defined: {}", .{err});

        const nav_instance = interfaces.WorkerNavigator.init(self.allocator, realm) catch |err| {
            log.debug("the worker navigator was not made: {}", .{err});
            return;
        };
        engine.setProperty(realm, global, "navigator", .{ .instance = nav_instance }) catch |err| {
            log.debug("navigator was not stored: {}", .{err});
        };
    }

    /// Register common globals (setTimeout, fetch, console, etc.)
    fn registerCommonGlobals(realm: runtime.Context) !void {
        // setTimeout, setInterval, their clears and the animation frame
        // methods, bound by the engine over this file's steps - on this window
        // and on every frame's.
        try engine.installWindowOperations(realm, &window_operations);

        // NOTE: console object is registered via WebIDL namespace binding in snapshot
        // (see bindings.zig initializeNamespaces -> Console.registerGlobal)
        // The native binding provides proper console.log/error/etc with output to stderr

        // NOTE: getComputedStyle is now properly defined on Window.prototype via WebIDL binding.
        // The Window.call_getComputedStyle implementation creates a proper CSSStyleDeclaration
        // with named property handlers for CSS property access (e.g., style.borderStyle).
        // Do NOT register a stub here - it would shadow the proper implementation.

        // addEventListener, removeEventListener and dispatchEvent are EventTarget's
        // WebIDL operations, own properties of the global (WebIDL 3.8, [Global]) as
        // on every frame's window. Native bindings used to overwrite them here -
        // from before those operations were on the global - and they resolved the
        // Window from the realm rather than `this`, returned true for a
        // dispatchEvent argument that is no Event, and swallowed InvalidStateError.
    }

    /// Set up global aliases via JavaScript
    /// Per WebIDL spec, window properties use accessor properties with proper this validation
    fn setupGlobalAliases(self: *Context) !void {
        const setup_script = switch (self.context_type) {
            .window =>
            // Window context: Set up __internal for singleton storage and GLOBAL for WPT tests
            // NOTE: Do NOT set self or window here! They are accessor properties registered by
            // registerPropertiesAsOwnOnObject() via the Window interface. Setting them here
            // would overwrite the accessor with a data property, breaking the getter mechanism.
            // NOTE: Do NOT try to set parent, top, opener, frames, length here!
            // These are read-only accessor properties defined by Window interface bindings.
            // The Window impl handles returning the correct values for these properties.
            \\globalThis.__internal = globalThis.__internal || { isSecureContext: false };
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return true; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return false; }
            \\};
            \\
            \\// NOTE: document, navigator, location, history, performance are exposed via
            \\// the Window interface's attribute getters. We only set up __internal for
            \\// storage, and the Window impl's getters retrieve from there.
            ,
            .worker =>
            // Dedicated worker context: self, navigator, location
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface DedicatedWorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
            .shared_worker, .service_worker =>
            // Shared/Service worker context: only self, no window
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface WorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
        };

        self.runScript(setup_script) catch |err| {
            log.debug("ERROR: Failed to set up global aliases: {}\n", .{err});
            return err;
        };
    }

    /// Options for loadPage
    pub const LoadPageOptions = struct {
        /// Optional script loader for external scripts
        script_loader: ?ScriptLoader = null,
    };

    /// Load page content (fetch, parse, execute)
    ///
    /// Navigation flow per HTML Standard:
    /// 1. Fetch URL content via HTTP
    /// 2. Parse HTML into DOM tree
    /// 3. Execute inline and external scripts (in document order)
    /// 4. Fire DOMContentLoaded event
    /// 5. Fire load event
    pub fn loadPage(self: *Context) !void {
        return self.loadPageWithOptions(.{});
    }

    /// Load page content with options
    pub fn loadPageWithOptions(self: *Context, options: LoadPageOptions) !void {
        // For about:blank, just return with empty document
        if (std.mem.eql(u8, self.url, "about:blank")) {
            return;
        }

        // Step 1: Fetch URL content via HTTP
        //
        // Propagate the navigation error rather than flattening it to
        // `NavigationFailed`. The WPT runner prints whatever comes back here,
        // and one catch-all name made a DNS failure, a refused connection, a
        // TLS error and a missing file read identically in the journal.
        var result = try navigation.fetchUrl(self.allocator, self.url, .{ .cookie_jar = self.cookie_jar });
        defer result.deinit();

        // HTML "create and initialize a Document object": Navigation
        // Timing's "create the navigation timing entry" for the new document,
        // from the navigation's fetch - before its parser, and any of its
        // script, runs.
        if (result.timing) |*timing| {
            const report: fetch.internal.TimingReport = .{
                .timing_info = &timing.timing_info,
                .url = self.url,
                .initiator_type = .other,
                .cache_state = "",
                .body_info = .{ .encoded_size = result.body.len, .decoded_size = result.body.len, .content_encoding = timing.content_encoding },
                .response_status = timing.response_status,
            };
            if (self.realm) |realm| dom_mod.performance_timeline.createNavigationTimingEntry(realm, .{
                .report = &report,
                .redirect_count = timing.redirect_count,
                .navigation_type = .navigate,
            }) catch |err| log.debug("the navigation timing entry was not made: {}", .{err});
        }

        // Step 2: HTML "load a document" - the response's type decides which
        // document it makes, as a navigable container's navigation does
        // (html_core.navigation.document_type).
        const document_type = html_mod.navigation.document_type;
        const computed = try document_type.essence(self.allocator, if (result.content_type.len > 0) result.content_type else "text/html");
        defer self.allocator.free(computed);
        const kind = document_type.classify(computed);
        var synthesized: ?[]u8 = null;
        defer if (synthesized) |markup| self.allocator.free(markup);
        // A text document's encoding: its bytes are decoded before the
        // markup that holds them is made.
        var text_encoding: ?[]const u8 = null;
        const sniffing = html_mod.parser.encoding_sniffing;
        const markup: []const u8 = switch (kind) {
            .html => result.body,
            // "Loading an XML document". Deviation, stated: Crane has no XML
            // parser. An XHTML page is parsed as HTML, as it always was here;
            // any other XML document is left as it is, empty.
            .xml => if (std.mem.eql(u8, computed, "application/xhtml+xml")) result.body else return,
            // "Loading a text document": one pre holding the text, decoded
            // by the type's rules - a BOM, the charset parameter, else the
            // default (the sniffing algorithm without the prescan).
            .text => blk: {
                const sniffed = sniffing.sniff(result.body, .{
                    .transport = sniffing.transportEncoding(self.allocator, result.content_type),
                    .prescan = false,
                });
                text_encoding = sniffing.canonicalName(sniffed.encoding);
                const text = try sniffing.decode(self.allocator, result.body, sniffed.encoding);
                defer self.allocator.free(text);
                synthesized = try document_type.textDocumentMarkup(self.allocator, text);
                break :blk synthesized.?;
            },
            // "Loading a media document": an img, video or audio hosting the
            // resource.
            .media => blk: {
                synthesized = try document_type.mediaDocumentMarkup(self.allocator, self.url, document_type.mediaHostElement(computed));
                break :blk synthesized.?;
            },
            // Handed to external software: the page keeps its document.
            .multipart, .external => return,
        };

        // "Create and initialize a Document object" step 9: the document's
        // policy container is the one "determine navigation params policy
        // container" chose - for a top-level page with no initiator, the
        // response's ("create a policy container from a fetch response"), or
        // a new one for a response from no network. It is the document's
        // before any of its script runs.
        if (self.document_instance) |document| {
            if (result.takePolicyContainer()) |container| dom_mod.policy_containers.set(document, container);
        }

        // Steps 3-5: parse and execute scripts using loadHTML - the full
        // HTML parser with script loading.
        try self.loadHTML(markup, .{
            .base_url = self.url,
            .scripting_enabled = kind == .html or kind == .xml,
            .script_loader = options.script_loader,
            // An HTML page is its response's bytes, decoded with the encoding
            // HTML's sniffing algorithm determines from them and their
            // Content-Type; the markup made for other types is characters.
            .byte_stream = if (kind == .html or kind == .xml) .{ .content_type = result.content_type } else null,
        });
        if (text_encoding) |name| {
            if (self.document_instance) |document| dom_mod.document_internals.setEncoding(document, name) catch {};
        }
        // "Create and initialize a Document object" step 11: its content type
        // is the response's computed type. An XHTML page parsed as HTML keeps
        // the HTML document it was always given.
        if (kind == .text or kind == .media) {
            if (self.document_instance) |document| {
                dom_mod.document_internals.setContentType(document, computed) catch {};
            }
        }
    }

    // ============================================================================
    // HTML Loading and Parsing
    // ============================================================================

    /// Script loader callback type for external script loading
    /// Returns script content for the given URL, or null if loading failed
    pub const ScriptLoaderFn = @import("html").parser_script_execution.ScriptLoaderFn;

    /// Script loader interface for customizing how external scripts are loaded
    pub const ScriptLoader = @import("html").scripted_parser.ScriptLoader;

    /// Options for HTML loading
    pub const LoadHTMLOptions = struct {
        /// Base URL for resolving relative URLs
        base_url: []const u8,
        /// Enable script execution during parsing (default: true)
        scripting_enabled: bool = true,
        /// Custom script loader (optional)
        /// If null, external scripts will use default HTTP fetch
        script_loader: ?ScriptLoader = null,
        /// The content is the page's byte stream, to decode with the encoding
        /// HTML's encoding sniffing algorithm determines; null when it is
        /// characters already.
        byte_stream: ?html_mod.scripted_parser.ByteStream = null,
    };

    /// Load and parse HTML content into the document
    ///
    /// This method:
    /// 1. Sets up the document URL and Window origin
    /// 2. Parses HTML using HTMLParser.parseHTMLWithScripting()
    /// 3. Executes inline and external scripts during parsing
    /// 4. Initializes iframe browsing contexts
    /// 5. Fires DOMContentLoaded after parsing
    ///
    /// Per HTML Standard §13.2.7 "The end":
    /// - Scripts execute during parsing (inline and deferred)
    /// - DOMContentLoaded fires after parsing completes
    ///
    /// ## Example
    /// ```zig
    /// const html =
    ///     \\<html>
    ///     \\<body>
    ///     \\<div id="test">Hello</div>
    ///     \\<script>
    ///     \\  window.found = document.getElementById('test').textContent;
    ///     \\</script>
    ///     \\</body>
    ///     \\</html>
    /// ;
    /// try ctx.loadHTML(html, .{ .base_url = "about:blank" });
    /// const result = try ctx.evaluateScript("window.found");
    /// // result === "Hello"
    /// ```
    pub fn loadHTML(self: *Context, html_content: []const u8, options: LoadHTMLOptions) !void {
        const runtime_ctx = self.realm orelse return error.NotInitialized;

        // The realm's document URL, for fetch's relative URL resolution.
        runtime_ctx.setDocumentUrl(options.base_url) catch |err| {
            log.debug("Warning: Failed to set document URL: {}\n", .{err});
        };

        // Update location object with the document's URL
        try self.setUrl(options.base_url);

        // Set the Window's origin from the base URL for storage access
        // This is needed for sessionStorage/localStorage to work properly
        if (self.window_instance) |win| {
            if (std.mem.startsWith(u8, options.base_url, "http://") or std.mem.startsWith(u8, options.base_url, "https://")) {
                // Extract origin from URL (scheme://host:port)
                const scheme_end = std.mem.indexOf(u8, options.base_url, "://") orelse options.base_url.len;
                const after_scheme = options.base_url[scheme_end + 3 ..];
                const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
                const origin = options.base_url[0 .. scheme_end + 3 + path_start];
                impls.Window.setOrigin(win, origin) catch |err| {
                    log.debug("Warning: Failed to set Window origin: {}\n", .{err});
                };
            }
        }

        // Get existing document instance - it was created during context initialization
        // and is already registered in V8. We pass it to the parser so scripts can
        // access the DOM via document.getElementById(), querySelector(), etc.
        const document = self.document_instance orelse {
            log.debug("ERROR: document_instance is null - context must be initialized first\n", .{});
            return error.NotInitialized;
        };

        // Create HTMLParser script loader
        const HTMLParser = impls.HTMLParser;

        // Parse HTML into the existing document (already registered in V8)
        var parser_canceled = false;
        _ = HTMLParser.parseHTMLWithScripting(
            self.allocator,
            runtime_ctx,
            html_content,
            .{
                .scripting_enabled = options.scripting_enabled,
                .parser_canceled = &parser_canceled,
                .base_url = options.base_url,
                .script_loader = options.script_loader,
                .existing_document = document,
                .byte_stream = options.byte_stream,
            },
        ) catch |err| {
            log.debug("HTML parse error: {}\n", .{err});
            return error.ParseError;
        };
        if (parser_canceled) return;

        // Initialize browsing contexts for any iframes in the document
        // This is necessary for window.frames[N] to work properly
        self.initializeIframeBrowsingContexts(document) catch |err| {
            // Non-fatal - some iframes may not need initialization
            log.debug("Warning: Failed to initialize iframe browsing contexts: {}\n", .{err});
        };

        // DOMContentLoaded and load (HTML §13.2.7 "the end" steps 6 and 9)
        // are the parser's: it queued them as tasks when parsing stopped, with
        // readiness and pageshow around them (dom.document_lifecycle). Firing
        // load here as well, synchronously, ran every load listener twice.
    }

    /// Initialize browsing contexts for all iframes in a document.
    /// This triggers lazy initialization of iframe browsing contexts by accessing
    /// their contentWindow property, which is required for window.frames[N] to work.
    fn initializeIframeBrowsingContexts(self: *Context, document: *runtime.Instance) !void {
        _ = self;

        // Get all iframe elements using getElementsByTagName
        const iframes = try interfaces.Document.call_getElementsByTagName(
            document,
            runtime.DOMString.initInterned("iframe"),
        );
        defer interfaces.HTMLCollection.deinit(iframes);

        // Get the collection length
        const length = try interfaces.HTMLCollection.get_length(iframes);
        if (length == 0) return;

        // Access contentWindow on each iframe to trigger browsing context initialization
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const element = try interfaces.HTMLCollection.call_item(iframes, i);
            if (element) |iframe_elem| {
                // Access contentWindow to trigger IFrameIntegration.ensureBrowsingContext
                _ = interfaces.HTMLIFrameElement.get_contentWindow(iframe_elem) catch |err| {
                    log.debug("Warning: Failed to initialize iframe {d}: {}\n", .{ i, err });
                };
            }
        }
    }

    /// Set the context URL (updates location object)
    fn setUrl(self: *Context, url: []const u8) !void {
        // Update internal URL
        // IMPORTANT: Check if url points to self.url (same slice) to avoid use-after-free.
        // This can happen when loadHTML is called with base_url = self.url
        if (url.ptr == self.url.ptr) {
            // URL is already set to this value, nothing to do
            return;
        }
        // Duplicate first, then free old to avoid use-after-free if url somehow
        // references memory that would be affected by the free
        const new_url = try self.allocator.dupe(u8, url);
        self.allocator.free(self.url);
        self.url = new_url;

        // Note: Location object URL is set during context initialization
        // and via JavaScript. Direct impl access would require Location.setHref
        // which isn't currently exposed. For now, the URL is tracked in Context.url.
        _ = self.location_instance;
    }

    /// Evaluate `script` - host code: the harness, WebDriver, the REPL - for
    /// its effects. What it throws is logged, and fails the call with
    /// `error.ExceptionReported`.
    pub fn runScript(self: *Context, script: []const u8) !void {
        const realm = self.realm orelse return error.NotInitialized;
        try engine.runClassicScript(realm, .{ .utf8 = script }, "", null, hostScriptReporter());
    }

    /// Evaluate `script` (host code) and return its completion value, OWNED:
    /// `release` it - a leaked one that holds an object keeps the page alive.
    /// Use `runScript` to discard it. What it throws is logged, and fails the
    /// call with `error.ExceptionReported`.
    pub fn evaluateScript(self: *Context, script: []const u8) !engine.Owned {
        const realm = self.realm orelse return error.NotInitialized;
        return engine.evaluateClassicScript(realm, .{ .utf8 = script }, "", null, hostScriptReporter());
    }

    /// Evaluate `script` (host code) and return its completion value's
    /// ToString, allocated with `allocator`.
    pub fn evaluateScriptToString(self: *Context, script: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const realm = self.realm orelse return error.NotInitialized;
        return engine.evaluateClassicScriptToString(realm, .{ .utf8 = script }, "", null, allocator, hostScriptReporter());
    }

    /// A host script is not the page's: what it throws is a runner-level
    /// failure, logged at warn - the runner's level - and never reported to
    /// the page's Window.
    fn hostScriptReporter() engine.Reporter {
        return .{ .report = logHostScriptException };
    }

    fn logHostScriptException(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        log.warn("a host script threw: {s} ({s}:{d}:{d})", .{ info.message, info.filename, info.lineno, info.colno });
    }

    /// The end of the page: its threadlocal state, its timers, then its realm
    /// (engine.destroyWindowRealm, which follows Blink's
    /// LocalWindowProxy::DisposeContext).
    pub fn deinit(self: *Context) void {
        log.debug("[Context.deinit] {s}", .{self.url});

        // Clean up threadlocal state that accumulates across context navigations.
        // These must be cleaned up to prevent state accumulation that causes
        // timeouts in sequential test execution.

        // Clean up custom elements threadlocal state (reactions_stack, element_reaction_queues)

        // Clean up mutation observer threadlocal state (global_agent)
        mutation_observer_algorithms.resetAgent();

        // Clear instance lifecycle registry entries
        // (the registry itself persists but entries for this context's instances should be cleaned)
        instance_lifecycle.clearAll();

        // Clear timer interface and cancel all pending timers, before the
        // realm ends, so that none fires into it.
        clearTimerInterface();

        // NOTE: Do NOT explicitly deinit singleton instances here! The
        // realm's end cleans up its wrapper cache, which frees each instance;
        // deinit'ing them here as well is a double free.
        self.document_instance = null;
        self.navigator_instance = null;
        self.location_instance = null;
        self.history_instance = null;
        self.performance_instance = null;

        // The end of the page's realm (engine.destroyWindowRealm): its
        // Window, document and frames torn down, its WindowProxy detached,
        // its context released - Blink's LocalWindowProxy::DisposeContext
        // order. Its document is destroyed first: the unloading document
        // cleanup steps other specifications define run for it (its frames'
        // run as their realms end, clearWindowState).
        if (self.realm) |realm| {
            dom_mod.unloading_cleanup.run(realm);
            engine.destroyWindowRealm(realm, .global_detached);
            self.realm = null;
        }

        self.allocator.free(self.url);
        self.initialized = false;
    }
};

// ============================================================================
// Animation frames
// ============================================================================

/// Schedule the single next-frame timer, if callbacks are waiting and none is
/// already pending. One timer per FRAME, never one per callback.
fn scheduleAnimationFrame() void {
    const state = if (animation_frames) |*s| s else return;
    if (state.timer_id != null) return;
    // A document turn may add callbacks to a later document this frame, but
    // nested loop pumping must never start another rendering turn.
    if (state.dispatch_token != null) return;
    if (state.pending.items.len == 0) return;
    const timer = getTimerInterface() orelse return;
    const id = timer.setTimeout(FRAME_INTERVAL_MS, animationFrameHandler, null);
    // 0 is the failure sentinel; leaving timer_id null lets a later rAF retry.
    if (id != 0) state.timer_id = id;
}

/// A removed/replaced Window has no active navigable; no future frame can
/// invoke its callback map. The realm itself may remain callable from script.
/// A live navigable with no document yet is temporary, and keeps callbacks.
fn animationFrameRealmIsTerminal(realm: runtime.Context) bool {
    if (!realm.hasEngine()) return true;
    const window = realmWindow(realm) orelse return true;
    if (instance_lifecycle.isCleanupStarted(window)) return true;
    const navigable = html_mod.window.BrowsingContext.ofWindow(window) orelse return true;
    if (navigable.is_closed or navigable.orphaned) return true;
    if (navigable.active_document) |ptr| {
        const document: *runtime.Instance = @ptrCast(@alignCast(ptr));
        if (runtime.SlabAllocator.generationOf(document) == runtime.SlabAllocator.dead_generation) return true;
        if (instance_lifecycle.isCleanupStarted(document)) return true;
    }
    return false;
}

/// The rAF map belongs to the associated Document, not a reusable Window.
/// When the Window adopts its successor, retire the old document's owners.
fn animationFrameTargetReplaced(entry: AnimationFrameEntry) bool {
    const target = entry.target_document orelse return false;
    if (entry.target_document_generation == runtime.SlabAllocator.dead_generation) return true;
    if (runtime.SlabAllocator.generationOf(target) != entry.target_document_generation) return true;
    const window = realmWindow(entry.realm) orelse return true;
    const navigable = html_mod.window.BrowsingContext.ofWindow(window) orelse return true;
    // A temporarily unassigned active document is deferred. A different
    // document is a permanent replacement of this entry's target map.
    const active = navigable.active_document orelse return false;
    return active != @as(*anyopaque, @ptrCast(target));
}

/// HTML update-rendering steps 2–3: eligibility is a document decision made
/// before any callback, distinct from permanent destruction of its target.
fn documentDispositionForAnimationFrame(realm: runtime.Context) AnimationFrameDisposition {
    if (animationFrameRealmIsTerminal(realm)) return .terminal;
    const window = realmWindow(realm) orelse return .terminal;
    const navigable = html_mod.window.BrowsingContext.ofWindow(window) orelse return .terminal;
    const document: *runtime.Instance = @ptrCast(@alignCast(navigable.active_document orelse return .deferred));
    if (!dom_mod.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return .deferred;
    if ((interfaces.Document.get_visibilityState(document) catch return .deferred) == ._hidden_) return .deferred;
    if (dom_mod.document_rendering.isBlocked(document)) return .deferred;
    return .ready;
}

/// A token is borrowed from the handler's stack, and covers all document
/// turns. Re-read it after JS: teardown can replace the threadlocal state.
fn animationFrameDispatchState(token: *const u8) ?*AnimationFrameState {
    const state = if (animation_frames) |*s| s else return null;
    if (state.dispatch_token != token) return null;
    return state;
}

/// Capture document eligibility globally, then snapshot handles separately
/// when each selected document's tree-ordered turn begins (HTML step 14).
fn animationFrameHandler(_: ?*anyopaque) void {
    const state = if (animation_frames) |*s| s else return;
    const allocator = current_allocator orelse return;
    state.timer_id = null;
    if (state.dispatch_token != null) return;
    // Terminal/canceled owners need no allocation to leave the map, even
    // when reserving the next document snapshot would fail.
    retireAnimationFrameCallbacks(state);
    if (state.pending.items.len == 0) return;

    var documents = collectAnimationFrameDocuments(allocator, state.pending.items[0].realm) catch {
        scheduleAnimationFrame();
        return;
    };
    defer documents.deinit(allocator);

    var token: u8 = 0;
    state.dispatch_token = &token;
    defer if (animationFrameDispatchState(&token)) |current| {
        current.running = &.{};
        current.dispatch_token = null;
        retireAnimationFrameCallbacks(current);
        scheduleAnimationFrame();
    };

    // Preserve the existing shared frame clock. Each document's relative time
    // origin remains a separate timing concern from callback ordering.
    const elapsed = clock.monotonicMillis() - animation_frame_origin_ms;
    const timestamp = runtime.JSValue{ .number = @floatFromInt(if (elapsed < 0) 0 else elapsed) };
    var last_realm: ?runtime.Context = null;
    for (documents.items) |document| {
        const current = animationFrameDispatchState(&token) orelse break;
        // Removal cancels a turn; adding/removing a render blocker does not
        // recalculate the eligibility captured before JS began.
        if (!document.current()) continue;
        var batch = takeAnimationFrameBatch(allocator, current, document.realm) catch break;
        defer batch.deinit(allocator);
        current.running = batch.items;
        defer if (animationFrameDispatchState(&token)) |live_state| {
            live_state.running = &.{};
        };

        for (batch.items) |*entry| {
            defer entry.deinit();
            if (entry.cancelled or animationFrameDispatchState(&token) == null) continue;
            if (!document.current() or animationFrameTargetReplaced(entry.*)) continue;
            // HTML run-animation-callbacks step 3.2: remove the handle before
            // JS so cancellation of an already-invoked handle is a no-op.
            entry.consumed = true;
            invokeReporting(entry.realm, entry.callback, &.{timestamp});
            last_realm = entry.realm;
        }
    }
    if (animationFrameDispatchState(&token) != null) {
        if (last_realm) |realm| if (realm.hasEngine()) performMicrotaskCheckpoint(realm);
    }
}

/// requestAnimationFrame(callback) - HTML "animation frames", step 2 onwards,
/// after the engine's conversion (`runtime.WindowOperations`). `callback` is
/// handed over.
fn requestAnimationFrame(realm: runtime.Context, callback: runtime.JSValue) u32 {
    const allocator = current_allocator orelse {
        releaseValue(callback);
        return 0;
    };

    if (animation_frames == null) animation_frames = .{};
    const state = &animation_frames.?;

    const handle = state.next_handle;
    if (animationFrameRealmIsTerminal(realm)) {
        // A saved removed Window remains callable, but retaining an engine
        // callback here would root a realm no rendering turn can visit.
        state.next_handle += 1;
        releaseValue(callback);
        return handle;
    }
    const window = realmWindow(realm) orelse unreachable;
    const navigable = html_mod.window.BrowsingContext.ofWindow(window) orelse unreachable;
    const target: ?*runtime.Instance = if (navigable.active_document) |document| @ptrCast(@alignCast(document)) else null;
    state.pending.append(allocator, .{
        .handle = handle,
        .callback = callback,
        .realm = realm,
        .target_document = target,
        .target_document_generation = if (target) |document| runtime.SlabAllocator.generationOf(document) else 0,
    }) catch {
        releaseValue(callback);
        return 0;
    };
    state.next_handle += 1;

    scheduleAnimationFrame();
    return handle;
}

/// cancelAnimationFrame(handle). An unknown handle must do nothing.
fn cancelAnimationFrame(realm: runtime.Context, handle: u32) void {
    const state = if (animation_frames) |*s| s else return;
    cancelAnimationFrameIn(state, realm, handle);
}

fn cancelAnimationFrameIn(state: *AnimationFrameState, realm: runtime.Context, handle: u32) void {

    // Mark rather than remove: the batch may already be running, and removing
    // from under the loop in animationFrameHandler would shift its indices.
    // The frame in progress first: a callback cancelling a sibling registered
    // for the same frame is the case `pending` alone cannot answer.
    //
    // A handle names a callback in THIS window's map only, so another
    // window's callback with that handle is not cancelled.
    for (state.running) |*entry| {
        if (!entry.consumed and entry.handle == handle and entry.realm == realm) {
            entry.cancelled = true;
            return;
        }
    }
    for (state.pending.items) |*entry| {
        if (entry.handle == handle and entry.realm == realm) {
            entry.cancelled = true;
            return;
        }
    }
}

test "a browser started without a snapshot builds its realm afresh and runs a page" {
    // JavaScriptCore has no snapshots, so this is the startup path it runs on:
    // every WebIDL interface defined afresh on the realm's global
    // (engine.createWindowRealm with from_snapshot false). The WebDriver
    // session starts its browser this way too.
    const allocator = std.testing.allocator;
    const Browser = @import("Browser.zig").Browser;
    const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try std.testing.expect(!browser.isUsingSnapshot());

    const ctx = browser.current_context orelse return error.NoContext;
    try ctx.loadHTML(
        \\<!doctype html><title>start</title><div id=d>parsed</div>
        \\<script>
        \\  var seen = document.getElementById('d').textContent;
        \\  setTimeout(function () {
        \\    seen += '|timer';
        \\    requestAnimationFrame(function (now) {
        \\      globalThis.result = document.title + '|' + seen + '|frame:' + typeof now;
        \\    });
        \\  }, 0);
        \\</script>
    , .{ .base_url = "https://example.test/page.html" });
    try browser.runEventLoop(500);
    // The parser, a timer and an animation frame ran in the page's realm.
    const result = try ctx.evaluateScriptToString("globalThis.result", allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("start|parsed|timer|frame:number", result);

    // The global is the page's Window, its members its own (WebIDL 3.8).
    const shape = try ctx.evaluateScriptToString("[globalThis instanceof Window, self === globalThis, typeof addEventListener, document instanceof Document].join()", allocator);
    defer allocator.free(shape);
    try std.testing.expectEqualStrings("true,true,function,true", shape);
}
