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
//!
//! ## Typed GC Callback Support
//!
//! For type-safe GC finalizers, use runtime.TypedGCCallback:
//!
//! ```zig
//! const typed_callback = @import("typed_callback.zig");
//!
//! const NativeResource = struct {
//!     file_handle: std.fs.File,
//!     buffer: []u8,
//!     allocator: std.mem.Allocator,
//! };
//!
//! fn cleanupResource(resource: *NativeResource) void {
//!     resource.file_handle.close();
//!     resource.allocator.free(resource.buffer);
//! }
//!
//! // Create resource on heap (required for GC callbacks)
//! var resource = try allocator.create(NativeResource);
//! resource.* = .{ .file_handle = file, .buffer = buf, .allocator = allocator };
//!
//! // Create typed callback
//! var cb = typed_callback.TypedGCCallback(NativeResource).init(
//!     &cleanupResource,
//!     resource,
//!     allocator,
//! );
//!
//! // Register with V8 weak callback API
//! // The toLegacyCallbackC() provides C-compatible function pointer
//! v8_set_weak_callback(handle, cb.getDataAnyopaque(), TypedGCCallback(NativeResource).toLegacyCallbackC());
//! ```
//!
//! ## Lifetime Contracts
//!
//! ### GC Finalizer Callbacks
//! - UserData MUST be heap-allocated (stack is invalid during GC)
//! - GC may call finalizer on ANY thread (must be thread-safe)
//! - After finalizer returns, object is fully collected
//! - Do NOT access JavaScript objects from finalizer (may trigger GC recursion)
//! - Do NOT allocate in finalizer (may cause deadlock)

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
///
/// ## Type Safety Note (KEEP - C ABI boundary)
///
/// This function uses `?*anyopaque` because it must be compatible with the C ABI
/// for JavaScript engine callbacks. The `callconv(.c)` calling convention requires
/// C-compatible types. For type-safe GC callbacks, use `TypedGCCallback(T)` from
/// `runtime.typed_callback` which provides a typed wrapper that converts to this
/// C-compatible signature.
///
/// Example with TypedGCCallback:
/// ```zig
/// const typed_callback = @import("typed_callback.zig");
/// var cb = TypedGCCallback(MyResource).init(&cleanupFn, resource, allocator);
/// v8.setWeakCallback(handle, cb.getDataAnyopaque(), TypedGCCallback(MyResource).toLegacyCallbackC());
/// ```
pub fn onObjectFreed(user_data: ?*anyopaque) callconv(.c) void {
    // KEEP: @ptrCast/@alignCast required at C ABI boundary - use TypedGCCallback for type-safe wrappers
    const inst = @as(*Instance, @ptrCast(@alignCast(user_data orelse return)));

    // Step 1: Call type-specific deinit to clean up owned resources
    // (strings, arrays, etc. allocated by the implementation)
    if (inst.vtable.deinit) |deinit| {
        deinit(inst); // Calls Node.deinit_wrapper → Node.deinit
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
///
/// ## KEEP - C ABI boundary
/// The `callconv(.c)` is required for JavaScript engine interop.
pub fn onGCSweep() callconv(.c) void {
    // Reset arena to batch-free ALL FullState memory at once
    // This is much faster than individual frees
    ArenaAllocator.get().reset();
}

/// Error type for GC integration operations
pub const GCError = error{
    /// registerCallbacks was called but no JS engine implementation is available
    NotImplemented,
};

/// Register GC callbacks with JavaScript engine (engine-specific)
///
/// This is a helper that would be called during engine initialization.
/// The actual implementation depends on which JavaScript engine is used.
///
/// Returns error.NotImplemented if called without a specific JS engine binding.
/// In practice, engine-specific bindings (V8, JSC) provide their own registration.
///
/// Example for V8:
///   extern fn registerV8Callbacks(isolate: *v8.Isolate) void;
///
/// Example for JavaScriptCore:
///   extern fn registerJSCCallbacks(ctx: *JSC.JSContextRef) void;
pub fn registerCallbacks() GCError!void {
    // This is a placeholder - actual implementation depends on JS engine
    // In practice, this would be implemented in the JS engine binding layer
    return GCError.NotImplemented;
}

// ============================================================================
// Typed Wrapper for Internal Use
// ============================================================================

/// Create a typed finalizer function from a cleanup callback.
///
/// This is a convenience wrapper for internal Zig code that wants type safety
/// when registering GC finalizers. The underlying C ABI callback (`onObjectFreed`)
/// must still use `?*anyopaque` for engine compatibility.
///
/// ## Example
///
/// ```zig
/// const MyResource = struct {
///     buffer: []u8,
///     allocator: std.mem.Allocator,
///
///     pub fn cleanup(self: *MyResource) void {
///         self.allocator.free(self.buffer);
///     }
/// };
///
/// // Register with typed safety
/// const finalizer = TypedFinalizer(MyResource).init(&MyResource.cleanup);
/// // The finalizer can be stored and invoked with type safety
/// // For actual GC registration, use onObjectFreed which handles the C ABI
/// ```
pub fn TypedFinalizer(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The typed cleanup function
        cleanup_fn: *const fn (*T) void,

        /// Initialize with a typed cleanup function
        pub fn init(cleanup_fn: *const fn (*T) void) Self {
            return .{ .cleanup_fn = cleanup_fn };
        }

        /// Invoke the cleanup function on a typed pointer
        pub fn invoke(self: Self, instance: *T) void {
            self.cleanup_fn(instance);
        }
    };
}

// ============================================================================
// Statistics
// ============================================================================

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
///
/// KEEP: anyopaque required - extern "C" callback for JavaScript engine GC.
/// See onObjectFreed for full documentation.
pub fn onObjectFreedInstrumented(user_data: ?*anyopaque) callconv(.c) void {
    GCStats.get().objects_finalized += 1;
    onObjectFreed(user_data);
}

/// Instrumented version of onGCSweep for testing/debugging
///
/// KEEP: callconv(.c) required - extern "C" callback for JavaScript engine GC.
/// See onGCSweep for full documentation.
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
        fn deinit(instance: *Instance) void {
            const called: *bool = @ptrCast(@alignCast(instance.state));
            called.* = true;
        }
    };

    // Create instance
    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = &TestImpl.deinit,
        .methods_ptr = &delegates,
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

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
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

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
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
