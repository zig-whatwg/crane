//! Internal State Registry and Accessors
//!
//! This module provides a generic mechanism for storing and accessing internal
//! state associated with WebIDL interface instances. Instead of each impl
//! defining its own registry and accessor functions, this module provides
//! a centralized, type-safe approach.
//!
//! ## Background
//!
//! WebIDL interfaces often need internal state beyond what's defined in the
//! WebIDL specification. For example, HTMLScriptElement needs to track:
//! - already_started flag
//! - parser_document reference
//! - script_type enum
//!
//! Previously, each impl (e.g., HTMLScriptElementImpl) would define its own:
//! - InternalState struct
//! - Global registry (AutoHashMap keyed by instance pointer)
//! - getInternal/setInternal functions
//! - Dozens of accessor functions (hasAlreadyStarted, setAlreadyStarted, etc.)
//!
//! This approach had problems:
//! - Massive code duplication across impls
//! - Accessor functions were mechanical (just get field, set field)
//! - External code had to import from impls, violating architectural boundaries
//!
//! ## Solution
//!
//! This module provides:
//! 1. A generic registry that can store any InternalState type
//! 2. Type-safe getInternal/setInternal that work with any state type
//! 3. No need for per-impl accessor boilerplate
//!
//! External code can now do:
//! ```zig
//! const internal_state = @import("runtime");
//! const internal = internal_state.getInternal(instance, HTMLScriptElementInternalState);
//! if (internal.already_started) { ... }
//! ```
//!
//! Instead of:
//! ```zig
//! const HTMLScriptElement = @import("interfaces").HTMLScriptElement;
//! if (HTMLScriptElement.hasAlreadyStarted(instance)) { ... }
//! ```

const std = @import("std");
const Instance = @import("instance.zig").Instance;

/// Type-erased internal state storage: instance address -> internal state
/// pointer (the actual InternalState type is known by the caller).
///
/// Every thread that makes platform objects - a Browser's and each of its
/// workers' (docs/instances.md) - registers here, so the map is reached only
/// under `mutex`. A value is a pointer to a block the instance's own thread
/// allocated and frees, so a pointer read under the lock stays good after it.
const Registry = struct {
    /// Protects `map` and `initialized`; held for one map operation, never
    /// across a call out of this file.
    mutex: std.Io.Mutex = .init,
    map: std.AutoHashMapUnmanaged(usize, *anyopaque) = .empty,
    allocator: std.mem.Allocator = std.heap.page_allocator,
    initialized: bool = false,
};
var global_registry: Registry = .{};

/// Initialize the registry with a specific allocator
/// This should be called early in application startup.
/// If not called, registrations use page_allocator.
pub fn initRegistry(allocator: std.mem.Allocator) void {
    std.Io.Threaded.mutexLock(&global_registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&global_registry.mutex);
    if (global_registry.initialized) {
        // Already initialized: the map keeps its allocator - an entry's
        // storage must be freed by the allocator that made it.
        return;
    }
    global_registry.allocator = allocator;
    global_registry.initialized = true;
}

/// Register internal state for an instance
///
/// This should be called during impl init() to associate internal state
/// with the instance. The state must be allocated from ArenaAllocator
/// or another allocator with sufficient lifetime.
///
/// ## Parameters
/// - `instance`: The WebIDL instance
/// - `internal`: Pointer to the internal state struct
///
/// ## Example
/// ```zig
/// pub fn init(allocator: Allocator, ...) !*Instance {
///     const instance = try Instance.init(...);
///     const internal = try ArenaAllocator.get().create(InternalState);
///     internal.* = InternalState.init(allocator);
///     try internal_state.setInternal(instance, internal);
///     return instance;
/// }
/// ```
pub fn setInternal(instance: *Instance, internal: anytype) !void {
    std.Io.Threaded.mutexLock(&global_registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&global_registry.mutex);
    global_registry.initialized = true;
    try global_registry.map.put(global_registry.allocator, @intFromPtr(instance), @ptrCast(internal));
}

