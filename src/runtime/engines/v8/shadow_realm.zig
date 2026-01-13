//! ShadowRealm Support for V8
//!
//! This module implements the host callback for ShadowRealm context creation.
//! When JavaScript code executes `new ShadowRealm()`, V8 invokes our callback
//! to create the isolated execution context.
//!
//! ## WHATWG HTML Standard
//! https://html.spec.whatwg.org/multipage/webappapis.html#shadowrealmglobalscope
//!
//! ## TC39 ShadowRealm Proposal
//! https://tc39.es/proposal-shadowrealm/
//!
//! ## V8 Integration
//! V8 provides ShadowRealm via the --harmony-shadow-realm flag (enabled in SNAPSHOT_V8_FLAGS).
//! We implement HostCreateShadowRealmContextCallback to create properly-configured contexts.
//!
//! ## Lifetime Management
//! ShadowRealm contexts are tracked and cleaned up when:
//! 1. The initiator context is disposed
//! 2. The isolate is disposed
//! 3. The ShadowRealm object is garbage collected (via weak callback)

const std = @import("std");
const ffi = @import("ffi.zig");
const SnapshotContextIndex = @import("snapshot_context_index.zig").SnapshotContextIndex;
const context_manager = @import("context_manager.zig");

/// Tracked ShadowRealm context entry
const ShadowRealmEntry = struct {
    /// Global handle to the ShadowRealm context (owned by us)
    context_handle: ?*anyopaque,
    /// Pointer to the initiator context (for association, not ownership)
    initiator_context: ?*anyopaque,
    /// Creation timestamp for debugging
    created_at: i64,
};

/// User data passed to the ShadowRealm callback
const ShadowRealmCallbackData = struct {
    /// Allocator for context tracking
    allocator: std.mem.Allocator,
    /// Map of ShadowRealm context handles to their entries
    /// Key: context handle pointer (as usize for HashMap compatibility)
    tracked_realms: std.AutoHashMap(usize, ShadowRealmEntry),
    /// Count of total ShadowRealms created (for debugging)
    total_created: usize = 0,
};

/// Global callback data (set during initialization)
var g_callback_data: ?*ShadowRealmCallbackData = null;

/// V8 callback for ShadowRealm context creation
///
/// This is called by V8 when JavaScript executes `new ShadowRealm()`.
/// We create a new context from the snapshot at the ShadowRealm index,
/// which has only [Exposed=ShadowRealm] interfaces registered.
///
/// @param user_data - Opaque pointer to ShadowRealmCallbackData
/// @param initiator_context_ptr - Global<Context>* to the context that created the ShadowRealm
/// @return Global<Context>* to the new ShadowRealm context, or null on failure
fn shadowRealmContextCallback(
    user_data: ?*anyopaque,
    initiator_context_ptr: ?*anyopaque,
) callconv(.c) ?*anyopaque {
    const callback_data: ?*ShadowRealmCallbackData = if (user_data) |ud|
        @ptrCast(@alignCast(ud))
    else
        null;

    // Get the current isolate
    const isolate = ffi.v8_Isolate_GetCurrent() orelse {
        std.log.err("[ShadowRealm] No current isolate", .{});
        return null;
    };

    // Create context from the ShadowRealm snapshot index
    // NOTE: The actual snapshot index is the position in SnapshotContextIndex.implemented,
    // NOT the enum value. Since shared_storage_worklet is skipped, ShadowRealm is at index 8.
    // The implemented array is: [window, dedicated_worker, shared_worker, service_worker,
    //                           audio_worklet, paint_worklet, animation_worklet, layout_worklet,
    //                           shadow_realm] = indices 0-8
    const shadow_realm_actual_index: usize = SnapshotContextIndex.implemented.len - 1; // shadow_realm is last
    const context = ffi.v8_Context_NewFromSnapshotAt(isolate, shadow_realm_actual_index) orelse {
        std.log.err("[ShadowRealm] Failed to create context from snapshot at index {d}", .{shadow_realm_actual_index});
        return null;
    };

    // Create a Global handle for the new context
    // The C++ side expects a Global<Context>* which it will use and clean up
    const global_context = ffi.v8_Context_GlobalHandle_New(isolate, context);
    if (global_context == null) {
        std.log.err("[ShadowRealm] Failed to create global handle for context", .{});
        ffi.v8_Context_Dispose(context);
        return null;
    }

    // Register the ShadowRealm context in the context manager
    // This enables dynamic import to work correctly with ShadowRealm contexts
    if (callback_data) |data| {
        // Use the callback data's allocator for the context entry
        _ = context_manager.getOrCreate(context, data.allocator) catch |err| {
            std.log.warn("[ShadowRealm] Failed to register context in manager: {}", .{err});
        };
    }

    // Track the ShadowRealm for lifetime management
    if (callback_data) |data| {
        const entry = ShadowRealmEntry{
            .context_handle = global_context,
            .initiator_context = initiator_context_ptr,
            .created_at = std.time.timestamp(),
        };
        data.tracked_realms.put(@intFromPtr(global_context), entry) catch {
            std.log.warn("[ShadowRealm] Failed to track ShadowRealm context", .{});
        };
        data.total_created += 1;
        std.log.info("[ShadowRealm] Created ShadowRealm #{d} from snapshot", .{data.total_created});
    } else {
        std.log.info("[ShadowRealm] Created new ShadowRealm context from snapshot", .{});
    }

    return global_context;
}

