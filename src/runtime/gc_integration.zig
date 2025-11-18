//! GC integration for JavaScript engine
//!
//! This module provides callbacks for JavaScript engine garbage collectors.
//! It handles:
//! - Object finalization (onObjectFreed)
//! - GC sweep phase (onGCSweep)
//! - Memory lifecycle coordination between GC and allocators
//!
//! Supported JavaScript engines:
//! - V8 (Chrome, Node.js)
//! - JavaScriptCore (Safari, Bun)
//! - SpiderMonkey (Firefox)
//!
//! Thread safety: Callbacks are called from GC thread
//! Memory model: Two-phase cleanup (deinit resources, then batch free memory)

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

/// GC finalizer callback - called when JS engine garbage collects an object
///
/// This is called by the JavaScript engine's GC when it determines an object
/// is no longer reachable. The callback must:
/// 1. Call the type-specific deinit function to clean up owned resources
/// 2. Return the Instance handle to the slab allocator
/// 3. NOT free FullState memory (arena handles that in batch)
///
/// Signature: extern "C" fn(user_data: ?*anyopaque) void
///
/// JavaScript engines register this as the finalizer when creating objects:
///   // V8 example:
///   v8::External::New(isolate, instance);
///   object->SetAlignedPointerInInternalField(0, instance);
///   // Register finalizer:
///   object.SetWeak(instance, onObjectFreed, v8::WeakCallbackType::kParameter);
///
/// Thread safety: Called from GC thread, must not allocate or access shared state
pub fn onObjectFreed(user_data: ?*anyopaque) callconv(.c) void {
    const inst = @as(*Instance, @ptrCast(@alignCast(user_data orelse return)));

    // Step 1: Call type-specific deinit to clean up owned resources
    // (strings, arrays, etc. allocated by the implementation)
    if (inst.vtable.deinit_fn) |deinit| {
        deinit(inst.state); // Calls Node.deinit_wrapper → Node.deinit
    }

    // Step 2: FullState memory is NOT freed here
    // The ArenaAllocator will batch-free all FullState memory during onGCSweep

    // Step 3: Return Instance handle to slab allocator
    SlabAllocator.get().free(inst);
}

/// GC sweep callback - called after JS engine completes a GC sweep
///
/// This is called by the JavaScript engine after it has completed a full
/// GC sweep and finalized all dead objects. At this point:
/// - All onObjectFreed callbacks have been called
/// - All type-specific deinit functions have run
/// - Owned resources have been cleaned up
///
/// Now we can batch-free all FullState memory in one operation by
/// resetting the arena allocator.
///
/// Signature: extern "C" fn() void
///
/// JavaScript engines call this after GC sweep:
///   // V8 example:
///   isolate->AddGCEpilogueCallback(onGCSweep, v8::GCType::kGCTypeAll);
///
/// Thread safety: Called from GC thread, must not allocate
pub fn onGCSweep() callconv(.c) void {
    // Reset arena to batch-free ALL FullState memory at once
    // This is much faster than individual frees
    ArenaAllocator.get().reset();
}

/// Register GC callbacks with JavaScript engine (engine-specific)
///
/// This is a helper that would be called during engine initialization.
/// The actual implementation depends on which JavaScript engine is used.
///
/// Example for V8:
///   extern fn registerV8Callbacks(isolate: *v8.Isolate) void;
///
/// Example for JavaScriptCore:
///   extern fn registerJSCCallbacks(ctx: *JSC.JSContextRef) void;
pub fn registerCallbacks() void {
    // This is a placeholder - actual implementation depends on JS engine
    // In practice, this would be implemented in the JS engine binding layer
    @panic("registerCallbacks must be implemented for specific JS engine");
}

/// Statistics for GC integration
pub const GCStats = struct {
    /// Total objects finalized
    objects_finalized: usize = 0,
    /// Total GC sweeps
    gc_sweeps: usize = 0,
    /// Total bytes freed by arena resets
    total_bytes_freed: usize = 0,

    /// Global stats instance
    var global: GCStats = .{};

    /// Get the global stats
    pub fn get() *GCStats {
        return &global;
    }

    /// Reset stats
    pub fn reset() void {
        global = .{};
    }
};

/// Instrumented version of onObjectFreed for testing/debugging
pub fn onObjectFreedInstrumented(user_data: ?*anyopaque) callconv(.c) void {
    GCStats.get().objects_finalized += 1;
    onObjectFreed(user_data);
}

/// Instrumented version of onGCSweep for testing/debugging
pub fn onGCSweepInstrumented() callconv(.c) void {
    const stats = GCStats.get();
    stats.gc_sweeps += 1;

    // Track bytes before reset
    const arena_stats = ArenaAllocator.get().stats();
    stats.total_bytes_freed += arena_stats.total_bytes_allocated;

    onGCSweep();
}

// Unit tests
const testing = std.testing;
const VTable = @import("instance.zig").VTable;
const MethodMap = @import("instance.zig").MethodMap;

test "onObjectFreed calls deinit_fn" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    var deinit_called = false;

    const TestImpl = struct {
        fn deinit(state: *anyopaque) void {
            const called: *bool = @ptrCast(@alignCast(state));
            called.* = true;
        }
    };

    // Create instance
    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = &TestImpl.deinit,
        .fns = methods,
    };

    const inst = try SlabAllocator.get().alloc(&vtable);
    inst.state = @ptrCast(&deinit_called);

    // Call finalizer
    onObjectFreed(inst);

    // Verify deinit was called
    try testing.expect(deinit_called);
}

test "onObjectFreed handles null user_data" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    // Should not crash
    onObjectFreed(null);
}

test "onObjectFreed handles null deinit_fn" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    const inst = try SlabAllocator.get().alloc(&vtable);
    inst.state = undefined;

    // Should not crash even without deinit_fn
    onObjectFreed(inst);
}

test "onGCSweep resets arena" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    // Allocate some items
    _ = try arena.create(u32);
    _ = try arena.create(u64);
    _ = try arena.alloc(u8, 100);

    const stats_before = arena.stats();
    try testing.expectEqual(@as(usize, 3), stats_before.total_allocations);

    // Call GC sweep
    onGCSweep();

    const stats_after = arena.stats();
    try testing.expectEqual(@as(usize, 3), stats_after.total_allocations); // Cumulative

    // Can still allocate after sweep
    const item = try arena.create(u32);
    item.* = 42;
    try testing.expectEqual(@as(u32, 42), item.*);
}

test "onObjectFreedInstrumented increments stats" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    GCStats.reset();

    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    const inst1 = try SlabAllocator.get().alloc(&vtable);
    const inst2 = try SlabAllocator.get().alloc(&vtable);

    onObjectFreedInstrumented(inst1);
    onObjectFreedInstrumented(inst2);

    const stats = GCStats.get();
    try testing.expectEqual(@as(usize, 2), stats.objects_finalized);
}

test "onGCSweepInstrumented increments stats" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    GCStats.reset();

    onGCSweepInstrumented();
    onGCSweepInstrumented();

    const stats = GCStats.get();
    try testing.expectEqual(@as(usize, 2), stats.gc_sweeps);
}

test "GCStats.reset clears stats" {
    GCStats.reset();

    const stats = GCStats.get();
    stats.objects_finalized = 10;
    stats.gc_sweeps = 5;

    GCStats.reset();

    try testing.expectEqual(@as(usize, 0), stats.objects_finalized);
    try testing.expectEqual(@as(usize, 0), stats.gc_sweeps);
}
