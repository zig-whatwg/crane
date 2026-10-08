//! HTML event handler IDL attribute access, owned by EventTarget.
//!
//! lint-impls: hook for EventTarget
const std = @import("std");
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

pub const Implementation = struct {
    get: *const fn (*runtime.Instance, []const u8) ?usize,
    set: *const fn (*runtime.Instance, []const u8, ?usize) anyerror!void,
    erase: *const fn (*runtime.Instance) void,
};

// process-wide: hook table written once at process start by EventTarget.installHooks (B0); comptime in B9
var implementation: ?Implementation = null;

/// Install the owner's steps before any Browser exists.
pub fn install(steps: Implementation) void {
    process_start.assertInstalling();
    implementation = steps;
}

/// Borrow the handler in the binding's representation.
pub inline fn get(comptime Handler: type, target: *runtime.Instance, event_type: []const u8) Handler {
    const address = (implementation orelse return null).get(target, event_type) orelse return null;
    return fromAddress(Handler, address);
}

/// Hand the binding's handler value to EventTarget, or deactivate it.
pub inline fn set(comptime Handler: type, target: *runtime.Instance, event_type: []const u8, value: Handler) !void {
    const steps = implementation orelse return error.NotSupported;
    return steps.set(target, event_type, toAddress(Handler, value));
}

/// HTML "erase all event listeners and handlers", including activated IDL
/// event handlers. document.open applies this to its shadow-including tree.
pub fn eraseAll(target: *runtime.Instance) void {
    const steps = implementation orelse return;
    steps.erase(target);
}

fn fromAddress(comptime Handler: type, address: usize) Handler {
    const Callable = @typeInfo(Handler).optional.child;
    comptime std.debug.assert(@sizeOf(Callable) == @sizeOf(usize));
    var handler: Callable = undefined;
    @memcpy(std.mem.asBytes(&handler), std.mem.asBytes(&address));
    return handler;
}

fn toAddress(comptime Handler: type, value: Handler) ?usize {
    const Callable = @typeInfo(Handler).optional.child;
    comptime std.debug.assert(@sizeOf(Callable) == @sizeOf(usize));
    const handler = value orelse return null;
    var address: usize = undefined;
    @memcpy(std.mem.asBytes(&address), std.mem.asBytes(&handler));
    return address;
}

test "event handler representation - null and callable round trip" {
    const Handler = ?*const fn () void;
    const function = struct {
        fn callback() void {}
    }.callback;
    const handler: Handler = &function;
    try std.testing.expect(toAddress(Handler, null) == null);
    try std.testing.expect(fromAddress(Handler, toAddress(Handler, handler).?) == handler);
}