/// Initialize ShadowRealm support for an isolate
///
/// This registers the HostCreateShadowRealmContextCallback with V8.
/// Must be called after the isolate is created and before any JavaScript
/// that uses ShadowRealm is executed.
///
/// @param isolate - V8 isolate to configure
/// @param allocator - Allocator for internal tracking
pub fn initializeShadowRealmSupport(isolate: *ffi.Isolate, allocator: std.mem.Allocator) !void {
    // Create callback data if not already created
    if (g_callback_data == null) {
        g_callback_data = try allocator.create(ShadowRealmCallbackData);
        g_callback_data.?.* = .{
            .allocator = allocator,
            .tracked_realms = std.AutoHashMap(usize, ShadowRealmEntry).init(allocator),
            .total_created = 0,
        };
    }

    // Register the callback with V8
    ffi.v8_Isolate_SetHostCreateShadowRealmContextCallback(
        isolate,
        g_callback_data,
        shadowRealmContextCallback,
    );

    std.log.info("[ShadowRealm] Registered HostCreateShadowRealmContextCallback", .{});
}

/// Cleanup ShadowRealm support
///
/// Call this when disposing the isolate to free resources.
/// This disposes all tracked ShadowRealm context handles.
pub fn deinitializeShadowRealmSupport() void {
    if (g_callback_data) |data| {
        // Dispose all tracked ShadowRealm contexts
        var iter = data.tracked_realms.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.context_handle) |handle| {
                ffi.v8_Context_GlobalHandle_Dispose(handle);
            }
        }
        const count = data.tracked_realms.count();
        data.tracked_realms.deinit();

        std.log.info("[ShadowRealm] Cleaned up {d} tracked ShadowRealm contexts (total created: {d})", .{ count, data.total_created });

        data.allocator.destroy(data);
        g_callback_data = null;
    }
}

/// Dispose a specific ShadowRealm context
///
/// Call this when a ShadowRealm is garbage collected or explicitly disposed.
/// Removes the context from tracking and disposes its global handle.
///
/// @param context_handle - The global handle to the ShadowRealm context
pub fn disposeShadowRealm(context_handle: ?*anyopaque) void {
    if (context_handle == null) return;

    if (g_callback_data) |data| {
        const key = @intFromPtr(context_handle);
        if (data.tracked_realms.fetchRemove(key)) |entry| {
            if (entry.value.context_handle) |handle| {
                ffi.v8_Context_GlobalHandle_Dispose(handle);
            }
            std.log.debug("[ShadowRealm] Disposed ShadowRealm context", .{});
        }
    }
}

/// Dispose all ShadowRealm contexts created from a specific initiator
///
/// Call this when an initiator context (Window, Worker, etc.) is disposed.
/// This ensures ShadowRealms don't outlive their creating context.
///
/// @param initiator_context - The initiator context handle
pub fn disposeByInitiator(initiator_context: ?*anyopaque) void {
    if (initiator_context == null) return;

    if (g_callback_data) |data| {
        var to_remove: std.ArrayList(usize) = std.ArrayList(usize).init(data.allocator);
        defer to_remove.deinit();

        // Find all ShadowRealms created by this initiator
        var iter = data.tracked_realms.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.initiator_context == initiator_context) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        // Remove and dispose them
        for (to_remove.items) |key| {
            if (data.tracked_realms.fetchRemove(key)) |entry| {
                if (entry.value.context_handle) |handle| {
                    ffi.v8_Context_GlobalHandle_Dispose(handle);
                }
            }
        }

        if (to_remove.items.len > 0) {
            std.log.info("[ShadowRealm] Disposed {d} ShadowRealm contexts for initiator", .{to_remove.items.len});
        }
    }
}

/// Get the count of currently tracked ShadowRealm contexts
pub fn getTrackedCount() usize {
    if (g_callback_data) |data| {
        return data.tracked_realms.count();
    }
    return 0;
}

/// Get the total number of ShadowRealm contexts created
pub fn getTotalCreated() usize {
    if (g_callback_data) |data| {
        return data.total_created;
    }
    return 0;
}

test "ShadowRealm callback data initialization" {
    const allocator = std.testing.allocator;

    // Cleanup any existing data
    deinitializeShadowRealmSupport();

    // Cannot test full initialization without V8, but can test data structures
    const data = try allocator.create(ShadowRealmCallbackData);
    defer {
        data.tracked_realms.deinit();
        allocator.destroy(data);
    }

    data.* = .{
        .allocator = allocator,
        .tracked_realms = std.AutoHashMap(usize, ShadowRealmEntry).init(allocator),
        .total_created = 0,
    };

    try std.testing.expect(data.allocator.ptr == allocator.ptr);
    try std.testing.expectEqual(@as(usize, 0), data.tracked_realms.count());
    try std.testing.expectEqual(@as(usize, 0), data.total_created);
}

test "ShadowRealm entry tracking" {
    const allocator = std.testing.allocator;

    var tracked_realms = std.AutoHashMap(usize, ShadowRealmEntry).init(allocator);
    defer tracked_realms.deinit();

    // Add a test entry
    const entry = ShadowRealmEntry{
        .context_handle = @ptrFromInt(0x1234),
        .initiator_context = @ptrFromInt(0x5678),
        .created_at = 12345,
    };
    try tracked_realms.put(0x1234, entry);

    try std.testing.expectEqual(@as(usize, 1), tracked_realms.count());

    // Retrieve entry
    const retrieved = tracked_realms.get(0x1234);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(@as(i64, 12345), retrieved.?.created_at);

    // Remove entry
    _ = tracked_realms.remove(0x1234);
    try std.testing.expectEqual(@as(usize, 0), tracked_realms.count());
}
