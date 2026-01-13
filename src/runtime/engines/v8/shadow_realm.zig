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

const std = @import("std");
const ffi = @import("ffi.zig");
const SnapshotContextIndex = @import("snapshot_context_index.zig").SnapshotContextIndex;

/// User data passed to the ShadowRealm callback
const ShadowRealmCallbackData = struct {
    /// Allocator for context tracking
    allocator: std.mem.Allocator,
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
    _ = user_data;
    _ = initiator_context_ptr;

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

    std.log.info("[ShadowRealm] Created new ShadowRealm context from snapshot", .{});
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
pub fn deinitializeShadowRealmSupport() void {
    if (g_callback_data) |data| {
        data.allocator.destroy(data);
        g_callback_data = null;
    }
}

test "ShadowRealm callback data initialization" {
    const allocator = std.testing.allocator;

    // Cleanup any existing data
    deinitializeShadowRealmSupport();

    // Cannot test full initialization without V8, but can test data structures
    const data = try allocator.create(ShadowRealmCallbackData);
    defer allocator.destroy(data);

    data.* = .{
        .allocator = allocator,
    };

    try std.testing.expect(data.allocator.ptr == allocator.ptr);
}
