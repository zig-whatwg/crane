//! The engine protocol's callback invocations (design section 4.4), as V8
//! implements them: WebIDL "invoke a callback function" (3.12) and "call a
//! user object's operation" (3.11), each returning ECMAScript's Completion
//! Record under the caller's exception behavior.
//!
//! The call runs in the callback's associated realm - "prepare to run script"
//! enters its context - and "clean up after running script" is V8's: the
//! browser leaves the automatic microtask policy in place, so when this call
//! is the outermost one the checkpoint runs as the call returns, before the
//! completion is reported, in WebIDL's order.
//!
//! Not yet: "prepare to run a callback" with the callback context (the
//! incumbent settings object) - the entry and incumbent realm stacks are the
//! realm operations' (design 4.2).
//!
//! The conversion of the completion's value to the callback's return type is
//! the caller's, and so is step 7 onwards of "invoke" for a promise return
//! type (a promise rejected with the thrown value): both need the type, which
//! only the caller knows.

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const js_scope = @import("js_scope.zig");
const realm_entry = @import("realm_entry.zig");
const support = @import("protocol_support.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Error = engine.Error;
const Completion = engine.Completion;

/// The most arguments a callback is called with here.
const max_arguments = 32;

/// The completion that is WebIDL's "the unique undefined IDL value".
const normal_undefined: Completion = .{ .normal = .{ .value = JSValue.jsUndefined } };

/// Where a callback runs: its associated realm's context, entered
/// ("prepare to run script" with the relevant settings object), and the
/// runtime realm the context manager hosts for it, when it hosts one.
const CallbackRealm = struct {
    scope: js_scope.JsScope,
    context: *ffi.Context,
    realm: ?Context,

    /// The associated realm of `object`: its creation context. A context V8
    /// cannot name (a revoked proxy's) is `fallback`'s.
    fn enter(object: *ffi.Value, fallback: support.Entered) Error!CallbackRealm {
        const context = ffi.v8_Object_GetCreationContext(@ptrCast(object)) orelse
            (ffi.v8_Isolate_GetCurrentContext(fallback.isolate) orelse return error.OperationFailed);
        const scope = js_scope.JsScope.initFromV8Context(context) orelse {
            ffi.v8_Context_Dispose(context);
            return error.OperationFailed;
        };
        return .{ .scope = scope, .context = context, .realm = support.associatedRealm(object) };
    }

    /// "Clean up after running script".
    fn leave(self: CallbackRealm) void {
        self.scope.deinit();
        ffi.v8_Context_Dispose(self.context);
    }
};

/// WebIDL "convert a Web IDL arguments list to a JavaScript arguments list":
/// each argument converted in the callback's realm. `values` owns what was
/// made for the call.
const Arguments = struct {
    values: [max_arguments]realm_entry.EngineValue = undefined,
    pointers: [max_arguments]*ffi.Value = undefined,
    count: usize = 0,

    fn convert(self: *Arguments, isolate: *ffi.Isolate, context: *ffi.Context, args: []const JSValue) Error!void {
        if (args.len > max_arguments) return error.OperationFailed;
        // 4. While i < args's size: append the converted value.
        for (args) |arg| {
            self.values[self.count] = realm_entry.EngineValue.of(isolate, context, arg) catch |err| return support.protocolError(err);
            self.pointers[self.count] = self.values[self.count].ptr;
            self.count += 1;
        }
    }

    fn slice(self: *const Arguments) []const *ffi.Value {
        return self.pointers[0..self.count];
    }

    fn release(self: *Arguments) void {
        for (self.values[0..self.count]) |value| value.release();
    }
};

/// The callback this value as a V8 receiver: undefined (null), `realm`'s
/// global this binding, or a value. `global` and `made` own what was made for
/// the call.
const Receiver = struct {
    value: ?*ffi.Value = null,
    global: ?*ffi.Object = null,
    made: ?*ffi.Value = null,

    fn of(entered: support.Entered, this_arg: engine.CallbackThis) Error!Receiver {
        return switch (this_arg) {
            .undefined => .{},
            // Context::Global is the global proxy: a Window realm's WindowProxy.
            .global_this => blk: {
                const global = ffi.v8_Context_Global(entered.context()) orelse return error.OperationFailed;
                break :blk .{ .value = @ptrCast(global), .global = global };
            },
            .value => |v| blk: {
                const held = try support.ownGlobal(entered, v);
                break :blk .{ .value = held, .made = held };
            },
        };
    }

    fn release(self: Receiver) void {
        if (self.global) |global| ffi.v8_Object_Dispose(global);
        if (self.made) |made| ffi.v8_Global_Dispose(made);
    }
};

/// Steps 14.3-14.6 of "invoke" (15.3-15.4 of "call a user object's
/// operation"): the completion as the caller's exception behavior has it.
/// Takes `thrown`.
fn abrupt(thrown: *ffi.Value, context: *ffi.Context, realm: ?Context, behavior: engine.ExceptionBehavior) Completion {
    switch (behavior) {
        // 5. If exceptionBehavior is "rethrow", throw completion.[[Value]] -
        //    handed back, for the caller to throw on or handle.
        .rethrow => return .{ .throw = support.owned(thrown) },
        // 6. Otherwise, if exceptionBehavior is "report":
        .report => |reporter| {
            defer ffi.v8_Global_Dispose(thrown);
            // 2. Report an exception completion.[[Value]] for realm's global
            //    object: the error information V8 has about it.
            const details = ffi.v8_Exception_GetErrorInfo(context, thrown);
            defer ffi.v8_FreeErrorInfo(details);
            var info: engine.ErrorInfo = .{
                .message = "Uncaught exception",
                .filename = "",
                .lineno = 0,
                .colno = 0,
                .error_value = support.borrowed(thrown),
                .realm = realm,
            };
            if (details) |d| {
                if (d.getMessage()) |message| info.message = message;
                if (d.getResourceName()) |resource| info.filename = resource;
                if (d.line_number > 0) info.lineno = @intCast(d.line_number);
                // V8 counts columns from 0; ErrorEvent.colno from 1.
                if (d.column_number >= 0) info.colno = @intCast(d.column_number + 1);
            }
            reporter.report(reporter.host, &info);
            // 3. Return the unique undefined IDL value.
            return normal_undefined;
        },
    }
}

/// Call(`function`, `receiver`, `args`) in `callback_realm`: the completion.
fn callCompletion(callback_realm: CallbackRealm, function: *ffi.Value, receiver: ?*ffi.Value, args: []const *ffi.Value, behavior: engine.ExceptionBehavior) Error!Completion {
    var threw = false;
    const result = ffi.v8_Function_CallCatching(callback_realm.context, function, receiver, @intCast(args.len), if (args.len == 0) null else args.ptr, &threw);
    // A terminating isolate has no value to hand back.
    const value = result orelse return error.OperationFailed;
    if (threw) return abrupt(value, callback_realm.context, callback_realm.realm, behavior);
    return .{ .normal = support.owned(value) };
}

/// WebIDL "invoke a callback function" (3.12), `realm` being where the
/// callback is read: a realm of its agent.
pub fn invokeCallbackFunction(realm: Context, callback: JSValue, this_arg: engine.CallbackThis, args: []const JSValue, behavior: engine.ExceptionBehavior) Error!Completion {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 1. Let completion be an uninitialized variable.
    // 2. If thisArg was not given, let thisArg be undefined (CallbackThis's
    //    `undefined`).
    // 3. Let F be the JavaScript object corresponding to callable.
    // 4. If IsCallable(F) is false - only possible for a
    //    [LegacyTreatNonObjectAsNull] attribute's value - return undefined
    //    converted to the return type (the caller's conversion).
    const function = support.handleOf(callback) orelse return normal_undefined;
    if (!ffi.v8_Value_IsFunction(function)) return normal_undefined;

    // 5. Let realm be F's associated realm.
    // 6-8. Prepare to run script with realm's settings object.
    const callback_realm = try CallbackRealm.enter(function, entered);
    defer callback_realm.leave();
    // 9. Prepare to run a callback with stored settings: not yet (above).

    // The callback this value, from where it was read.
    const receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();

    // 10. Let jsArgs be the result of converting args to a JavaScript
    //     arguments list.
    var js_args: Arguments = .{};
    defer js_args.release();
    try js_args.convert(entered.isolate, callback_realm.context, args);

    // 11. Let callResult be Completion(Call(F, thisArg, jsArgs)).
    // 12. If callResult is an abrupt completion, set completion to callResult.
    // 13. Set completion to callResult.[[Value]] (its conversion is the
    //     caller's).
    // 14. Return: clean up after running a callback and after running script
    //     (V8's checkpoint, as the outermost call returns), then the IDL value,
    //     or the abrupt completion as `behavior` has it.
    return callCompletion(callback_realm, function, receiver.value, js_args.slice(), behavior);
}

/// WebIDL "call a user object's operation" (3.11), `realm` as for
/// invokeCallbackFunction.
pub fn callUserObjectOperation(realm: Context, callback: JSValue, operation: []const u8, this_arg: engine.CallbackThis, args: []const JSValue, behavior: engine.ExceptionBehavior) Error!Completion {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 1. Let completion be an uninitialized variable.
    // 2. If thisArg was not given, let thisArg be undefined.
    // 3. Let O be the JavaScript object corresponding to value.
    const object = support.handleOf(callback) orelse return error.TypeError;
    if (!ffi.v8_Value_IsObject(object)) return error.TypeError;

    // 4. Let realm be O's associated realm.
    // 5-7. Prepare to run script with realm's settings object.
    const callback_realm = try CallbackRealm.enter(object, entered);
    defer callback_realm.leave();
    // 8. Prepare to run a callback with stored settings: not yet (above).

    var receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();

    // 9. Let X be O.
    var function = object;
    var got: ?*ffi.Value = null;
    defer if (got) |g| ffi.v8_Global_Dispose(g);
    // 10. If IsCallable(O) is false, then:
    if (!ffi.v8_Value_IsFunction(object)) {
        // 1. Let getResult be Completion(Get(O, opName)).
        var threw = false;
        const get_result = ffi.v8_Object_GetCatching(callback_realm.context, object, operation.ptr, @intCast(operation.len), &threw);
        // 2. If getResult is an abrupt completion, set completion to
        //    getResult and jump to the step labeled return.
        if (threw) return abrupt(get_result orelse return error.OperationFailed, callback_realm.context, callback_realm.realm, behavior);
        // 3. Set X to getResult.[[Value]].
        got = get_result orelse return error.OperationFailed;
        function = got.?;
        // 4. If IsCallable(X) is false, then set completion to a throw
        //    completion of a new TypeError, and jump to return.
        if (!ffi.v8_Value_IsFunction(function)) {
            const message = "The callback's operation is not callable";
            const type_error = try support.newTypeError(entered.isolate, callback_realm.context, message);
            return abrupt(type_error, callback_realm.context, callback_realm.realm, behavior);
        }
        // 5. Set thisArg to O (overriding the provided value).
        receiver.release();
        receiver = .{ .value = object };
    }

    // 11. Let jsArgs be the result of converting args to a JavaScript
    //     arguments list.
    var js_args: Arguments = .{};
    defer js_args.release();
    try js_args.convert(entered.isolate, callback_realm.context, args);

    // 12. Let callResult be Completion(Call(X, thisArg, jsArgs)).
    // 13. If callResult is an abrupt completion, set completion to callResult.
    // 14. Set completion to callResult.[[Value]] (its conversion is the
    //     caller's).
    // 15. Return: clean up after running a callback and after running script,
    //     then the IDL value, or the abrupt completion as `behavior` has it.
    return callCompletion(callback_realm, function, receiver.value, js_args.slice(), behavior);
}
