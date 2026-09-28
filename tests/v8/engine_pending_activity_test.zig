//! Why a wrapper is held: keepPlatformObjectAlive / releasePlatformObject, and
//! the wrapper cache's reasons for holding a wrapper strongly
//! (wrapper_cache.zig `Holds`, `shouldBeStrong`).
//!
//! A platform object with pending activity - a running Worker - must outlive
//! whatever script holds of it: Blink's ActiveScriptWrappable keeps the wrapper
//! alive while HasPendingActivity() is true, and only while it is. Crane's
//! first version held the wrapper with holdStrong, a window's document's
//! one-way hold, so a page that started and terminated many Workers pinned
//! every one until the realm ended. Each reason to hold a wrapper is now its
//! own flag, and the wrapper is weak only when no reason remains.
//!
//! Real V8, real collections: a full GC (LowMemoryNotification) runs the weak
//! callback of every wrapper nothing holds, and the callback runs the
//! instance's deinit - which is what these tests count.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const WrapperCache = v8.WrapperCache;

var isolate_once: ?*ffi.Isolate = null;
var data_once: ?*runtime.ContextData = null;
var cache_once: ?*WrapperCache = null;

/// An instance as (address, slab generation): a freed slot is reissued to the
/// next instance, so the address alone does not say which one it was.
const Made = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Made {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }
};

/// Instances whose deinit ran - the weak callback's onObjectFreed.
var freed: std.ArrayListUnmanaged(Made) = .empty;

fn countingDeinit(instance: *runtime.Instance) void {
    freed.append(std.heap.page_allocator, Made.of(instance)) catch {};
}

const mock_methods: u8 = 0;
/// An interface nobody owns (not a node, not a streams object, not a window's
/// Location): its wrapper takes the weak default.
const mock_vtable = runtime.VTable{
    .name = "MockPendingActivity",
    .deinit = countingDeinit,
    .methods_ptr = &mock_methods,
};
var mock_state: u64 = 0;

fn setup() !void {
    if (data_once != null) return;
    runtime.SlabAllocator.init(std.heap.page_allocator);
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
    data.agent = @ptrCast(isolate);
    const cache = try std.heap.page_allocator.create(WrapperCache);
    cache.* = try WrapperCache.init(std.heap.page_allocator, @ptrCast(context));
    data.setV8WrapperCacheStorage(@ptrCast(cache));
    isolate_once = isolate;
    data_once = data;
    cache_once = cache;
}

/// A new instance of the realm, wrapped: a real V8 object, owned by the
/// cache - as the binding leaves a platform object script has seen.
fn wrapped() !Made {
    const made = try unwrapped();
    try wrap(made);
    return made;
}

/// A new instance of the realm that script has not seen: no wrapper.
fn unwrapped() !Made {
    const instance = try runtime.SlabAllocator.get().alloc(&mock_vtable);
    instance.state = @ptrCast(&mock_state);
    instance.ctx = data_once.?;
    return Made.of(instance);
}

fn wrap(made: Made) !void {
    const wrapper = ffi.v8_Object_New(isolate_once.?) orelse return error.ObjectFailed;
    try cache_once.?.set(made.instance, @ptrCast(wrapper), @ptrCast(isolate_once.?));
}

fn collect() void {
    ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
}

fn wasFreed(made: Made) bool {
    for (freed.items) |f| if (f.instance == made.instance and f.generation == made.generation) return true;
    return false;
}

fn isStrong(made: Made) bool {
    const entry = cache_once.?.cache.get(made.instance) orelse return false;
    return entry.strong;
}

fn isCached(made: Made) bool {
    return cache_once.?.get(made.instance) != null;
}

test "a wrapper nothing holds is weak, and a full GC frees its instance" {
    try setup();
    const plain = try wrapped();
    // The predicate's default: no reason, not a node, never held - weak.
    try std.testing.expect(!isStrong(plain));
    collect();
    try std.testing.expect(wasFreed(plain));
}

