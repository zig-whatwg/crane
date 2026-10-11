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
const BrowserScope = @import("browser_scope.zig").BrowserScope;

/// Type-erased internal state storage: instance address -> internal state
/// pointer (the actual InternalState type is known by the caller). One per
/// Browser - its scope's `.internal_states` table - so an instance's entry is
/// its Browser's and goes with it (docs/instances.md).
///
/// Every thread that makes platform objects - a Browser's and each of its
/// workers' - registers here, so the map is reached only under `mutex`. A
/// value is a pointer to a block the instance's own thread allocated and
/// frees, so a pointer read under the lock stays good after it.
pub const Registry = struct {
    /// Protects `map`; held for one map operation, never across a call out of
    /// this file.
    mutex: std.Io.Mutex = .init,
    map: std.AutoHashMapUnmanaged(usize, *anyopaque) = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    /// With its scope: the entries go (the blocks they point to are their
    /// owners').
    pub fn deinit(self: *Registry) void {
        self.map.deinit(self.allocator);
    }
};

/// `instance`'s Browser's registry.
fn registryOf(instance: *const Instance) !*Registry {
    return BrowserScope.ofInstance(instance).table(.internal_states, Registry);
}

/// `instance`'s Browser's registry, if it was ever made.
fn existingRegistryOf(instance: *const Instance) ?*Registry {
    return BrowserScope.ofInstance(instance).existingTable(.internal_states, Registry);
}

/// Register internal state for an instance
///
/// This should be called during impl init() to associate internal state
/// with the instance. The state must be allocated from the instance's arena
/// (runtime.arenaOf) or another allocator with sufficient lifetime.
///
/// ## Parameters
/// - `instance`: The WebIDL instance
/// - `internal`: Pointer to the internal state struct
pub fn setInternal(instance: *Instance, internal: anytype) !void {
    const registry = try registryOf(instance);
    std.Io.Threaded.mutexLock(&registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&registry.mutex);
    try registry.map.put(registry.allocator, @intFromPtr(instance), @ptrCast(internal));
}

/// Get internal state for an instance
///
/// Returns the internal state pointer cast to the specified type,
/// or null if no internal state is registered for this instance.
///
/// ## Type Safety
/// The caller must ensure the correct InternalState type is specified.
/// Using the wrong type will result in undefined behavior.
pub fn getInternal(comptime InternalStateType: type, instance: *Instance) ?*InternalStateType {
    const registry = existingRegistryOf(instance) orelse return null;
    std.Io.Threaded.mutexLock(&registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&registry.mutex);
    const ptr = registry.map.get(@intFromPtr(instance)) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

/// Remove internal state registration for an instance
///
/// This should be called during impl deinit() to clean up.
/// Note: This does NOT free the internal state memory - that is the impl's.
pub fn removeInternal(instance: *Instance) void {
    const registry = existingRegistryOf(instance) orelse return;
    std.Io.Threaded.mutexLock(&registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&registry.mutex);
    _ = registry.map.remove(@intFromPtr(instance));
}

/// Check if an instance has internal state registered
pub fn hasInternal(instance: *Instance) bool {
    const registry = existingRegistryOf(instance) orelse return false;
    std.Io.Threaded.mutexLock(&registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&registry.mutex);
    return registry.map.contains(@intFromPtr(instance));
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

// Tests: tests/runtime/browser_scope_allocators_test.zig, runtime_threads_test.zig.
