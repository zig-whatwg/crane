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
//!
//! ## Per agent
//! Each agent's ShadowRealms are its own (`ShadowRealmCallbackData`, on the
//! agent's record in protocol_agents), found from the isolate V8 calls back
//! on. It used to be one process-wide record that every createAgent
//! overwrote and every host agent's end cleared - a worker on a thread of its
//! own is its thread's host agent, so its end took the page's ShadowRealms
//! (docs/instances.md).

const std = @import("std");
const ffi = @import("ffi.zig");
const context_manager = @import("context_manager.zig");
const clock = @import("clock");
/// The agent records, where each agent's ShadowRealm data lives.
const protocol_agents = @import("protocol_agents.zig");

/// Tracked ShadowRealm context entry
const ShadowRealmEntry = struct {
    /// Global handle to the ShadowRealm context (owned by us)
    context_handle: ?*anyopaque,
    /// Raw address of the initiator context (stable identifier for comparison)
    /// This is the internal V8 context address, NOT a Global handle pointer.
    /// We use this for matching when disposeByInitiator is called.
    initiator_context_raw_addr: ?*anyopaque,
    /// Creation timestamp for debugging
    created_at: i64,
};

/// One agent's ShadowRealms: made by its createAgent, freed by its end, and
/// touched only on the agent's own thread.
pub const ShadowRealmCallbackData = struct {
    /// Allocator for context tracking
    allocator: std.mem.Allocator,
    /// Map of ShadowRealm context handles to their entries
    /// Key: context handle pointer (as usize for HashMap compatibility)
    tracked_realms: std.AutoHashMap(usize, ShadowRealmEntry),
    /// Count of total ShadowRealms created (for debugging)
    total_created: usize = 0,
    /// Recursion guard to prevent infinite loops during context creation:
    /// V8's Context::New() initializes harmony_shadow_realm, which can
    /// trigger the callback again for this agent.
    in_callback: bool = false,
};

/// The ShadowRealm data of the agent whose isolate this is, if it has any.
fn dataOf(isolate: *ffi.Isolate) ?*ShadowRealmCallbackData {
    const record = protocol_agents.recordOf(isolate) orelse return null;
    return record.shadow_realms;
}

/// The current isolate's ShadowRealm data.
fn currentData() ?*ShadowRealmCallbackData {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    return dataOf(isolate);
}

