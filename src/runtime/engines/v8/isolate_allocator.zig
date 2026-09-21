//! V8 Isolate-Scoped Allocator Management
//!
//! Provides per-isolate memory management for V8 callbacks.
//! Each V8 isolate gets its own allocator that can track and cleanup
//! all allocations made during the isolate's lifetime.
//!
//! ## Architecture
//!
//! V8 isolates are independent JavaScript execution environments.
//! Each isolate should have its own memory space for:
//! - Constructor arguments (temporary)
//! - Runtime instances (long-lived)
//! - Converted strings and objects
//!
//! ## Implementation Strategy
//!
//! We use V8's embedder data API to store an allocator per isolate.
//! This gives us:
//! - Automatic cleanup when isolate is disposed
//! - Thread-safe (each isolate belongs to one thread)
//! - Fast access (stored directly in V8 isolate)
//!
//! ## Usage
//!
//! ```zig
//! // On isolate creation
//! try initIsolateAllocator(isolate, parent_allocator);
//!
//! // In callbacks
//! const allocator = getIsolateAllocator(isolate).?;
//!
//! // On isolate disposal
//! deinitIsolateAllocator(isolate);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");

/// Embedder data slot for allocator storage
/// V8 allows storing arbitrary data per-isolate using slot indices
const ALLOCATOR_SLOT: c_int = 0;

/// Allocator wrapper stored in V8 isolate embedder data
const AllocatorData = struct {
    /// The actual allocator
    allocator: std.mem.Allocator,

    /// Parent allocator used to create this allocator
    /// (for cleanup)
    parent: std.mem.Allocator,

    /// Arena allocator for temporary allocations
    /// Gets reset after each callback
    arena: std.heap.ArenaAllocator,

    /// Arena mode, rather than handing back the parent directly.
    use_arena: bool,
};

/// Initialize allocator for a V8 isolate
///
/// This must be called once per isolate before any callbacks are invoked.
/// The allocator is stored in the isolate's embedder data and can be
/// retrieved with getIsolateAllocator().
///
/// Arguments:
/// - isolate: V8 isolate to initialize allocator for
/// - parent: Parent allocator to use for creating the isolate allocator
/// - use_arena: If true, allocations go to a per-isolate arena that is freed in
///   bulk at isolate teardown. If false, `parent` is handed back directly, so
///   `free` reaches the real allocator and memory is reclaimed during the run.
///   False is what every caller wants and what every caller passes: the arena's
///   `free` is a no-op, and this allocator serves every method and attribute
///   dispatcher, so in arena mode each argument conversion leaked until teardown.
///
/// Returns: Error if allocator already initialized or allocation fails
pub fn initIsolateAllocator(
    isolate: *v8.Isolate,
    parent: std.mem.Allocator,
    use_arena: bool,
) !void {
    // Check if already initialized
    const existing = v8.v8_Isolate_GetData(isolate, ALLOCATOR_SLOT);
    if (existing != null) {
        return error.AllocatorAlreadyInitialized;
    }

    // Create allocator data
    const data = try parent.create(AllocatorData);
    errdefer parent.destroy(data);

    if (use_arena) {
        data.* = .{
            .allocator = undefined, // Set below
            .parent = parent,
            .arena = std.heap.ArenaAllocator.init(parent),
            .use_arena = true,
        };
        data.allocator = data.arena.allocator();
    } else {
        // Non-arena: hand back the PARENT allocator, so `free` actually frees.
        //
        // Not a DebugAllocator: that retains freed pages to detect use-after-free
        // and never returns them to the OS, which would swap one non-reclaiming
        // allocator for another. The parent is whatever the caller supplied, and
        // the call sites supply `std.heap.c_allocator`.
        data.* = .{
            .allocator = parent,
            .parent = parent,
            .arena = undefined,
            .use_arena = false,
        };
    }

    // Store in isolate
    v8.v8_Isolate_SetData(isolate, ALLOCATOR_SLOT, data);
}

/// Get allocator for a V8 isolate
///
/// Returns null if no allocator has been initialized for this isolate.
/// Call initIsolateAllocator() first.
pub fn getIsolateAllocator(isolate: *v8.Isolate) ?std.mem.Allocator {
    const data_ptr = v8.v8_Isolate_GetData(isolate, ALLOCATOR_SLOT) orelse return null;
    const data: *AllocatorData = @ptrCast(@alignCast(data_ptr));
    return data.allocator;
}

