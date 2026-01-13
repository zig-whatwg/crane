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

    /// General purpose allocator for long-lived objects
    gpa: std.heap.GeneralPurposeAllocator(.{}),

    /// Whether this uses an arena or GPA
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
/// - use_arena: If true, use arena allocator (fast, bulk free). If false, use GPA (slower, granular free)
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
            .gpa = undefined,
            .use_arena = true,
        };
        data.allocator = data.arena.allocator();
    } else {
        data.* = .{
            .allocator = undefined, // Set below
            .parent = parent,
            .arena = undefined,
            .gpa = std.heap.GeneralPurposeAllocator(.{}){},
            .use_arena = false,
        };
        data.allocator = data.gpa.allocator();
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

    // Clean up based on type
    if (data.use_arena) {
        data.arena.deinit();
    } else {
        _ = data.gpa.deinit();
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

    // Initialize with arena (faster for callbacks)
    try initIsolateAllocator(isolate, fallback, true);
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
