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
//! "Prepare to run a callback" pushes the callback's context - the
//! incumbent realm recorded when the value was converted - onto the backup
//! incumbent settings object stack: V8's Context::BackupIncumbentScope, held
//! on the C++ stack around the body of the invocation (Blink's
//! CallbackInvokeHelper does the same), so Isolate::GetIncumbentContext
//! answers it for a callback with no script frame of its own (a built-in
//! function); a script function is its own incumbent, as HTML says.
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
const context_manager = @import("context_manager.zig");
const callback_interfaces = @import("callback_interfaces.zig");
const V8CallbackWrapper = @import("callback_wrapper.zig").CallbackWrapper;
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
/// each argument converted in the callback's realm - a platform object to its
/// wrapper in its own relevant realm. `values` owns what was made for the
/// call.
const Arguments = struct {
    values: [max_arguments]realm_entry.EngineValue = undefined,
    pointers: [max_arguments]*ffi.Value = undefined,
    count: usize = 0,

    fn convert(self: *Arguments, isolate: *ffi.Isolate, context: *ffi.Context, args: []const JSValue) Error!void {
        if (args.len > max_arguments) return error.OperationFailed;
        // 4. While i < args's size: append the converted value.
        for (args) |arg| {
            self.values[self.count] = switch (arg) {
                .instance => |instance| .{ .ptr = try support.relevantWrapper(isolate, instance), .made = true },
                else => realm_entry.EngineValue.of(isolate, context, arg) catch |err| return support.protocolError(err),
            };
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
fn abrupt(thrown: Thrown, context: *ffi.Context, realm: ?Context, behavior: engine.ExceptionBehavior) Completion {
    switch (behavior) {
        // 5. If exceptionBehavior is "rethrow", throw completion.[[Value]] -
        //    handed back, for the caller to throw on or handle.
        .rethrow => {
            ffi.v8_FreeErrorInfo(thrown.site);
            return .{ .throw = support.owned(thrown.value) };
        },
        // 6. Otherwise, if exceptionBehavior is "report":
        .report => |reporter| {
            defer ffi.v8_Global_Dispose(thrown.value);
            // 2. Report an exception completion.[[Value]] for realm's global
            //    object, with the error information of where it was thrown -
            //    or, for an exception the call did not catch at its throw
            //    site (a TypeError made here), what the value itself carries.
            const details = thrown.site orelse ffi.v8_Exception_GetErrorInfo(context, thrown.value);
            defer ffi.v8_FreeErrorInfo(details);
            var info: engine.ErrorInfo = .{
                .message = "Uncaught exception",
                .filename = "",
                .lineno = 0,
                .colno = 0,
                .error_value = support.borrowed(thrown.value),
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

/// What the body of an invocation ends with, before "clean up": the call's
/// value, or what was thrown. OWNED.
const Raw = union(enum) {
    normal: *ffi.Value,
    thrown: Thrown,
};

/// A thrown value, and the error information of where it was thrown when the
/// catch had it (null for an exception made here). Both OWNED.
const Thrown = struct {
    value: *ffi.Value,
    site: ?*ffi.V8ErrorInfo = null,
};

/// The step labeled "return", after clean up: the completion as the caller's
/// exception behavior has it.
fn finish(raw: Raw, context: *ffi.Context, realm: ?Context, behavior: engine.ExceptionBehavior) Completion {
    return switch (raw) {
        .normal => |value| .{ .normal = support.owned(value) },
        .thrown => |thrown| abrupt(thrown, context, realm, behavior),
    };
}

/// Call(`function`, `receiver`, `args`) in `context`, its completion caught
/// - with where it was thrown, for "report an exception".
fn callRaw(context: *ffi.Context, function: *ffi.Value, receiver: ?*ffi.Value, args: []const *ffi.Value) Error!Raw {
    var threw = false;
    var site: ?*ffi.V8ErrorInfo = null;
    const result = ffi.v8_Function_CallCatchingWithSite(context, function, receiver, @intCast(args.len), if (args.len == 0) null else args.ptr, &threw, &site);
    // A terminating isolate has no value to hand back.
    const value = result orelse {
        ffi.v8_FreeErrorInfo(site);
        return error.OperationFailed;
    };
    return if (threw) .{ .thrown = .{ .value = value, .site = site } } else .{ .normal = value };
}

/// HTML "prepare to run a callback" with `callback_context`, then `body.run()`,
/// then "clean up after running a callback": the context is on the backup
/// incumbent settings object stack for the body's extent. A context the
/// engine no longer hosts (a retired realm) pushes nothing.
fn withCallbackContext(isolate: *ffi.Isolate, callback_context: ?Context, body: anytype) void {
    const Body = @TypeOf(body.*);
    const Trampoline = struct {
        fn call(data: ?*anyopaque) callconv(.c) void {
            const self: *Body = @ptrCast(@alignCast(data.?));
            self.run();
        }
    };
    const incumbent: ?*ffi.Context = if (callback_context) |c|
        (if (c.engine_ctx) |engine_ctx| @ptrCast(@alignCast(engine_ctx)) else null)
    else
        null;
    ffi.v8_RunWithBackupIncumbent(isolate, incumbent, Trampoline.call, body);
}

/// The incumbent realm now, as the context manager hosts it.
fn incumbentRealm(isolate: *ffi.Isolate) ?Context {
    const context = ffi.v8_Isolate_GetIncumbentContext(isolate) orelse return null;
    defer ffi.v8_Context_Dispose(context);
    return context_manager.get(context);
}

/// WebIDL "invoke a callback function" (3.12), `realm` being where the
/// callback is read: a realm of its agent.
pub fn invokeCallbackFunction(realm: Context, callback: *const engine.CallbackFunction, this_arg: engine.CallbackThis, args: []const JSValue, behavior: engine.ExceptionBehavior) Error!Completion {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 1. Let completion be an uninitialized variable.
    // 2. If thisArg was not given, let thisArg be undefined (CallbackThis's
    //    `undefined`).
    // 3. Let F be the JavaScript object corresponding to callable.
    // 4. If IsCallable(F) is false - only possible for a
    //    [LegacyTreatNonObjectAsNull] attribute's value - return undefined
    //    converted to the return type (the caller's conversion).
    const function = support.handleOf(callback.function.value) orelse return normal_undefined;
    // A callback of a realm the collector took (weak since the realm's
    // detach, protocol_realms) is empty: nothing to call.
    if (ffi.v8_Global_IsEmpty(function)) return normal_undefined;
    if (!ffi.v8_Value_IsFunction(function)) return normal_undefined;

    // 5. Let realm be F's associated realm.
    // 6. Let relevant settings be realm's settings object.
    // 7. Let stored settings be callable's callback context.
    // 8. Prepare to run script with relevant settings.
    const callback_realm = try CallbackRealm.enter(function, entered);
    var in_callback_realm = true;
    defer if (in_callback_realm) callback_realm.leave();

    // The callback this value, from where it was read.
    const receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();
    var js_args: Arguments = .{};
    defer js_args.release();

    var body: struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        function: *ffi.Value,
        receiver: ?*ffi.Value,
        args: []const JSValue,
        js_args: *Arguments,
        result: Error!Raw = error.OperationFailed,
        pub fn run(self: *@This()) void {
            // 10. Let jsArgs be the result of converting args to a JavaScript
            //     arguments list.
            self.js_args.convert(self.isolate, self.context, self.args) catch |err| {
                self.result = err;
                return;
            };
            // 11. Let callResult be Completion(Call(F, thisArg, jsArgs)).
            // 12. If callResult is an abrupt completion, set completion to
            //     callResult.
            // 13. Set completion to callResult.[[Value]] (its conversion to
            //     the return type is the caller's).
            self.result = callRaw(self.context, self.function, self.receiver, self.js_args.slice());
        }
    } = .{ .isolate = entered.isolate, .context = callback_realm.context, .function = function, .receiver = receiver.value, .args = args, .js_args = &js_args };
    // 9. Prepare to run a callback with stored settings; 14.1. clean up after
    //    running a callback with stored settings.
    withCallbackContext(entered.isolate, callback.context, &body);
    // 14.2. Clean up after running script with relevant settings (and V8's
    //       checkpoint, as the outermost call returned).
    callback_realm.leave();
    in_callback_realm = false;
    // 14.3-14.6. The IDL value, or the abrupt completion as `behavior` has it.
    return finish(try body.result, entered.context(), callback_realm.realm, behavior);
}

/// WebIDL "construct a callback function" (3.12), `realm` as for
/// invokeCallbackFunction: the constructed object, or what was thrown -
/// always handed back (the algorithm's step 13.3 throws it; the caller does).
pub fn constructCallbackFunction(realm: Context, callback: *const engine.CallbackFunction, args: []const JSValue) Error!Completion {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 1. Let completion be an uninitialized variable.
    // 2. Let F be the JavaScript object corresponding to callable.
    // 3. If IsConstructor(F) is false, throw a TypeError exception. (A
    //    callback of a realm the collector took is empty: nothing to
    //    construct either.)
    const function = support.handleOf(callback.function.value) orelse return notAConstructor(entered);
    if (ffi.v8_Global_IsEmpty(function) or !ffi.v8_Value_IsConstructor(function)) return notAConstructor(entered);

    // 4. Let realm be F's associated realm.
    // 5. Let relevant settings be realm's settings object.
    // 6. Let stored settings be callable's callback context.
    // 7. Prepare to run script with relevant settings.
    const callback_realm = try CallbackRealm.enter(function, entered);
    var in_callback_realm = true;
    defer if (in_callback_realm) callback_realm.leave();

    var js_args: Arguments = .{};
    defer js_args.release();

    var body: struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        function: *ffi.Value,
        args: []const JSValue,
        js_args: *Arguments,
        result: Error!Raw = error.OperationFailed,
        pub fn run(self: *@This()) void {
            // 9. Let jsArgs be the result of converting args to a JavaScript
            //    arguments list.
            self.js_args.convert(self.isolate, self.context, self.args) catch |err| {
                self.result = err;
                return;
            };
            // 10. Let callResult be Completion(Construct(F, jsArgs)).
            // 11. If callResult is an abrupt completion, set completion to
            //     callResult.
            // 12. Set completion to callResult.[[Value]] (its conversion to
            //     the return type is the caller's).
            self.result = constructRaw(self.context, self.function, self.js_args.slice());
        }
    } = .{ .isolate = entered.isolate, .context = callback_realm.context, .function = function, .args = args, .js_args = &js_args };
    // 8. Prepare to run a callback with stored settings; 13.1. clean up after
    //    running a callback with stored settings.
    withCallbackContext(entered.isolate, callback.context, &body);
    // 13.2. Clean up after running script with relevant settings.
    callback_realm.leave();
    in_callback_realm = false;
    // 13.3. If completion is an abrupt completion, throw completion.[[Value]]
    //       - handed back, for the caller to throw. 13.4. Return completion.
    return finish(try body.result, entered.context(), callback_realm.realm, .rethrow);
}

/// Step 3's TypeError, made in the entered realm before any script runs.
fn notAConstructor(entered: support.Entered) Error!Completion {
    const exception = try support.newTypeError(entered.isolate, entered.context(), "The callback is not a constructor");
    return .{ .throw = support.owned(exception) };
}

/// Construct(`function`, `args`) in `context`, its completion caught - with
/// where it was thrown, as `callRaw` has it.
fn constructRaw(context: *ffi.Context, function: *ffi.Value, args: []const *ffi.Value) Error!Raw {
    var threw = false;
    var site: ?*ffi.V8ErrorInfo = null;
    const result = ffi.v8_Function_ConstructCatchingWithSite(context, function, @intCast(args.len), if (args.len == 0) null else args.ptr, &threw, &site);
    // A terminating isolate has no value to hand back.
    const value = result orelse {
        ffi.v8_FreeErrorInfo(site);
        return error.OperationFailed;
    };
    return if (threw) .{ .thrown = .{ .value = value, .site = site } } else .{ .normal = value };
}

/// WebIDL "call a user object's operation" (3.11), `realm` as for
/// invokeCallbackFunction.
pub fn callUserObjectOperation(realm: Context, callback: *const engine.CallbackInterface, operation: []const u8, this_arg: engine.CallbackThis, args: []const JSValue, behavior: engine.ExceptionBehavior) Error!Completion {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 1. Let completion be an uninitialized variable.
    // 2. If thisArg was not given, let thisArg be undefined.
    // 3. Let O be the JavaScript object corresponding to value.
    const object = support.handleOf(callback.object.value) orelse return error.TypeError;
    // Empty: a callback of a realm the collector took (protocol_realms).
    if (ffi.v8_Global_IsEmpty(object)) return error.TypeError;
    if (!ffi.v8_Value_IsObject(object)) return error.TypeError;

    // 4. Let realm be O's associated realm.
    // 5. Let relevant settings be realm's settings object.
    // 6. Let stored settings be value's callback context.
    // 7. Prepare to run script with relevant settings.
    const callback_realm = try CallbackRealm.enter(object, entered);
    var in_callback_realm = true;
    defer if (in_callback_realm) callback_realm.leave();

    const receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();
    var js_args: Arguments = .{};
    defer js_args.release();

    var body: struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        object: *ffi.Value,
        operation: []const u8,
        receiver: ?*ffi.Value,
        args: []const JSValue,
        js_args: *Arguments,
        got: ?*ffi.Value = null,
        result: Error!Raw = error.OperationFailed,
        pub fn run(self: *@This()) void {
            self.result = self.steps();
        }
        fn steps(self: *@This()) Error!Raw {
            // 9. Let X be O.
            var function = self.object;
            var this_value = self.receiver;
            // 10. If IsCallable(O) is false, then:
            if (!ffi.v8_Value_IsFunction(self.object)) {
                // 1. Let getResult be Completion(Get(O, opName)).
                var threw = false;
                var site: ?*ffi.V8ErrorInfo = null;
                const get_result = ffi.v8_Object_GetCatchingWithSite(self.context, self.object, self.operation.ptr, @intCast(self.operation.len), &threw, &site);
                // 2. If getResult is an abrupt completion, set completion to
                //    getResult and jump to the step labeled return.
                if (threw) {
                    const value = get_result orelse {
                        ffi.v8_FreeErrorInfo(site);
                        return error.OperationFailed;
                    };
                    return .{ .thrown = .{ .value = value, .site = site } };
                }
                // 3. Set X to getResult.[[Value]].
                self.got = get_result orelse return error.OperationFailed;
                function = self.got.?;
                // 4. If IsCallable(X) is false, then set completion to a throw
                //    completion of a new TypeError, and jump to return.
                if (!ffi.v8_Value_IsFunction(function)) {
                    return .{ .thrown = .{ .value = try support.newTypeError(self.isolate, self.context, "The callback's operation is not callable") } };
                }
                // 5. Set thisArg to O (overriding the provided value).
                this_value = self.object;
            }
            // 11. Let jsArgs be the result of converting args to a JavaScript
            //     arguments list.
            try self.js_args.convert(self.isolate, self.context, self.args);
            // 12. Let callResult be Completion(Call(X, thisArg, jsArgs)).
            // 13. If callResult is an abrupt completion, set completion to
            //     callResult.
            // 14. Set completion to callResult.[[Value]] (its conversion is
            //     the caller's).
            return callRaw(self.context, function, this_value, self.js_args.slice());
        }
    } = .{ .isolate = entered.isolate, .context = callback_realm.context, .object = object, .operation = operation, .receiver = receiver.value, .args = args, .js_args = &js_args };
    defer if (body.got) |got| ffi.v8_Global_Dispose(got);
    // 8. Prepare to run a callback with stored settings; 15.1. clean up after
    //    running a callback with stored settings.
    withCallbackContext(entered.isolate, callback.context, &body);
    // 15.2. Clean up after running script with relevant settings.
    callback_realm.leave();
    in_callback_realm = false;
    // 15.3-15.4. The IDL value, or the abrupt completion as `behavior` has it.
    return finish(try body.result, entered.context(), callback_realm.realm, behavior);
}

/// A callback-function argument as the binding hands it over (the
/// Global<Function> the conversion made, tagged), with its callback context:
/// the incumbent realm now - the operation is converting its arguments.
pub fn takeCallbackFunction(argument: *const anyopaque) engine.CallbackFunction {
    const function = callback_interfaces.takeCallbackFunction(argument);
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return .{ .function = .{ .value = function }, .context = null };
    tagWithCurrentRealm(isolate, function);
    return .{ .function = .{ .value = function }, .context = incumbentRealm(isolate) };
}

/// Tag a callback's handle with the realm whose API is storing it - the
/// current realm: V8 runs an API function in its own context, so a frame
/// target's `onmessage` setter or `addEventListener` is the frame's,
/// whichever realm called it. If that realm's navigable is destroyed, its
/// detach makes the handle weak (protocol_realms) - a listener whose closure
/// reaches the frame must not be a root that keeps the frame forever.
fn tagWithCurrentRealm(isolate: *ffi.Isolate, value: JSValue) void {
    const handle = support.handleOf(value) orelse return;
    const current = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer ffi.v8_Context_Dispose(current);
    const key = context_manager.keyOf(current) orelse return;
    ffi.v8_Global_TagRealm(handle, key);
}

/// A callback-interface argument as the binding hands it over (the
/// runtime.CallbackWrapper it converted - this adapter's CallbackWrapper):
/// its object as a Global of the caller's own, with its callback context as
/// for takeCallbackFunction. The wrapper is the call's; the binding releases
/// it.
pub fn takeCallbackInterface(argument: *const engine.CallbackWrapper) engine.CallbackInterface {
    const wrapper: *const V8CallbackWrapper = @ptrCast(@alignCast(argument));
    const held = wrapper.callback_object_global orelse wrapper.callback_function_global;
    const object: JSValue = if (held) |global|
        (if (ffi.v8_Global_Clone(global.ptr)) |clone| realm_entry.owned(clone) else JSValue.jsUndefined)
    else
        JSValue.jsUndefined;
    tagWithCurrentRealm(wrapper.isolate, object);
    return .{ .object = .{ .value = object }, .context = incumbentRealm(wrapper.isolate) };
}
