//! Entering a realm, and handing a runtime.JSValue to V8 - shared by the
//! runtime-impls lane's adapter files (value_construction.zig,
//! callback_interfaces.zig, webidl_conversions_numeric.zig).
//!
//! A realm is entered as engine.zig's realm operations enter one: its agent
//! (isolate) when it is not the current one, then a HandleScope with its
//! context entered.

const runtime = @import("runtime");
const EngineError = runtime.EngineError;
const JSValue = runtime.JSValue;

const ffi = @import("ffi.zig");
const js_scope = @import("js_scope.zig");
const conversions = @import("conversions.zig");

/// A realm entered, until `leave`.
pub const Entered = struct {
    isolate: *ffi.Isolate,
    entered_isolate: bool,
    scope: js_scope.JsScope,

    pub fn context(self: Entered) *ffi.Context {
        return self.scope.context;
    }

    pub fn leave(self: Entered) void {
        self.scope.deinit();
        if (self.entered_isolate) ffi.v8_Isolate_Exit(self.isolate);
    }
};

/// The agent `realm` belongs to: the isolate recorded on it (a worker realm on
/// this thread needs that), else the current one.
pub fn agentOf(realm: runtime.Context) ?*ffi.Isolate {
    if (realm.realm) |r| {
        if (r.isolate) |isolate| return @ptrCast(@alignCast(isolate));
    }
    return ffi.v8_Isolate_GetCurrent();
}

pub fn enter(realm: runtime.Context) EngineError!Entered {
    const engine_ctx = realm.engine_ctx orelse return EngineError.OperationFailed;
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = agentOf(realm) orelse return EngineError.OperationFailed;
    const entered_isolate = ffi.v8_Isolate_GetCurrent() != isolate;
    if (entered_isolate) ffi.v8_Isolate_Enter(isolate);
    const scope = js_scope.JsScope.initFromV8Context(context) orelse {
        if (entered_isolate) ffi.v8_Isolate_Exit(isolate);
        return EngineError.OperationFailed;
    };
    return .{ .isolate = isolate, .entered_isolate = entered_isolate, .scope = scope };
}

/// `value` as a V8 value (a Global), and whether it was made for this call. A
/// handle and an instance's wrapper are borrowed as they are; anything else is
/// a new value `release` disposes.
pub const EngineValue = struct {
    ptr: *ffi.Value,
    made: bool,

    pub fn of(isolate: *ffi.Isolate, context: *ffi.Context, value: JSValue) EngineError!EngineValue {
        const ptr = conversions.toV8Value(JSValue, isolate, context, value) catch
            return EngineError.OperationFailed;
        return .{ .ptr = ptr, .made = switch (value) {
            .handle, .instance => false,
            else => true,
        } };
    }

    pub fn release(self: EngineValue) void {
        if (self.made) ffi.v8_Value_Dispose(self.ptr);
    }
};

/// A persistent handle the caller owns, as a JSValue.
pub fn owned(ptr: *anyopaque) JSValue {
    return .{ .handle = .{ .ptr = ptr, .needs_disposal = true, .handle_scope = .global } };
}