test "a kept wrapper survives a full GC; released, it is collected and its deinit runs" {
    try setup();
    const worker = try wrapped();
    v8.worker_realm.keepPlatformObjectAlive(worker.instance);
    try std.testing.expect(isStrong(worker));
    collect();
    try std.testing.expect(!wasFreed(worker));
    try std.testing.expect(isCached(worker));

    v8.worker_realm.releasePlatformObject(worker.instance);
    try std.testing.expect(!isStrong(worker));
    collect();
    try std.testing.expect(wasFreed(worker));
}

test "releasing twice, or what was never kept, changes nothing" {
    try setup();
    const never_kept = try wrapped();
    v8.worker_realm.releasePlatformObject(never_kept.instance);
    v8.worker_realm.releasePlatformObject(never_kept.instance);
    try std.testing.expect(!isStrong(never_kept));

    const kept = try wrapped();
    v8.worker_realm.keepPlatformObjectAlive(kept.instance);
    v8.worker_realm.keepPlatformObjectAlive(kept.instance);
    v8.worker_realm.releasePlatformObject(kept.instance);
    v8.worker_realm.releasePlatformObject(kept.instance);
    try std.testing.expect(!isStrong(kept));
    collect();
    try std.testing.expect(wasFreed(never_kept));
    try std.testing.expect(wasFreed(kept));
}

test "releasing pending activity leaves a wrapper held for another reason" {
    try setup();
    // A window's document's hold (holdStrong) and pending activity are
    // separate reasons: ending one leaves the other.
    const both = try wrapped();
    v8.wrapper_cache_mod.holdStrong(both.instance);
    v8.worker_realm.keepPlatformObjectAlive(both.instance);
    v8.worker_realm.releasePlatformObject(both.instance);
    try std.testing.expect(isStrong(both));
    collect();
    try std.testing.expect(!wasFreed(both));
    try std.testing.expect(isCached(both));
}

test "a hold placed before the wrapper exists is taken by the wrapper when it is made" {
    try setup();
    // A timeout signal's timer is armed before the binding wraps the signal.
    const early = try unwrapped();
    v8.worker_realm.keepPlatformObjectAlive(early.instance);
    try wrap(early);
    try std.testing.expect(isStrong(early));
    collect();
    try std.testing.expect(!wasFreed(early));
    v8.worker_realm.releasePlatformObject(early.instance);
    collect();
    try std.testing.expect(wasFreed(early));

    // Released before it was wrapped: nothing is left to take.
    const brief = try unwrapped();
    v8.worker_realm.keepPlatformObjectAlive(brief.instance);
    v8.worker_realm.releasePlatformObject(brief.instance);
    try wrap(brief);
    try std.testing.expect(!isStrong(brief));
    collect();
    try std.testing.expect(wasFreed(brief));
}

test "a hold recorded for a freed instance is not inherited by its slot's next occupant" {
    try setup();
    const first = try unwrapped();
    v8.worker_realm.keepPlatformObjectAlive(first.instance);
    // The instance goes without ever being wrapped, and its slot is reissued.
    runtime.SlabAllocator.get().free(first.instance);
    const second = try unwrapped();
    try std.testing.expectEqual(first.instance, second.instance);
    try wrap(second);
    try std.testing.expect(!isStrong(second));
    collect();
    try std.testing.expect(wasFreed(second));
}

// The protocol's operations are the table's: `engine` here names the table,
// so the facade is `protocol`.
const protocol = @import("engine");

test "protocol: keepPlatformObjectAlive holds a wrapper through a full GC, and releasePlatformObject ends the hold" {
    try setup();
    const worker = try wrapped();
    protocol.keepPlatformObjectAlive(worker.instance);
    try std.testing.expect(isStrong(worker));
    collect();
    try std.testing.expect(!wasFreed(worker));

    protocol.releasePlatformObject(worker.instance);
    try std.testing.expect(!isStrong(worker));
    collect();
    try std.testing.expect(wasFreed(worker));
}
