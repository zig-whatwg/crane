//! WebIDL Runtime Library
//!
//! This module provides the core runtime infrastructure for generated WebIDL interfaces.
//! It exports all runtime components needed by generated code:
//!
//! - **Instance Management**: Instance handles and VTable dispatch
//! - **Memory Allocation**: Slab allocator (Instance handles) and Arena allocator (FullState)
//! - **Type System**: WebIDL string types (DOMString, USVString, ByteString) from webidl module
//! - **Compile-Time Utilities**: Field merger, VTable builder
//! - **GC Integration**: JavaScript engine lifecycle callbacks
//!
//! ## Usage Example
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! // Initialize allocators
//! runtime.SlabAllocator.init(allocator);
//! defer runtime.SlabAllocator.deinit();
//!
//! runtime.ArenaAllocator.init(allocator);
//! defer runtime.ArenaAllocator.deinit();
//!
//! // Create an instance
//! const vtable = runtime.buildVTable(MyInterface, .{});
//! const instance = try runtime.SlabAllocator.get().alloc(&vtable);
//! defer runtime.SlabAllocator.get().free(instance);
//!
//! // Use WebIDL types
//! var str: runtime.DOMString = .empty;
//! defer str.deinit(allocator);
//! ```
//!
//! ## Architecture
//!
//! The runtime uses a two-tier memory model:
//!
//! 1. **SlabAllocator** - Fast fixed-size allocation for Instance handles (16 bytes)
//! 2. **ArenaAllocator** - Variable-sized allocation for FullState structs
//!
//! Instance handles are small (16 bytes) and frequently allocated/freed.
//! FullState structs contain the full object state and can be batch-freed during GC.
//!
//! ## Thread Safety
//!
//! - Allocators must be initialized before use
//! - Allocators use global state (single-threaded runtime)
//! - GC callbacks are called from GC thread
//!
//! ## Memory Management
//!
//! - Instance handles: Allocated via SlabAllocator, freed via GC or manual free
//! - FullState: Allocated via ArenaAllocator, batch-freed during GC sweep
//! - WebIDL strings: Use DOMString type with proper deinit

// Instance management and VTable dispatch
pub const Instance = @import("instance.zig").Instance;
pub const VTable = @import("instance.zig").VTable;
pub const MethodMap = @import("instance.zig").MethodMap;
pub const Method = @import("instance.zig").Method;

// WebIDL type system (delegated to webidl module for spec compliance)
const webidl = @import("webidl");
pub const DOMString = webidl.DOMString;
pub const USVString = webidl.USVString;
pub const ByteString = webidl.ByteString;

// Memory allocators
pub const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
pub const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

// Compile-time utilities
pub const buildVTable = @import("vtable_builder.zig").buildVTable;
pub const FlattenedState = @import("field_merger.zig").FlattenedState;

// GC integration
pub const gc = @import("gc_integration.zig");
pub const onObjectFreed = gc.onObjectFreed;
pub const onGCSweep = gc.onGCSweep;
pub const GCStats = gc.GCStats;

// Convenience re-exports
pub const initRuntime = initializeRuntime;
pub const deinitRuntime = deinitializeRuntime;

/// Initialize the WebIDL runtime
///
/// Must be called before using any runtime functionality.
/// Initializes both SlabAllocator and ArenaAllocator.
///
/// Thread safety: Not thread-safe, call once during startup
///
/// Example:
/// ```zig
/// const std = @import("std");
/// const runtime = @import("runtime");
///
/// pub fn main() !void {
///     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
///     defer _ = gpa.deinit();
///     const allocator = gpa.allocator();
///
///     runtime.initRuntime(allocator);
///     defer runtime.deinitRuntime();
///
///     // Use runtime...
/// }
/// ```
pub fn initializeRuntime(allocator: std.mem.Allocator) void {
    SlabAllocator.init(allocator);
    ArenaAllocator.init(allocator);
}

/// Deinitialize the WebIDL runtime
///
/// Frees all resources allocated by the runtime.
/// Must be called after all WebIDL objects have been freed.
///
/// Thread safety: Not thread-safe, call once during shutdown
pub fn deinitializeRuntime() void {
    ArenaAllocator.deinit();
    SlabAllocator.deinit();
}

// Standard library dependency
const std = @import("std");

// Unit tests
const testing = std.testing;

test "runtime exports" {
    // Verify all expected exports are available
    _ = Instance;
    _ = VTable;
    _ = MethodMap;
    _ = Method;

    _ = DOMString;
    _ = USVString;
    _ = ByteString;

    _ = SlabAllocator;
    _ = ArenaAllocator;

    _ = buildVTable;
    _ = FlattenedState;

    _ = gc;
    _ = onObjectFreed;
    _ = onGCSweep;
    _ = GCStats;

    _ = initRuntime;
    _ = deinitRuntime;
}

test "initRuntime and deinitRuntime work" {
    initializeRuntime(testing.allocator);
    defer deinitializeRuntime();

    // Verify allocators are initialized and can allocate
    const slab = SlabAllocator.get();
    const arena = ArenaAllocator.get();

    // Can allocate after init
    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    const instance = try slab.alloc(&vtable);
    const value = try arena.create(u32);
    value.* = 42;

    try testing.expectEqual(@as(u32, 42), value.*);

    slab.free(instance);
}

test "initRuntime initializes both allocators" {
    initializeRuntime(testing.allocator);
    defer deinitializeRuntime();

    // SlabAllocator should be usable
    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };
    const inst = try SlabAllocator.get().alloc(&vtable);
    SlabAllocator.get().free(inst);

    // ArenaAllocator should be usable
    const val = try ArenaAllocator.get().create(u64);
    val.* = 123;
    try testing.expectEqual(@as(u64, 123), val.*);
}

test "convenience aliases work" {
    // initRuntime is an alias for initializeRuntime
    try testing.expect(initRuntime == initializeRuntime);
    try testing.expect(deinitRuntime == deinitializeRuntime);
}
