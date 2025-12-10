//! Implementation for IdleDeadline interface
//!
//! Spec: https://w3c.github.io/requestidlecallback/#the-idledeadline-interface
//! This interface is used to determine the time remaining for idle callbacks.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const IdleDeadline = interfaces.IdleDeadline;

pub const State = IdleDeadline.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Internal state for IdleDeadline implementation
/// Stores the deadline timestamp and whether this was invoked due to timeout.
pub const InternalState = struct {
    /// The deadline timestamp (in milliseconds since epoch)
    /// After this time, the browser wants to do other work.
    deadline: i64,

    /// Whether this callback was invoked because the timeout expired
    /// rather than because the browser had idle time.
    did_timeout: bool,

    /// Allocator
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, deadline: i64, did_timeout: bool) InternalState {
        return .{
            .deadline = deadline,
            .did_timeout = did_timeout,
            .allocator = allocator,
        };
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

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

/// Create an IdleDeadline instance with specific deadline and timeout info
pub fn createWithDeadline(
    allocator: std.mem.Allocator,
    deadline: i64,
    did_timeout: bool,
) !*runtime.Instance {
    const instance = try init(allocator, State, &IdleDeadline.vtable, .{});
    errdefer deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator, deadline, did_timeout);
    try Registry.set(instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.allocator.destroy(internal);
    }
    Registry.remove(instance);
}

/// Getter for didTimeout
/// Spec: Returns true if the callback was invoked because timeout expired,
/// false if invoked during an idle period.
pub fn get_didTimeout(instance: *runtime.Instance) anyerror!bool {
    const internal = Registry.get(instance) orelse return false;
    return internal.did_timeout;
}

/// Operation: timeRemaining
/// Spec: Returns the estimated number of milliseconds remaining in the current
/// idle period. If the deadline has passed, returns 0.
pub fn call_timeRemaining(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    const internal = Registry.get(instance) orelse return 0;

    const now = std.time.milliTimestamp();
    const remaining = internal.deadline - now;

    // Return 0 if deadline has passed, otherwise return remaining time
    return if (remaining > 0) @floatFromInt(remaining) else 0;
}

// ============================================================================
// Tests
// ============================================================================

test "IdleDeadline - didTimeout returns correct value" {
    const allocator = std.testing.allocator;

    // Test with did_timeout = false
    {
        const future_deadline = std.time.milliTimestamp() + 1000;
        const deadline = try createWithDeadline(allocator, future_deadline, false);
        defer deinit(deadline);

        try std.testing.expectEqual(false, try get_didTimeout(deadline));
    }

    // Test with did_timeout = true
    {
        const future_deadline = std.time.milliTimestamp() + 1000;
        const deadline = try createWithDeadline(allocator, future_deadline, true);
        defer deinit(deadline);

        try std.testing.expectEqual(true, try get_didTimeout(deadline));
    }
}

test "IdleDeadline - timeRemaining returns positive for future deadline" {
    const allocator = std.testing.allocator;

    // Set deadline 1 second in the future
    const future_deadline = std.time.milliTimestamp() + 1000;
    const deadline = try createWithDeadline(allocator, future_deadline, false);
    defer deinit(deadline);

    const remaining = try call_timeRemaining(deadline);

    // Should have some time remaining (less than 1000ms due to execution time)
    try std.testing.expect(remaining > 0);
    try std.testing.expect(remaining <= 1000);
}

test "IdleDeadline - timeRemaining returns 0 for past deadline" {
    const allocator = std.testing.allocator;

    // Set deadline 1 second in the past
    const past_deadline = std.time.milliTimestamp() - 1000;
    const deadline = try createWithDeadline(allocator, past_deadline, true);
    defer deinit(deadline);

    const remaining = try call_timeRemaining(deadline);

    // Should be 0 since deadline has passed
    try std.testing.expectEqual(@as(typedefs.DOMHighResTimeStamp, 0), remaining);
}