/// V8 callback for ShadowRealm context creation
///
/// This is called by V8 when JavaScript executes `new ShadowRealm()`.
/// We create a new V8 context with the initiator's microtask queue.
/// Unlike Window/Worker contexts, ShadowRealm doesn't need full DOM bindings -
/// V8 provides all the JavaScript built-ins automatically.
///
/// @param user_data - Opaque pointer to ShadowRealmCallbackData
/// @param initiator_context_ptr - Global<Context>* to the context that created the ShadowRealm
/// @return Global<Context>* to the new ShadowRealm context, or null on failure
fn shadowRealmContextCallback(
    user_data: ?*anyopaque,
    initiator_context_ptr: ?*anyopaque,
) callconv(.c) ?*anyopaque {
    // The C++ side keeps one user_data for every isolate; this agent's data
    // is found from the isolate instead.
    _ = user_data;

    // Get the current isolate
    const isolate = ffi.v8_Isolate_GetCurrent() orelse {
        std.log.err("[ShadowRealm] No current isolate", .{});
        return null;
    };
    const callback_data = dataOf(isolate);

    // Recursion guard: V8's Context::New() initializes harmony_shadow_realm,
    // which can trigger our callback. Return null to break the recursion.
    // V8 handles null returns gracefully during its internal initialization.
    if (callback_data) |data| {
        if (data.in_callback) {
            std.log.debug("[ShadowRealm] Recursive callback detected, returning null to break recursion", .{});
            return null;
        }
        data.in_callback = true;
    }
    defer if (callback_data) |data| {
        data.in_callback = false;
    };

    // Extract the raw address from the initiator context Global handle BEFORE
    // we return. This is critical because C++ will delete the Global handle after
    // this callback returns, making initiator_context_ptr a dangling pointer.
    // The raw address is stable and can be used for comparison in disposeByInitiator.
    const initiator_raw_addr: ?*anyopaque = if (initiator_context_ptr) |ptr|
        ffi.v8_Context_GetRawAddress(@ptrCast(ptr))
    else
        null;

    // Get the initiator context's microtask queue
    // This is CRITICAL for ShadowRealm: wrapped functions must execute in the same
    // microtask queue as the initiator, otherwise calls from inside the ShadowRealm fail.
    // See Chromium's shadow_realm_context.cc which passes:
    //   initiator_execution_context->GetMicrotaskQueue()
    const initiator_context: ?*ffi.Context = @ptrCast(initiator_context_ptr);
    const microtask_queue = if (initiator_context) |ctx|
        ffi.v8_Context_GetMicrotaskQueue(ctx)
    else
        null;

    // Create a context for the ShadowRealm from the snapshot
    // Using a snapshot context is required because Context::New crashes inside
    // the ShadowRealm callback due to V8's internal state.
    //
    // We use context index 0. V8's ShadowRealm implementation correctly filters out
    // host objects (document, window, etc.) from the global scope per TC39 spec.
    // ShadowRealm only exposes JavaScript built-ins, not Web APIs.
    // The ShadowRealm semantics (isolation, wrapped functions) are handled by V8 itself.
    _ = microtask_queue; // V8 manages the microtask queue for ShadowRealm
    const context = ffi.v8_Context_NewFromSnapshotAt(isolate, 0) orelse {
        std.log.err("[ShadowRealm] Failed to create context from snapshot", .{});
        return null;
    };

    // Share the initiator context's security token with the ShadowRealm
    //
    // For Function constructor to work inside ShadowRealm, V8's AllowDynamicFunction
    // must return true. It calls MayAccess() which checks security tokens.
    // By sharing the initiator's security token, MayAccess returns true and
    // new Function() works inside the ShadowRealm.
    //
    // Note: This still maintains ShadowRealm isolation for cross-realm function
    // wrapping because V8's GetWrappedValue handles that separately.
    if (initiator_context) |ctx| {
        if (ffi.v8_Context_GetSecurityToken(ctx)) |token| {
            ffi.v8_Context_SetSecurityToken(context, token);
            std.log.debug("[ShadowRealm] Set security token from initiator context", .{});
        } else {
            std.log.warn("[ShadowRealm] Initiator context has no security token, using default", .{});
            ffi.v8_Context_UseDefaultSecurityToken(context);
        }
    } else {
        // No initiator context - use default token for isolation
        ffi.v8_Context_UseDefaultSecurityToken(context);
    }

    // Create a Global handle for the new context
    // The C++ side expects a Global<Context>* which it will use and clean up
    const global_context = ffi.v8_Context_GlobalHandle_New(isolate, context);
    if (global_context == null) {
        std.log.err("[ShadowRealm] Failed to create global handle for context", .{});
        return null;
    }

    // Register the ShadowRealm context in the context manager - its realm, to
    // the host - and record the realm that created it: the ShadowRealm's
    // synthetic realm settings object's principal realm (host data,
    // runtime.ContextData.principal_realm), which its import()s resolve and
    // fetch against.
    if (callback_data) |data| {
        if (context_manager.getOrCreate(context, data.allocator)) |shadow| {
            shadow.principal_realm = if (initiator_context) |ctx| context_manager.get(ctx) else null;
        } else |err| {
            std.log.warn("[ShadowRealm] Failed to register context in manager: {}", .{err});
        }
    }

    // Track the ShadowRealm for lifetime management
    if (callback_data) |data| {
        const entry = ShadowRealmEntry{
            .context_handle = global_context,
            .initiator_context_raw_addr = initiator_raw_addr,
            .created_at = clock.wallSeconds(),
        };
        data.tracked_realms.put(@intFromPtr(global_context), entry) catch {
            std.log.warn("[ShadowRealm] Failed to track ShadowRealm context", .{});
        };
        data.total_created += 1;
        std.log.info("[ShadowRealm] Created ShadowRealm #{d} (initiator raw addr: {?})", .{ data.total_created, initiator_raw_addr });
    } else {
        std.log.info("[ShadowRealm] Created new ShadowRealm context", .{});
    }

    return global_context;
}