/// Reset arena allocator (if using arena mode)
///
/// Call this after each callback to free temporary allocations.
/// Only works if the isolate was initialized with use_arena=true.
pub fn resetArena(isolate: *v8.Isolate) void {
    const data_ptr = v8.v8_Isolate_GetData(isolate, ALLOCATOR_SLOT) orelse return;
    const data: *AllocatorData = @ptrCast(@alignCast(data_ptr));

    if (data.use_arena) {
        _ = data.arena.reset(.retain_capacity);
    }
}

/// Deinitialize allocator for a V8 isolate
///
/// This should be called when the isolate is being disposed.
/// Frees all memory associated with the isolate allocator.
pub fn deinitIsolateAllocator(isolate: *v8.Isolate) void {
    const data_ptr = v8.v8_Isolate_GetData(isolate, ALLOCATOR_SLOT) orelse return;
    const data: *AllocatorData = @ptrCast(@alignCast(data_ptr));

    // Only the arena is ours to tear down. In passthrough mode `allocator` IS
    // `parent`, every allocation was already freed through it by its owner, and
    // there is no wrapper state - `arena` is `undefined` and must not be touched.
    if (data.use_arena) {
        data.arena.deinit();
    }

    // Free the data struct itself
    const parent = data.parent;
    parent.destroy(data);

    // Clear isolate data
    v8.v8_Isolate_SetData(isolate, ALLOCATOR_SLOT, null);
}

/// Get or create allocator for isolate
///
/// Convenience function that initializes the allocator if it doesn't exist.
/// Uses the provided fallback allocator if initialization is needed.
///
/// This is useful in callbacks where you're not sure if the allocator
/// has been initialized yet.
pub fn getOrInitAllocator(
    isolate: *v8.Isolate,
    fallback: std.mem.Allocator,
) !std.mem.Allocator {
    if (getIsolateAllocator(isolate)) |alloc| {
        return alloc;
    }

    // NOT an arena, despite "faster for callbacks".
    //
    // An arena's `free` is a no-op, so every per-callback argument conversion
    // accumulated for the life of the isolate - and this allocator serves the
    // method and getter dispatchers, i.e. every DOM call. `resetArena` exists for
    // exactly this, with the comment "Call this after each callback", and nothing
    // has ever called it.
    //
    // Resetting would be the other fix, but it is only safe if nothing allocated
    // during the callback outlives it, and that is not something the dispatcher
    // can know for 1,263 interfaces. Making `free` real is safe by construction:
    // callers that free reclaim, callers that do not leak exactly as much as they
    // already did. It is also backed by malloc rather than the page allocator, so
    // the memory is visible to `mstats()` instead of vanishing into VM_ALLOCATE.
    try initIsolateAllocator(isolate, fallback, false);
    return getIsolateAllocator(isolate).?;
}

// ============================================================================
// V8 FFI Functions (need to be added to ffi.zig)
// ============================================================================

// These functions are part of V8's embedder data API but might not be in ffi.zig yet
// If they're missing, they need to be added to src/v8/ffi.zig

// extern fn v8_Isolate_SetData(isolate: *v8.Isolate, slot: c_int, data: ?*anyopaque) void;
// extern fn v8_Isolate_GetData(isolate: *v8.Isolate, slot: c_int) ?*anyopaque;

// ============================================================================
// Tests
// ============================================================================

test "IsolateAllocator - init and deinit with arena" {
    // Note: This test would fail because v8_Isolate_SetData/GetData aren't real
    // In actual usage, V8 provides these functions
    // For now, just verify the code compiles

    // Example usage (commented out - requires real V8 isolate):
    // try initIsolateAllocator(mock_isolate, testing.allocator, true);
    // defer deinitIsolateAllocator(mock_isolate);
    // const alloc = getIsolateAllocator(mock_isolate).?;
    // const memory = try alloc.alloc(u8, 100);
    // defer alloc.free(memory);
}

test "IsolateAllocator - init and deinit with GPA" {
    // Similar to above - would need real V8 isolate
    // Just verifies compilation
}

test "IsolateAllocator - getOrInit creates allocator" {
    // Would test that getOrInitAllocator creates allocator if missing
    // Requires real V8 isolate
}

test "IsolateAllocator module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}
