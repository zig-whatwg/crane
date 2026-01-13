//! Instance Lifecycle Tracking
//!
//! This module provides lifecycle state tracking for runtime.Instance objects
//! to coordinate cleanup between different paths (context teardown vs GC).
//!
//! ## Problem (RC2)
//!
//! Without lifecycle tracking, there's no way to know if an instance:
//! - Has already been cleaned up (preventing double-free)
//! - Is currently being cleaned up (preventing recursive cleanup)
//! - Is attached to the DOM tree (affecting cleanup order)
//!
//! ## Solution
//!
//! Track lifecycle flags per-instance using a lightweight registry.
//! Flags are stored externally to preserve Instance's 24-byte size constraint.
//!
//! ## Flags
//!
//! - `cleanup_started`: Cleanup has begun (prevents re-entry)
//! - `cleanup_complete`: Cleanup is done (prevents double-free)
//! - `attached_to_dom`: Instance is in the DOM tree (affects cleanup order)
//! - `gc_weak_callback_pending`: V8 weak callback may fire
//!
//! ## Usage
//!
//! ```zig
//! const lifecycle = @import("runtime").instance_lifecycle;
//!
//! // In deinit function
//! pub fn deinit(instance: *runtime.Instance) void {
//!     // Check if already cleaned up
//!     if (lifecycle.isCleanedUp(instance)) return;
//!
//!     // Mark cleanup started (prevents re-entry)
//!     lifecycle.markCleanupStarted(instance);
//!
//!     // ... do actual cleanup ...
//!
//!     // Mark cleanup complete
//!     lifecycle.markCleanupComplete(instance);
//! }
//! ```

const std = @import("std");
const Instance = @import("instance.zig").Instance;

/// Lifecycle flags for an instance
pub const LifecycleFlags = packed struct {
    /// Cleanup has started (prevents recursive cleanup)
    cleanup_started: bool = false,

    /// Cleanup is complete (prevents double-free)
    cleanup_complete: bool = false,

    /// Instance is attached to DOM tree
    attached_to_dom: bool = false,

    /// V8 weak callback is registered and may fire
    gc_weak_callback_pending: bool = false,

    /// Reserved for future use
    _reserved: u4 = 0,
};

/// Thread-local lifecycle registry
/// Uses a HashMap for O(1) lookup by instance pointer
const Registry = std.AutoHashMap(*const Instance, LifecycleFlags);

threadlocal var registry: ?Registry = null;
threadlocal var registry_allocator: ?std.mem.Allocator = null;

/// Initialize the lifecycle registry for this thread
pub fn init(allocator: std.mem.Allocator) void {
    if (registry == null) {
        registry = Registry.init(allocator);
        registry_allocator = allocator;
    }
}

/// Deinitialize the lifecycle registry
pub fn deinit() void {
    if (registry) |*r| {
        r.deinit();
        registry = null;
        registry_allocator = null;
    }
}

/// Get lifecycle flags for an instance (creates default if not present)
fn getOrCreate(instance: *const Instance) *LifecycleFlags {
    const r = &(registry orelse {
        // Auto-initialize with page allocator if not explicitly initialized
        // This is a fallback for testing - production should call init()
        registry = Registry.init(std.heap.page_allocator);
        registry_allocator = std.heap.page_allocator;
        return getOrCreate(instance);
    });

    const result = r.getOrPut(instance) catch {
        // On OOM, return a static default (shouldn't happen in practice)
        return &default_flags;
    };

    if (!result.found_existing) {
        result.value_ptr.* = .{};
    }

    return result.value_ptr;
}

/// Default flags (used as fallback on OOM)
var default_flags: LifecycleFlags = .{};

/// Get lifecycle flags for an instance (returns null if not tracked)
pub fn get(instance: *const Instance) ?LifecycleFlags {
    const r = registry orelse return null;
    return r.get(instance);
}

/// Remove lifecycle tracking for an instance
pub fn remove(instance: *const Instance) void {
    if (registry) |*r| {
        _ = r.remove(instance);
    }
}

// ============================================================================
// Convenience Functions for Common Operations
// ============================================================================

/// Check if cleanup has started for an instance
pub fn isCleanupStarted(instance: *const Instance) bool {
    const flags = get(instance) orelse return false;
    return flags.cleanup_started;
}

/// Check if cleanup is complete for an instance
pub fn isCleanedUp(instance: *const Instance) bool {
    const flags = get(instance) orelse return false;
    return flags.cleanup_complete;
}

/// Check if instance is attached to DOM
pub fn isAttachedToDOM(instance: *const Instance) bool {
    const flags = get(instance) orelse return false;
    return flags.attached_to_dom;
}

/// Check if GC weak callback is pending
pub fn hasGCWeakCallbackPending(instance: *const Instance) bool {
    const flags = get(instance) orelse return false;
    return flags.gc_weak_callback_pending;
}

/// Mark cleanup as started
/// Returns true if this is the first call (cleanup should proceed)
/// Returns false if cleanup was already started (should skip)
pub fn markCleanupStarted(instance: *const Instance) bool {
    const flags = getOrCreate(instance);
    if (flags.cleanup_started) {
        return false; // Already started, skip
    }
    flags.cleanup_started = true;
    return true; // First call, proceed with cleanup
}

/// Mark cleanup as complete and remove from registry
/// This is important because slab allocator reuses memory addresses.
/// If we don't remove the entry, a new instance at the same address
/// would be detected as "already cleaned up" and deinit would be skipped.
pub fn markCleanupComplete(instance: *const Instance) void {
    if (registry) |*r| {
        // Remove the entry entirely - this is critical for memory reuse!
        // When slab allocator reuses this address for a new instance,
        // we need markCleanupStarted to return true (fresh state).
        _ = r.remove(instance);
    }
}