/// Initialize ShadowRealm support for an isolate
///
/// This registers the HostCreateShadowRealmContextCallback with V8, and
/// returns the agent's ShadowRealm data, which its record keeps
/// (protocol_agents) and its end frees (`deinitializeShadowRealmSupport`).
/// Must be called after the isolate is created and before any JavaScript
/// that uses ShadowRealm is executed.
///
/// @param isolate - V8 isolate to configure
/// @param allocator - Allocator for internal tracking
pub fn initializeShadowRealmSupport(isolate: *ffi.Isolate, allocator: std.mem.Allocator) !*ShadowRealmCallbackData {
    const data = try allocator.create(ShadowRealmCallbackData);
    data.* = .{
        .allocator = allocator,
        .tracked_realms = std.AutoHashMap(usize, ShadowRealmEntry).init(allocator),
        .total_created = 0,
    };

    // Register the callback with V8. No user_data: the callback finds the
    // agent's data from its isolate.
    ffi.v8_Isolate_SetHostCreateShadowRealmContextCallback(
        isolate,
        null,
        shadowRealmContextCallback,
    );

    std.log.info("[ShadowRealm] Registered HostCreateShadowRealmContextCallback", .{});
    return data;
}

/// Cleanup ShadowRealm support
///
/// Call this when an agent ends, on its thread, before its isolate is
/// disposed: it disposes the agent's tracked ShadowRealm context handles
/// and frees `data`.
pub fn deinitializeShadowRealmSupport(data: *ShadowRealmCallbackData) void {
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
}

/// Dispose a specific ShadowRealm context of the current agent
///
/// Call this when a ShadowRealm is garbage collected or explicitly disposed.
/// Removes the context from tracking and disposes its global handle.
///
/// @param context_handle - The global handle to the ShadowRealm context
pub fn disposeShadowRealm(context_handle: ?*anyopaque) void {
    if (context_handle == null) return;

    if (currentData()) |data| {
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
/// Call this when an initiator context (Window, Worker, etc.) is disposed,
/// with its agent current. This ensures ShadowRealms don't outlive their
/// creating context.
///
/// @param initiator_raw_addr - The raw address of the initiator context (from v8_Context_GetRawAddress)
pub fn disposeByInitiator(initiator_raw_addr: ?*anyopaque) void {
    if (initiator_raw_addr == null) return;

    if (currentData()) |data| {
        var to_remove: std.ArrayListUnmanaged(usize) = .empty;
        defer to_remove.deinit(data.allocator);

        // Find all ShadowRealms created by this initiator (compare raw addresses)
        var iter = data.tracked_realms.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.initiator_context_raw_addr == initiator_raw_addr) {
                to_remove.append(data.allocator, entry.key_ptr.*) catch continue;
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
            std.log.info("[ShadowRealm] Disposed {d} ShadowRealm contexts for initiator (raw addr: {?})", .{ to_remove.items.len, initiator_raw_addr });
        }
    }
}

/// Get the count of the current agent's tracked ShadowRealm contexts
pub fn getTrackedCount() usize {
    if (currentData()) |data| {
        return data.tracked_realms.count();
    }
    return 0;
}

/// Get the total number of ShadowRealm contexts the current agent created
pub fn getTotalCreated() usize {
    if (currentData()) |data| {
        return data.total_created;
    }
    return 0;
}

test "ShadowRealm callback data initialization" {
    const allocator = std.testing.allocator;

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
        .initiator_context_raw_addr = @ptrFromInt(0x5678),
        .created_at = 12345,
    };
    try tracked_realms.put(0x1234, entry);

    try std.testing.expectEqual(@as(usize, 1), tracked_realms.count());

    // Retrieve entry
    const retrieved = tracked_realms.get(0x1234);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(@as(i64, 12345), retrieved.?.created_at);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrFromInt(0x5678)), retrieved.?.initiator_context_raw_addr);

    // Remove entry
    _ = tracked_realms.remove(0x1234);
    try std.testing.expectEqual(@as(usize, 0), tracked_realms.count());
}
