//! Implementation for ProgressEvent interface
//!
//! XMLHttpRequest Standard: https://xhr.spec.whatwg.org/#progressevent
//!
//! ProgressEvent extends Event with progress-related properties for tracking
//! async operations like file reading, XMLHttpRequest, and Fetch.
//!
//! Used by: FileReader, XMLHttpRequest, Fetch API

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ProgressEvent = interfaces.ProgressEvent;
const Event = interfaces.Event;
const EventImpl = @import("Event.zig");

pub const State = ProgressEvent.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for ProgressEvent
///
/// ProgressEvent adds three readonly attributes on top of Event:
/// - lengthComputable: whether the total size is known
/// - loaded: bytes transferred so far
/// - total: total bytes to transfer (0 if unknown)
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    length_computable: bool,
    loaded: f64,
    total: f64,
};

/// Get internal state from instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
///
/// Spec: https://xhr.spec.whatwg.org/#dom-progressevent-progressevent
///
/// The ProgressEvent(type, eventInitDict) constructor steps are:
/// 1. Set this's initialized flag via Event constructor (handled by V8 prototype chain)
/// 2. Set lengthComputable, loaded, total from eventInitDict
///
/// Note: ProgressEvent inherits from Event via prototype chain (BaseType = *Event).
/// The Event properties (type, bubbles, cancelable, etc.) are handled at the V8/JS level.
/// We only need to initialize ProgressEvent's own properties here.
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, event_type: runtime.DOMString, eventInitDict: dictionaries.ProgressEventInit) !*runtime.Instance {
    _ = event_type; // Event type is handled by V8 Event prototype

    // Create instance through init()
    const instance = try init(allocator, State, &ProgressEvent.vtable, ctx);
    errdefer deinit(instance);

    // Get state
    const state = instance.getState(State);

    // Create internal state for ProgressEvent-specific properties
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .allocator = allocator,
        .length_computable = eventInitDict.lengthComputable orelse false,
        .loaded = eventInitDict.loaded orelse 0,
        .total = eventInitDict.total orelse 0,
    };
    state.own._internal = internal;

    // Set the flattened state properties for direct access
    state.own.lengthComputable = internal.length_computable;
    state.own.loaded = internal.loaded;
    state.own.total = internal.total;

    return instance;
}

/// Getter for lengthComputable
///
/// Spec: https://xhr.spec.whatwg.org/#dom-progressevent-lengthcomputable
///
/// Returns true if the progress can be calculated (total is known).
pub fn get_lengthComputable(instance: *runtime.Instance) ImplError!bool {
    const internal = getInternal(instance) orelse {
        // Fall back to state
        const state = instance.getState(State);
        return state.own.lengthComputable;
    };
    return internal.length_computable;
}

/// Getter for loaded
///
/// Spec: https://xhr.spec.whatwg.org/#dom-progressevent-loaded
///
/// Returns the number of bytes transferred so far.
pub fn get_loaded(instance: *runtime.Instance) ImplError!f64 {
    const internal = getInternal(instance) orelse {
        // Fall back to state
        const state = instance.getState(State);
        return state.own.loaded;
    };
    return internal.loaded;
}

/// Getter for total
///
/// Spec: https://xhr.spec.whatwg.org/#dom-progressevent-total
///
/// Returns the total number of bytes to be transferred.
/// Returns 0 if lengthComputable is false.
pub fn get_total(instance: *runtime.Instance) ImplError!f64 {
    const internal = getInternal(instance) orelse {
        // Fall back to state
        const state = instance.getState(State);
        return state.own.total;
    };
    return internal.total;
}

// ============================================================================
// Helper functions for creating ProgressEvents
// ============================================================================

/// Create a ProgressEvent with the given parameters
///
/// This is a convenience function for internal use (e.g., FileReader)
/// that creates a fully initialized ProgressEvent.
pub fn create(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    event_type: []const u8,
    length_computable: bool,
    loaded: u64,
    total: u64,
) !*runtime.Instance {
    return call_constructor(
        allocator,
        ctx,
        runtime.DOMString.initInterned(event_type),
        .{
            .base = .{
                .bubbles = false, // ProgressEvents don't bubble
                .cancelable = false, // ProgressEvents are not cancelable
                .composed = false,
            },
            .lengthComputable = length_computable,
            .loaded = @floatFromInt(loaded),
            .total = @floatFromInt(total),
        },
    );
}

// ============================================================================
// Tests
// ============================================================================

test "ProgressEvent - constructor with defaults" {
    const allocator = std.testing.allocator;

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const event = try call_constructor(
        allocator,
        ctx,
        runtime.DOMString.initInterned("progress"),
        .{ .base = .{} },
    );
    defer deinit(event);

    // Check defaults
    try std.testing.expectEqual(false, try get_lengthComputable(event));
    try std.testing.expectEqual(@as(f64, 0), try get_loaded(event));
    try std.testing.expectEqual(@as(f64, 0), try get_total(event));
}

test "ProgressEvent - constructor with values" {
    const allocator = std.testing.allocator;

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const event = try call_constructor(
        allocator,
        ctx,
        runtime.DOMString.initInterned("load"),
        .{
            .base = .{ .bubbles = false, .cancelable = false },
            .lengthComputable = true,
            .loaded = 500,
            .total = 1000,
        },
    );
    defer deinit(event);

    try std.testing.expectEqual(true, try get_lengthComputable(event));
    try std.testing.expectEqual(@as(f64, 500), try get_loaded(event));
    try std.testing.expectEqual(@as(f64, 1000), try get_total(event));
}

test "ProgressEvent - create helper" {
    const allocator = std.testing.allocator;

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const event = try create(allocator, ctx, "loadend", true, 1024, 2048);
    defer deinit(event);

    try std.testing.expectEqual(true, try get_lengthComputable(event));
    try std.testing.expectEqual(@as(f64, 1024), try get_loaded(event));
    try std.testing.expectEqual(@as(f64, 2048), try get_total(event));
}