/// Mark instance as attached to DOM
pub fn markAttachedToDOM(instance: *const Instance) void {
    const flags = getOrCreate(instance);
    flags.attached_to_dom = true;
}

/// Mark instance as detached from DOM
pub fn markDetachedFromDOM(instance: *const Instance) void {
    const flags = getOrCreate(instance);
    flags.attached_to_dom = false;
}

/// Mark that GC weak callback is registered
pub fn markGCWeakCallbackPending(instance: *const Instance) void {
    const flags = getOrCreate(instance);
    flags.gc_weak_callback_pending = true;
}

/// Clear GC weak callback pending flag
pub fn clearGCWeakCallbackPending(instance: *const Instance) void {
    const flags = getOrCreate(instance);
    flags.gc_weak_callback_pending = false;
}

/// Check if cleanup should proceed (not already started/complete)
/// This is the main guard function for deinit implementations
pub fn shouldCleanup(instance: *const Instance) bool {
    const flags = get(instance) orelse return true; // No flags = never cleaned
    return !flags.cleanup_started and !flags.cleanup_complete;
}

/// Reset all flags for an instance (for testing)
pub fn reset(instance: *const Instance) void {
    if (registry) |*r| {
        if (r.getPtr(instance)) |flags| {
            flags.* = .{};
        }
    }
}

/// Clear the entire registry (for testing between tests)
pub fn clearAll() void {
    if (registry) |*r| {
        r.clearRetainingCapacity();
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "LifecycleFlags - default values" {
    const flags = LifecycleFlags{};
    try testing.expect(!flags.cleanup_started);
    try testing.expect(!flags.cleanup_complete);
    try testing.expect(!flags.attached_to_dom);
    try testing.expect(!flags.gc_weak_callback_pending);
}

test "LifecycleFlags - packed size" {
    try testing.expectEqual(@as(usize, 1), @sizeOf(LifecycleFlags));
}

test "instance_lifecycle - init and deinit" {
    init(testing.allocator);
    defer deinit();

    // Should be initialized
    try testing.expect(registry != null);
}

test "instance_lifecycle - mark and check cleanup" {
    init(testing.allocator);
    defer deinit();

    // Create a dummy instance for testing
    const vtable = @import("instance.zig").VTable{
        .deinit = null,
        .methods_ptr = undefined,
    };
    var instance = Instance{
        .vtable = &vtable,
        .state = undefined,
        .ctx = undefined,
    };

    // Initially not cleaned up
    try testing.expect(shouldCleanup(&instance));
    try testing.expect(!isCleanupStarted(&instance));
    try testing.expect(!isCleanedUp(&instance));

    // Mark cleanup started
    try testing.expect(markCleanupStarted(&instance));
    try testing.expect(isCleanupStarted(&instance));
    try testing.expect(!isCleanedUp(&instance));
    try testing.expect(!shouldCleanup(&instance)); // Should not cleanup again

    // Second call returns false
    try testing.expect(!markCleanupStarted(&instance));

    // Mark cleanup complete
    markCleanupComplete(&instance);
    try testing.expect(isCleanedUp(&instance));

    // Remove tracking
    remove(&instance);
    try testing.expect(!isCleanedUp(&instance)); // No longer tracked
}

test "instance_lifecycle - DOM attachment tracking" {
    init(testing.allocator);
    defer deinit();

    const vtable = @import("instance.zig").VTable{
        .deinit = null,
        .methods_ptr = undefined,
    };
    var instance = Instance{
        .vtable = &vtable,
        .state = undefined,
        .ctx = undefined,
    };

    // Initially not attached
    try testing.expect(!isAttachedToDOM(&instance));

    // Mark attached
    markAttachedToDOM(&instance);
    try testing.expect(isAttachedToDOM(&instance));

    // Mark detached
    markDetachedFromDOM(&instance);
    try testing.expect(!isAttachedToDOM(&instance));
}

test "instance_lifecycle - GC weak callback tracking" {
    init(testing.allocator);
    defer deinit();

    const vtable = @import("instance.zig").VTable{
        .deinit = null,
        .methods_ptr = undefined,
    };
    var instance = Instance{
        .vtable = &vtable,
        .state = undefined,
        .ctx = undefined,
    };

    // Initially no callback pending
    try testing.expect(!hasGCWeakCallbackPending(&instance));

    // Mark pending
    markGCWeakCallbackPending(&instance);
    try testing.expect(hasGCWeakCallbackPending(&instance));

    // Clear pending
    clearGCWeakCallbackPending(&instance);
    try testing.expect(!hasGCWeakCallbackPending(&instance));
}

test "instance_lifecycle - reset and clearAll" {
    init(testing.allocator);
    defer deinit();

    const vtable = @import("instance.zig").VTable{
        .deinit = null,
        .methods_ptr = undefined,
    };
    var instance = Instance{
        .vtable = &vtable,
        .state = undefined,
        .ctx = undefined,
    };

    // Set some flags
    _ = markCleanupStarted(&instance);
    markAttachedToDOM(&instance);

    // Reset should clear flags
    reset(&instance);
    try testing.expect(!isCleanupStarted(&instance));
    try testing.expect(!isAttachedToDOM(&instance));

    // Set again for clearAll test
    _ = markCleanupStarted(&instance);
    clearAll();
    try testing.expect(!isCleanupStarted(&instance));
}
