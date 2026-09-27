//! DOM § 6 "filter", steps 6 and 8, shared by NodeIterator and TreeWalker:
//! call the traverser's NodeFilter and convert what it answers.
//!
//! The filter is a WebIDL callback interface: a function, or an object whose
//! `acceptNode` is looked up when it is called. Either way the call is the
//! engine's "call a user object's operation", which performs that lookup,
//! and what the filter throws is rethrown - step 8.
//! The active flag (steps 1, 5 and 7) stays with each traverser.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

/// A traverser's filter: the value the binding converted - what the `filter`
/// attribute returns - and the callback interface value the calls are made
/// through, taken at the conversion, so that its callback context is the
/// incumbent realm of createNodeIterator() or createTreeWalker().
const Filter = struct {
    wrapper: *runtime.CallbackWrapper,
    callback: engine.CallbackInterface,
};

/// Keep `wrapper`, the filter argument the binding converted, as a
/// traverser's filter: null for none. The result is the traverser's, freed by
/// `release`; `wrapper` is the result's from here on, and is released here
/// if keeping it fails.
pub fn store(wrapper: ?*runtime.CallbackWrapper) error{OutOfMemory}!?*anyopaque {
    const converted = wrapper orelse return null;
    const filter = converted.allocator.create(Filter) catch |err| {
        releaseWrapper(converted);
        return err;
    };
    filter.* = .{ .wrapper = converted, .callback = engine.takeCallbackInterface(converted) };
    return filter;
}

/// Invoke the filter `stored` keeps with « node » and return its answer as an
/// unsigned short, or `error.ExceptionPending` once the exception it threw
/// has been rethrown.
///
/// The call is made from the current realm - the traversal method's - as
/// script calling the traverser would make it.
pub fn call(stored: *anyopaque, node: *runtime.Instance) Error!u16 {
    const filter: *Filter = @ptrCast(@alignCast(stored));
    const realm = engine.currentRealm() orelse node.ctx;

    // Step 6: "call a user object's operation" acceptNode with « node » and no
    // this value - the operation makes the filter object `this` when it gets
    // acceptNode from it. Step 8's "If an exception was thrown, re-throw the
    // exception" is the operation's "rethrow": what the filter threw comes
    // back as a throw completion, and is thrown on.
    const completion = engine.callUserObjectOperation(realm, &filter.callback, "acceptNode", .undefined, &.{.{ .instance = node }}, .rethrow) catch |err|
        return traverserError(err);
    const result = switch (completion) {
        .normal => |value| value,
        .throw => |exception| {
            defer exception.release();
            engine.throwValue(realm, exception.value) catch |err| return traverserError(err);
            return error.ExceptionPending;
        },
    };
    defer result.release();

    // The callback's return type is `unsigned short`: ToNumber - which throws
    // for a Symbol or a BigInt - then ConvertToInt.
    const number = engine.convertToUnrestrictedDouble(realm, result.value) catch |err| return traverserError(err);
    return convertToUnsignedShort(number);
}

/// What `call` fails with: the traversers' own errors.
pub const Error = error{ ExceptionPending, InvalidStateError, NotImplemented, OutOfMemory };

/// An engine operation's failure as a traverser reports it: a pending
/// exception stays pending; anything else means the engine could not make
/// the call at all.
fn traverserError(err: engine.Error) Error {
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
    const filter: *Filter = @ptrCast(@alignCast(stored orelse return null));
    return filter.wrapper;
}

/// Release a stored filter: the callback interface value, then the binding's
/// wrapper.
pub fn release(stored: ?*anyopaque) void {
    const filter: *Filter = @ptrCast(@alignCast(stored orelse return));
    const wrapper = filter.wrapper;
    filter.callback.release();
    wrapper.allocator.destroy(filter);
    releaseWrapper(wrapper);
}

/// The engine's wrapper (and the handle it holds), then the runtime wrapper,
/// which the conversion allocated.
fn releaseWrapper(wrapper: *runtime.CallbackWrapper) void {
    wrapper.deinit();
    wrapper.allocator.destroy(wrapper);
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
