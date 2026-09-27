//! WebIDL numeric conversions of a value an impl holds unconverted - the V8
//! side of the Engine table's convertToUnrestrictedDouble (AGENTS.md, "The
//! engine boundary"). Kept apart from the engine-boundary lane's
//! webidl_conversions.zig until the integrator consolidates them.

const std = @import("std");
const runtime = @import("runtime");
const EngineError = runtime.EngineError;
const JSValue = runtime.JSValue;

const ffi = @import("ffi.zig");
const realm_entry = @import("realm_entry.zig");

const ToNumber = struct {
    value: *ffi.Value,
    context: *ffi.Context,
    result: f64 = 0,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *ToNumber = @ptrCast(@alignCast(data.?));
        self.result = ffi.v8_Value_NumberValue(self.value, self.context);
    }
};

/// WebIDL "convert to unrestricted double" (§ 3.2.5): ? ToNumber(value). What
/// ToNumber throws - a TypeError for a Symbol or a BigInt, or whatever a
/// valueOf throws - is rethrown and reported as ExceptionPending.
pub fn convertToUnrestrictedDouble(realm: runtime.Context, value: JSValue) EngineError!f64 {
    switch (value) {
        // The binding's own classifications: no script can run for these.
        .number => |n| return n,
        .boolean => |b| return if (b) 1 else 0,
        .null => return 0,
        .undefined => return std.math.nan(f64),
        else => {},
    }
    const entered = try realm_entry.enter(realm);
    defer entered.leave();
    const engine_value = try realm_entry.EngineValue.of(entered.isolate, entered.context(), value);
    defer engine_value.release();

    var to_number: ToNumber = .{ .value = engine_value.ptr, .context = entered.context() };
    var exception: ?*ffi.Value = null;
    if (ffi.v8_RunCatching(entered.isolate, ToNumber.run, &to_number, &exception)) {
        if (exception) |e| {
            ffi.v8_Isolate_ThrowException(entered.isolate, e);
            ffi.v8_Global_Dispose(e);
        }
        return EngineError.ExceptionPending;
    }
    return to_number.result;
}
