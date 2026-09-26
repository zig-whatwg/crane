//! DOM § 6 "filter", steps 6 and 8, shared by NodeIterator and TreeWalker:
//! call the traverser's NodeFilter and convert what it answers.
//!
//! The filter is a WebIDL callback interface: a function, or an object whose
//! `acceptNode` is looked up when it is called. Either way the call is the
//! Engine table's callUserObjectOperation, which performs that lookup and
//! rethrows what the filter throws - step 8.
//! The active flag (steps 1, 5 and 7) stays with each traverser.

const std = @import("std");
const runtime = @import("runtime");

/// Invoke `filter` with « node » and return its answer as an unsigned short,
/// or `error.ExceptionPending` once the exception it threw has been rethrown.
///
/// The call is made from the current realm - the traversal method's - as
/// script calling the traverser would make it.
pub fn call(filter: *runtime.CallbackWrapper, node: *runtime.Instance) Error!u16 {
    const engine = node.ctx.getEngine() orelse return error.InvalidStateError;
    const call_operation = engine.callUserObjectOperation orelse return error.InvalidStateError;
    const to_number = engine.convertToUnrestrictedDouble orelse return error.InvalidStateError;
    const current_realm = engine.currentRealm orelse return error.InvalidStateError;
    const realm = current_realm() orelse node.ctx;

    // Step 6: "call a user object's operation" acceptNode with « node »; step
    // 8's "If an exception was thrown, re-throw the exception" is the
    // operation's "rethrow" - it comes back as ExceptionPending.
    const result = call_operation(realm, filter, "acceptNode", &.{runtime.JSValue.fromInstance(node)}) catch |err|
        return traverserError(err);
    defer if (engine.releaseValue) |release_value| release_value(result);

    // The callback's return type is `unsigned short`: ToNumber - which throws
    // for a Symbol or a BigInt - then ConvertToInt.
    const number = to_number(realm, result) catch |err| return traverserError(err);
    return convertToUnsignedShort(number);
}

/// What `call` fails with: the traversers' own errors.
pub const Error = error{ ExceptionPending, InvalidStateError, NotImplemented, OutOfMemory };

/// An Engine operation's failure as a traverser reports it: a pending
/// exception stays pending; anything else means the engine could not make
/// the call at all.
fn traverserError(err: runtime.EngineError) Error {
    return switch (err) {
        error.ExceptionPending => error.ExceptionPending,
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

/// WebIDL § 3.2.4 ConvertToInt for `unsigned short`, steps 6-10, of a number
/// ToNumber produced: NaN, +-0 and +-Infinity give 0; anything else is
/// truncated and wrapped modulo 2^16.
fn convertToUnsignedShort(x: f64) u16 {
    if (std.math.isNan(x) or std.math.isInf(x) or x == 0) return 0;
    const wrapped = @mod(@trunc(x), 65536.0);
    return @intFromFloat(wrapped);
}

/// The filter as script sees it: `nodeIterator.filter`, `treeWalker.filter`.
pub fn fromStored(stored: ?*anyopaque) ?*runtime.CallbackWrapper {
    const raw = stored orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// Release a stored filter: the engine's wrapper (and the Global it holds),
/// then the runtime wrapper, which the conversion allocated.
pub fn release(stored: ?*anyopaque) void {
    const filter = fromStored(stored) orelse return;
    filter.deinit();
    filter.allocator.destroy(filter);
}

test "ConvertToInt for unsigned short wraps modulo 2^16 and truncates toward zero" {
    try std.testing.expectEqual(@as(u16, 0), convertToUnsignedShort(std.math.nan(f64)));
    try std.testing.expectEqual(@as(u16, 0), convertToUnsignedShort(std.math.inf(f64)));
    try std.testing.expectEqual(@as(u16, 0), convertToUnsignedShort(-0.0));
    try std.testing.expectEqual(@as(u16, 1), convertToUnsignedShort(1.9));
    try std.testing.expectEqual(@as(u16, 65535), convertToUnsignedShort(-1));
    try std.testing.expectEqual(@as(u16, 65535), convertToUnsignedShort(-1.5));
    try std.testing.expectEqual(@as(u16, 2), convertToUnsignedShort(65538));
    try std.testing.expectEqual(@as(u16, 3), convertToUnsignedShort(3));
}