/// Get internal state for an instance
///
/// Returns the internal state pointer cast to the specified type,
/// or null if no internal state is registered for this instance.
///
/// ## Type Safety
/// The caller must ensure the correct InternalState type is specified.
/// Using the wrong type will result in undefined behavior.
///
/// ## Parameters
/// - `InternalStateType`: The type of internal state to retrieve
/// - `instance`: The WebIDL instance
///
/// ## Returns
/// Pointer to the internal state, or null if not found
///
/// ## Example
/// ```zig
/// const HTMLScriptElementInternal = @import("impls").HTMLScriptElement.InternalState;
///
/// if (internal_state.getInternal(HTMLScriptElementInternal, instance)) |internal| {
///     if (internal.already_started) {
///         return;
///     }
///     internal.already_started = true;
/// }
/// ```
pub fn getInternal(comptime InternalStateType: type, instance: *Instance) ?*InternalStateType {
    std.Io.Threaded.mutexLock(&global_registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&global_registry.mutex);
    const ptr = global_registry.map.get(@intFromPtr(instance)) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

/// Remove internal state registration for an instance
///
/// This should be called during impl deinit() to clean up.
/// Note: This does NOT free the internal state memory - that should
/// be handled by the impl's deinit or by ArenaAllocator reset.
///
/// ## Parameters
/// - `instance`: The WebIDL instance
pub fn removeInternal(instance: *Instance) void {
    std.Io.Threaded.mutexLock(&global_registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&global_registry.mutex);
    _ = global_registry.map.remove(@intFromPtr(instance));
}

/// Check if an instance has internal state registered
///
/// ## Parameters
/// - `instance`: The WebIDL instance
///
/// ## Returns
/// true if internal state is registered, false otherwise
pub fn hasInternal(instance: *Instance) bool {
    std.Io.Threaded.mutexLock(&global_registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&global_registry.mutex);
    return global_registry.map.contains(@intFromPtr(instance));
}

/// Reset the entire registry (for testing or shutdown)
///
/// Warning: This does NOT free the internal state memory.
/// Only use during shutdown or between test runs.
pub fn resetRegistry() void {
    std.Io.Threaded.mutexLock(&global_registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&global_registry.mutex);
    if (global_registry.initialized) {
        global_registry.map.clearAndFree(global_registry.allocator);
        global_registry.initialized = false;
        // A registration before the next initRegistry uses page_allocator,
        // as it always did.
        global_registry.allocator = std.heap.page_allocator;
    }
}

// =============================================================================
// Convenience Field Accessors
// =============================================================================
// These functions provide type-safe access to individual fields within
// internal state, useful when you just need one field.

/// Get a boolean field from internal state
///
/// ## Example
/// ```zig
/// const already_started = internal_state.getBool(instance, HTMLScriptInternal, "already_started") orelse false;
/// ```
pub fn getBool(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
) ?bool {
    const internal = getInternal(InternalStateType, instance) orelse return null;
    return @field(internal, field_name);
}

/// Set a boolean field in internal state
pub fn setBool(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
    value: bool,
) void {
    if (getInternal(InternalStateType, instance)) |internal| {
        @field(internal, field_name) = value;
    }
}

/// Get an optional pointer field from internal state
pub fn getOptionalPtr(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
    comptime PtrType: type,
) ?PtrType {
    const internal = getInternal(InternalStateType, instance) orelse return null;
    return @field(internal, field_name);
}

/// Set an optional pointer field in internal state
pub fn setOptionalPtr(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
    value: anytype,
) void {
    if (getInternal(InternalStateType, instance)) |internal| {
        @field(internal, field_name) = value;
    }
}

/// Get an enum field from internal state
pub fn getEnum(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
    comptime EnumType: type,
) ?EnumType {
    const internal = getInternal(InternalStateType, instance) orelse return null;
    return @field(internal, field_name);
}

/// Set an enum field in internal state
pub fn setEnum(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
    value: anytype,
) void {
    if (getInternal(InternalStateType, instance)) |internal| {
        @field(internal, field_name) = value;
    }
}

/// Get a u32 field from internal state
pub fn getU32(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
) ?u32 {
    const internal = getInternal(InternalStateType, instance) orelse return null;
    return @field(internal, field_name);
}

/// Set a u32 field in internal state
pub fn setU32(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
    value: u32,
) void {
    if (getInternal(InternalStateType, instance)) |internal| {
        @field(internal, field_name) = value;
    }
}

/// Increment a u32 field in internal state
pub fn incrementU32(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
) void {
    if (getInternal(InternalStateType, instance)) |internal| {
        @field(internal, field_name) += 1;
    }
}

/// Decrement a u32 field in internal state (saturating at 0)
pub fn decrementU32(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
) void {
    if (getInternal(InternalStateType, instance)) |internal| {
        const current = @field(internal, field_name);
        if (current > 0) {
            @field(internal, field_name) = current - 1;
        }
    }
}

/// Get an optional slice field from internal state
pub fn getOptionalSlice(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
) ?[]const u8 {
    const internal = getInternal(InternalStateType, instance) orelse return null;
    return @field(internal, field_name);
}

/// Set an optional slice field in internal state
pub fn setOptionalSlice(
    instance: *Instance,
    comptime InternalStateType: type,
    comptime field_name: []const u8,
    value: ?[]const u8,
) void {
    if (getInternal(InternalStateType, instance)) |internal| {
        @field(internal, field_name) = value;
    }
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

test "setInternal and getInternal work correctly" {
    // Reset registry for clean test
    resetRegistry();
    defer resetRegistry();

    const TestInternal = struct {
        value: u32,
        flag: bool,
    };

    // Create a mock instance
    const delegates = .{};
    const vtable = @import("instance.zig").VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    var state: u8 = 0;
    var instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&state),
        .ctx = undefined,
    };

    // Allocate and register internal state
    var internal = TestInternal{ .value = 42, .flag = true };
    try setInternal(&instance, &internal);

    // Retrieve and verify
    const retrieved = getInternal(TestInternal, &instance);
    try testing.expect(retrieved != null);
    try testing.expectEqual(@as(u32, 42), retrieved.?.value);
    try testing.expect(retrieved.?.flag);

    // Modify through retrieved pointer
    retrieved.?.value = 100;
    try testing.expectEqual(@as(u32, 100), internal.value);
}

test "getInternal returns null for unregistered instance" {
    resetRegistry();
    defer resetRegistry();

    const TestInternal = struct {
        value: u32,
    };

    const delegates = .{};
    const vtable = @import("instance.zig").VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    var state: u8 = 0;
    var instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&state),
        .ctx = undefined,
    };

    const retrieved = getInternal(TestInternal, &instance);
    try testing.expect(retrieved == null);
}

test "removeInternal works correctly" {
    resetRegistry();
    defer resetRegistry();

    const TestInternal = struct {
        value: u32,
    };

    const delegates = .{};
    const vtable = @import("instance.zig").VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    var state: u8 = 0;
    var instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&state),
        .ctx = undefined,
    };

    var internal = TestInternal{ .value = 42 };
    try setInternal(&instance, &internal);

    try testing.expect(hasInternal(&instance));

    removeInternal(&instance);

    try testing.expect(!hasInternal(&instance));
    try testing.expect(getInternal(TestInternal, &instance) == null);
}

test "field accessors work correctly" {
    resetRegistry();
    defer resetRegistry();

    const TestInternal = struct {
        flag: bool,
        count: u32,
        name: ?[]const u8,
    };

    const delegates = .{};
    const vtable = @import("instance.zig").VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    var state: u8 = 0;
    var instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&state),
        .ctx = undefined,
    };

    var internal = TestInternal{
        .flag = false,
        .count = 0,
        .name = null,
    };
    try setInternal(&instance, &internal);

    // Test bool accessor
    try testing.expectEqual(false, getBool(&instance, TestInternal, "flag").?);
    setBool(&instance, TestInternal, "flag", true);
    try testing.expectEqual(true, getBool(&instance, TestInternal, "flag").?);

    // Test u32 accessor
    try testing.expectEqual(@as(u32, 0), getU32(&instance, TestInternal, "count").?);
    setU32(&instance, TestInternal, "count", 5);
    try testing.expectEqual(@as(u32, 5), getU32(&instance, TestInternal, "count").?);

    // Test increment/decrement
    incrementU32(&instance, TestInternal, "count");
    try testing.expectEqual(@as(u32, 6), getU32(&instance, TestInternal, "count").?);
    decrementU32(&instance, TestInternal, "count");
    try testing.expectEqual(@as(u32, 5), getU32(&instance, TestInternal, "count").?);

    // Test optional slice accessor
    try testing.expect(getOptionalSlice(&instance, TestInternal, "name") == null);
    setOptionalSlice(&instance, TestInternal, "name", "test");
    try testing.expectEqualStrings("test", getOptionalSlice(&instance, TestInternal, "name").?);
}
