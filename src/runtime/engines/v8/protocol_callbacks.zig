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
//! The caller supplies the declared return type when it is not `any`.
//! Its conversion runs before either callback scope ends (step 13), as in
//! Blink's CallbackInvokeHelper. Promise return types are not supported here.

const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");

const ffi = @import("ffi.zig");
const js_scope = @import("js_scope.zig");
const realm_entry = @import("realm_entry.zig");
const context_manager = @import("context_manager.zig");
const support = @import("protocol_support.zig");
const protocol_realms = @import("protocol_realms.zig");
const protocol_worlds = @import("protocol_worlds.zig");
const conv = @import("conversions.zig");
const interface = @import("interface.zig");

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

    /// Whether the callback may run: not when its associated realm's global
    /// is a Window whose associated Document is not fully active - a frame
    /// realm `destroyWindowRealm` detached, because a navigation replaced its
    /// document or its navigable was destroyed (protocol_realms.isDetached:
    /// its tasks no longer run either, HTML "destroy a document" step 7).
    ///
    /// DOM inner invoke step 8 skips such a listener; the browsers refuse
    /// every such callback, which is what this is: Blink
    /// (IsCallbackFunctionRunnable - the callback's relevant ExecutionContext
    /// is destroyed - and JSBasedEventListener::Invoke's ContextIsValid) and
    /// Gecko (CallbackObject::CallSetup: "Refusing to execute function from
    /// window whose document is no longer active"). wpt.fyi stable:
    /// html/semantics/scripting-1/the-script-element/execution-timing/083.html
    /// passes in Chrome 155, Firefox 157 and Safari 27. A worker's realm, or
    /// a realm the context manager does not host, is always runnable here.
    ///
    /// Nor when the Window's associated Document has been destroyed but its
    /// realm is not detached yet: "destroy a child navigable" destroys the
    /// frame's document at once (step 5) and ends its realm at a task of
    /// its own (dom.navigables.queueRemovedFrameRealmEnd), and in between a
    /// callback of the frame - a NodeFilter its script made for a parent
    /// document's iterator - must not run. Blink's IsCallbackFunctionRunnable
    /// refuses it the same way: the frame's ExecutionContext is destroyed
    /// (IsContextDestroyed) as the frame detaches. HTML "prepare to run
    /// script" with a Window whose Document is not fully active; WebIDL "call
    /// a user object's operation" step 7. dom/traversal/TreeWalker-acceptNode-
    /// filter-cross-realm-null-browsing-context.html: Chrome 155 and Firefox
    /// 158 pass, Safari 27 fails. Only a document that can never be fully
    /// active again (dom.document_activity `.gone`) is refused: a page the
    /// back/forward cache keeps (`.inactive`) is the cached-realm lesson's,
    /// for its phase C.
    fn runnable(self: CallbackRealm) bool {
        const realm = self.realm orelse return true;
        if (protocol_realms.isDetached(realm)) return false;
        // Only a frame's realm stays attached after its document is
        // destroyed (its end is a task of its own); a top-level page's realm
        // ends or detaches with its document. (The activity check walks the
        // Browser's navigables: keep it off every top-level callback.)
        if (!protocol_realms.isAttachedFrame(realm)) return true;
        // A realm no Browser made (WindowRealmOptions.browser_scope unset:
        // the engine's own tests) has no document state to consult - its
        // Window belongs to no navigable. (Not browserScope(), which falls
        // back to the process's standalone scope.)
        if (realm.browser_scope == null) return true;
        const record = realm.getRealm() orelse return true;
        const global: *engine.Instance = @ptrCast(@alignCast(record.global_object orelse return true));
        if (global.stateAs(@import("interfaces").Window.State) == null) return true;
        return @import("dom").document_activity.activity(global, runtime.SlabAllocator.generationOf(global)) != .gone;
    }

    /// Whether the callback's arguments are checked across worlds
    /// (`Arguments.across_worlds`): its realm's Browser made an isolated
    /// world. Two loads, no lookup - the fast path for every other Browser.
    fn acrossWorlds(self: CallbackRealm) bool {
        const realm = self.realm orelse return false;
        return protocol_worlds.realmMayHaveWorlds(realm);
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
    /// The callback's realm is of a Browser that made an isolated world
    /// (`CallbackRealm.acrossWorlds`): an object argument of another world is converted
    /// into the callback's (protocol_worlds.acrossWorlds) - an event's
    /// detail a world's script stored, handed to a page listener. Off - the
    /// fast path, every Browser with no world - nothing is compared.
    across_worlds: bool = false,

    fn convert(self: *Arguments, isolate: *ffi.Isolate, context: *ffi.Context, args: []const JSValue) Error!void {
        if (args.len > max_arguments) return error.OperationFailed;
        // 4. While i < args's size: append the converted value.
        for (args) |arg| {
            self.values[self.count] = switch (arg) {
                .instance => |instance| .{ .ptr = try support.relevantWrapper(isolate, instance), .made = true },
                else => converted: {
                    const value = realm_entry.EngineValue.of(isolate, context, arg) catch |err| return support.protocolError(err);
                    // A held value of another world than the callback's:
                    // its value in the callback's world, never the other
                    // world's object. One branch when no world exists.
                    if (self.across_worlds and arg == .handle) {
                        if (protocol_worlds.acrossWorlds(isolate, value.ptr, context)) |across| {
                            value.release();
                            break :converted .{ .ptr = across, .made = true };
                        }
                    }
                    break :converted value;
                },
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

    /// WebIDL "convert a Web IDL arguments list to a JavaScript arguments list"
    /// for typed IDL arguments: a tuple of typed values (with `webidl.Opt(T)`
    /// trailing-missing truncation and middle-missing -> `undefined`, plus an
    /// optional trailing `[]const JSValue` variadic tail) or a `[]const JSValue`
    /// slice directly.
    fn convertTuple(self: *Arguments, isolate: *ffi.Isolate, context: *ffi.Context, args: anytype) Error!void {
        const Args = @TypeOf(args);
        if (comptime Args == []const JSValue) return self.convert(isolate, context, args);
        const info = @typeInfo(Args);
        if (comptime info != .@"struct") {
            @compileError("callback args must be a tuple of WebIDL values or []const JSValue, got " ++ @typeName(Args));
        }
        const field_names = info.@"struct".field_names;
        const field_types = info.@"struct".field_types;
        if (comptime field_names.len == 0) return;

        // WebIDL 3.11 / 3.12: compute the last present argument so trailing
        // "missing" (`webidl.Opt.notPassed()`) items are truncated while middle
        // missing items become `undefined`.
        var present: [field_names.len]bool = undefined;
        inline for (field_names, field_types, 0..) |field_name, FieldType, i| {
            const val = @field(args, field_name);
            if (comptime isWebIdlOpt(FieldType)) {
                present[i] = val.wasPassed();
            } else if (comptime FieldType == []const JSValue and i == field_names.len - 1) {
                present[i] = val.len > 0;
            } else {
                present[i] = true;
            }
        }
        var last_present: usize = 0;
        for (present, 0..) |p, i| {
            if (p) last_present = i + 1;
        }

        inline for (field_names, field_types, 0..) |field_name, FieldType, i| {
            if (i < last_present) {
                const val = @field(args, field_name);
                if (comptime isWebIdlOpt(FieldType)) {
                    if (!val.wasPassed()) {
                        if (self.count >= max_arguments) return error.OperationFailed;
                        const undef = ffi.v8_Undefined(isolate) orelse return error.OperationFailed;
                        self.values[self.count] = .{ .ptr = undef, .made = true };
                        self.pointers[self.count] = undef;
                        self.count += 1;
                    } else {
                        try self.appendTyped(isolate, context, val.getValue());
                    }
                } else if (comptime FieldType == []const JSValue and i == field_names.len - 1) {
                    try self.convert(isolate, context, val);
                } else {
                    try self.appendTyped(isolate, context, val);
                }
            }
        }
    }

    fn appendTyped(self: *Arguments, isolate: *ffi.Isolate, context: *ffi.Context, val: anytype) Error!void {
        const T = @TypeOf(val);
        if (comptime T == JSValue) return self.convert(isolate, context, &.{val});
        if (self.count >= max_arguments) return error.OperationFailed;
        if (comptime T == *runtime.Instance) {
            const wrapper = try support.relevantWrapper(isolate, val);
            self.values[self.count] = .{ .ptr = wrapper, .made = true };
            self.pointers[self.count] = wrapper;
            self.count += 1;
            return;
        }
        if (comptime T == ?*runtime.Instance) {
            const ptr = if (val) |inst|
                try support.relevantWrapper(isolate, inst)
            else
                ffi.v8_Null(isolate) orelse return error.OperationFailed;
            self.values[self.count] = .{ .ptr = ptr, .made = true };
            self.pointers[self.count] = ptr;
            self.count += 1;
            return;
        }

        // Normalize string literals (`*const [N:0]u8` / `*const [N]u8`) and
        // comptime numeric literals for ergonomic typed calls.
        const NormT = comptime normalizedArgType(T);
        const norm_val: NormT = val;
        const converted = conv.toV8Value(NormT, isolate, context, norm_val) catch |err| return conversionErrorToProtocol(err);
        const owned_v8 = conv.memberValueIsOwned(NormT, norm_val);
        if (self.across_worlds) {
            if (conv.memberAcrossWorlds(NormT, norm_val, isolate, context, converted)) |across| {
                if (owned_v8) ffi.v8_Global_Dispose(converted);
                self.values[self.count] = .{ .ptr = across, .made = true };
                self.pointers[self.count] = across;
                self.count += 1;
                return;
            }
        }
        self.values[self.count] = .{ .ptr = converted, .made = owned_v8 };
        self.pointers[self.count] = converted;
        self.count += 1;
    }
};

fn isWebIdlOpt(comptime T: type) bool {
    return @typeInfo(T) == .@"struct" and @hasField(T, "was_passed") and @hasField(T, "value");
}

fn normalizedArgType(comptime T: type) type {
    if (T == comptime_int or T == comptime_float) return f64;
    const info = @typeInfo(T);
    if (info == .pointer and info.pointer.size == .one) {
        const child_info = @typeInfo(info.pointer.child);
        if (child_info == .array and child_info.array.child == u8) return []const u8;
    }
    return T;
}

fn conversionErrorToProtocol(err: conv.ConversionError) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.TypeError, error.RangeError, error.StringError => error.TypeError,
        error.ExceptionPending => error.ExceptionPending,
        error.NullContext, error.GlobalHandleCreationFailed => error.OperationFailed,
    };
}

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
    return invokeCallbackFunctionWithReturnType(realm, callback, this_arg, args, behavior, .any);
}

pub fn invokeCallbackFunctionWithReturnType(realm: Context, callback: *const engine.CallbackFunction, this_arg: engine.CallbackThis, args: []const JSValue, behavior: engine.ExceptionBehavior, comptime return_type: engine.CallbackReturnType) Error!Completion {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 1. Let completion be an uninitialized variable.
    // 2. If thisArg was not given, let thisArg be undefined (CallbackThis's
    //    `undefined`).
    // 3. Let F be the JavaScript object corresponding to callable.
    // 4. If IsCallable(F) is false - only possible for a
    //    [LegacyTreatNonObjectAsNull] attribute's value - return undefined
    //    converted to the return type (undefined becomes null for DOMString?).
    const no_call: Completion = if (return_type == .any) normal_undefined else .{ .normal = .{ .value = JSValue.jsNull } };
    const function = support.handleOf(callback.function.value) orelse return no_call;
    // A callback of a realm the collector took (weak since the realm's
    // detach, protocol_realms) is empty: nothing to call.
    if (ffi.v8_Global_IsEmpty(function)) return no_call;
    if (!ffi.v8_Value_IsFunction(function)) return no_call;

    // 5. Let realm be F's associated realm.
    // 6. Let relevant settings be realm's settings object.
    // 7. Let stored settings be callable's callback context.
    // 8. Prepare to run script with relevant settings.
    const callback_realm = try CallbackRealm.enter(function, entered);
    var in_callback_realm = true;
    defer if (in_callback_realm) callback_realm.leave();
    // A Window realm whose Document is not fully active runs nothing:
    // nothing is called, thrown or reported (`CallbackRealm.runnable`).
    if (!callback_realm.runnable()) return error.OperationFailed;

    // The callback this value, from where it was read.
    const receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();
    var js_args: Arguments = .{ .across_worlds = callback_realm.acrossWorlds() };
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
            const raw = callRaw(self.context, self.function, self.receiver, self.js_args.slice()) catch |err| {
                self.result = err;
                return;
            };
            // 13. Convert to the callback's IDL return type while relevant
            // settings and stored settings are both still prepared.
            self.result = convertReturn(self.isolate, self.context, raw, return_type);
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

/// Takes the call's owned completion. Every conversion path releases the old
/// normal value once; an abrupt call is handed on unchanged.
fn convertReturn(isolate: *ffi.Isolate, context: *ffi.Context, raw: Raw, comptime return_type: engine.CallbackReturnType) Error!Raw {
    if (return_type == .any) return raw;
    const value = switch (raw) {
        .thrown => return raw,
        .normal => |v| v,
    };
    defer ffi.v8_Global_Dispose(value);
    // WebIDL nullable conversion step 1: null and undefined become null.
    if (ffi.v8_Value_IsNull(value) or ffi.v8_Value_IsUndefined(value)) {
        return .{ .normal = ffi.v8_Null(isolate) orelse return error.OperationFailed };
    }
    var threw = false;
    var site: ?*ffi.V8ErrorInfo = null;
    const converted = ffi.v8_Value_ToStringCatchingWithSite(context, value, &threw, &site) orelse {
        ffi.v8_FreeErrorInfo(site);
        return error.OperationFailed;
    };
    return if (threw) .{ .thrown = .{ .value = converted, .site = site } } else .{ .normal = converted };
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
    // As for invokeCallbackFunction (`CallbackRealm.runnable`).
    if (!callback_realm.runnable()) return error.OperationFailed;

    var js_args: Arguments = .{ .across_worlds = callback_realm.acrossWorlds() };
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
    // As for invokeCallbackFunction (`CallbackRealm.runnable`): a listener
    // of a frame a navigation replaced does not run (DOM inner invoke step 8).
    if (!callback_realm.runnable()) return error.OperationFailed;

    const receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();
    var js_args: Arguments = .{ .across_worlds = callback_realm.acrossWorlds() };
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

/// Outcome of a typed callback invocation before clean-up and exception
/// behavior handling: either a converted `Held(R)` or a caught `Thrown`.
fn Converted(comptime R: type) type {
    return union(enum) {
        normal: engine.Held(R),
        thrown: Thrown,
    };
}

/// Synthesize a RangeError in `context` (the callback's associated realm).
fn newRangeError(isolate: *ffi.Isolate, context: *ffi.Context, message: []const u8) Error!*ffi.Value {
    const text = try support.newString(isolate, message);
    defer ffi.v8_String_Dispose(text);
    return ffi.v8_Exception_RangeErrorInContext(context, text) orelse error.OperationFailed;
}

/// Report a thrown exception via `reporter` and dispose it and its throw site.
fn reportThrown(thrown: Thrown, context: *ffi.Context, realm: ?Context, reporter: engine.Reporter) void {
    defer ffi.v8_Global_Dispose(thrown.value);
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
}

/// Value returned after reporting an exception under `.report` (WebIDL 3.12
/// step 14.6 "Return the unique undefined IDL value").
fn reportedFallback(comptime R: type) Error!engine.Held(R) {
    const empty_js: engine.Owned = .{ .value = JSValue.jsUndefined };
    if (comptime R == void) return .{ .value = {}, .js = empty_js };
    if (comptime R == JSValue) return .{ .value = JSValue.jsUndefined, .js = empty_js };
    if (comptime R == runtime.DOMString) return .{ .value = runtime.DOMString.empty, .js = empty_js };
    if (comptime R == []const u8) return .{ .value = &[_]u8{}, .js = empty_js };
    return switch (@typeInfo(R)) {
        .optional => .{ .value = null, .js = empty_js },
        .bool => .{ .value = false, .js = empty_js },
        .int => .{ .value = 0, .js = empty_js },
        .float => .{ .value = std.math.nan(R), .js = empty_js },
        else => error.OperationFailed,
    };
}

/// Finalize a `Converted(R)` after clean-up according to `behavior`.
fn finishTyped(
    comptime R: type,
    converted: Converted(R),
    context: *ffi.Context,
    realm: ?Context,
    behavior: engine.ExceptionBehavior,
) Error!engine.Returned(R) {
    return switch (converted) {
        .normal => |held| .{ .normal = held },
        .thrown => |thrown| switch (behavior) {
            .rethrow => {
                ffi.v8_FreeErrorInfo(thrown.site);
                return .{ .throw = support.owned(thrown.value) };
            },
            .report => |reporter| {
                reportThrown(thrown, context, realm, reporter);
                return .{ .normal = try reportedFallback(R) };
            },
        },
    };
}

/// Convert an OWNED `raw_value` to IDL type `R` inside `context` (F's
/// associated realm for callbacks, or the entered realm for `convertFromJS`),
/// catching any JS exception with its original throw site. Always consumes
/// `raw_value`: either moves it into `Held(R).js` or disposes it on throw,
/// error, or `void`.
fn convertRawAs(
    comptime R: type,
    comptime return_options: engine.ReturnOptions,
    allocator: std.mem.Allocator,
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    raw_value: *ffi.Value,
) Error!Converted(R) {
    // WebIDL 3.2.2 `undefined`: ignore the JS value without running script.
    if (comptime R == void) {
        ffi.v8_Global_Dispose(raw_value);
        return .{ .normal = .{ .value = {}, .js = .{ .value = JSValue.jsUndefined } } };
    }
    // WebIDL `any`: hand the JS value through directly.
    if (comptime R == JSValue) {
        const js = support.owned(raw_value);
        return .{ .normal = .{ .value = js.borrow(), .js = js } };
    }

    const copied = comptime interface.argHandleIsCopied(R);
    const input: *ffi.Value = if (comptime copied) raw_value else (ffi.v8_Global_Clone(raw_value) orelse {
        ffi.v8_Global_Dispose(raw_value);
        return error.OperationFailed;
    });

    const mode: interface.ArgMode = .{
        .interface = return_options.interface,
        .restricted = return_options.restricted_float,
        .byte_string = return_options.byte_string,
    };

    const Body = struct {
        allocator: std.mem.Allocator,
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        input: *ffi.Value,
        result: conv.ConversionError!R = error.TypeError,

        fn run(data: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            if (comptime copied) {
                var value = conv.fromV8ValueAs(R, return_options.interface, self.allocator, self.isolate, self.context, self.input) catch |err| {
                    self.result = err;
                    return;
                };
                if (comptime return_options.restricted_float) {
                    conv.requireFinite(R, value) catch |err| {
                        interface.freeConvertedArg(R, self.allocator, value);
                        self.result = err;
                        return;
                    };
                }
                if (comptime return_options.byte_string) {
                    conv.encodeByteStringOwned(R, self.allocator, &value) catch |err| {
                        interface.freeConvertedArg(R, self.allocator, value);
                        self.result = err;
                        return;
                    };
                }
                self.result = value;
            } else {
                // `convertArgChecked` consumes `self.input`: disposes it on
                // error or when `conversionLeavesHandle(R, value)` is true;
                // otherwise `value` owns `self.input` (freed by `freeArgument`).
                self.result = interface.convertArgChecked(R, mode, self.allocator, self.isolate, self.context, self.input);
            }
        }
    };

    var body: Body = .{
        .allocator = allocator,
        .isolate = isolate,
        .context = context,
        .input = input,
    };
    var caught_exc: ?*ffi.Value = null;
    var caught_site: ?*ffi.V8ErrorInfo = null;
    var terminated = false;
    const caught = ffi.v8_RunCatchingWithSite(isolate, context, Body.run, &body, &caught_exc, &caught_site, &terminated);

    if (terminated) {
        if (body.result) |val| {
            if (comptime copied) interface.freeConvertedArg(R, allocator, val) else interface.freeArgument(R, allocator, val);
        } else |_| {}
        ffi.v8_FreeErrorInfo(caught_site);
        if (caught_exc) |exc| ffi.v8_Global_Dispose(exc);
        ffi.v8_Global_Dispose(raw_value);
        return error.OperationFailed;
    }

    // Check `caught` FIRST: a V8 helper can leave an exception pending even if
    // the Zig conversion returned a fallback value instead of an error.
    if (caught) {
        if (body.result) |val| {
            if (comptime copied) interface.freeConvertedArg(R, allocator, val) else interface.freeArgument(R, allocator, val);
        } else |_| {}
        ffi.v8_Global_Dispose(raw_value);
        const exc = caught_exc orelse {
            ffi.v8_FreeErrorInfo(caught_site);
            return error.OperationFailed;
        };
        return .{ .thrown = .{ .value = exc, .site = caught_site } };
    }

    const value = body.result catch |err| {
        ffi.v8_Global_Dispose(raw_value);
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.RangeError => .{ .thrown = .{ .value = try newRangeError(isolate, context, "Value is out of range") } },
            error.TypeError, error.StringError => .{ .thrown = .{ .value = try support.newTypeError(isolate, context, "Failed to convert value") } },
            error.ExceptionPending, error.NullContext, error.GlobalHandleCreationFailed => error.OperationFailed,
        };
    };

    return .{ .normal = .{ .value = value, .js = support.owned(raw_value) } };
}

/// Create a new `%Promise%` in `context` resolved (if `fulfilled`) or rejected
/// (if `!fulfilled`) with `value` (BORROWED). WebIDL 3.2.24 / 3.12 step 14.7.
fn settledPromiseInContext(context: *ffi.Context, value: *ffi.Value, fulfilled: bool) Error!engine.Owned {
    const resolver = ffi.v8_PromiseResolver_New(context) orelse return error.OperationFailed;
    defer ffi.v8_PromiseResolver_Dispose(resolver);
    const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse return error.OperationFailed;
    errdefer ffi.v8_Promise_Dispose(promise);
    const ok = if (fulfilled)
        ffi.v8_PromiseResolver_Resolve(resolver, context, value)
    else
        ffi.v8_PromiseResolver_Reject(resolver, context, value);
    if (!ok) return error.OperationFailed;
    return support.owned(@ptrCast(promise));
}

/// WebIDL "invoke a callback function" (3.12) with typed WebIDL arguments
/// (step 10) and typed return conversion to `R` (step 13, inside the prepared
/// realm and callback context).
pub fn invokeCallbackFunctionAs(
    comptime R: type,
    comptime return_options: engine.ReturnOptions,
    realm: Context,
    callback: *const engine.CallbackFunction,
    this_arg: engine.CallbackThis,
    args: anytype,
    behavior: engine.ExceptionBehavior,
    allocator: std.mem.Allocator,
) Error!engine.Returned(R) {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 3-4. If IsCallable(F) is false, return the result of converting
    // undefined to the callback function's return type.
    const function = support.handleOf(callback.function.value);
    if (function == null or ffi.v8_Global_IsEmpty(function.?) or !ffi.v8_Value_IsFunction(function.?)) {
        const undef = ffi.v8_Undefined(entered.isolate) orelse return error.OperationFailed;
        const converted = try convertRawAs(R, return_options, allocator, entered.isolate, entered.context(), undef);
        return finishTyped(R, converted, entered.context(), realm, behavior);
    }

    // 5-8. Prepare to run script with F's associated realm's settings object.
    const callback_realm = try CallbackRealm.enter(function.?, entered);
    var in_callback_realm = true;
    defer if (in_callback_realm) callback_realm.leave();
    if (!callback_realm.runnable()) return error.OperationFailed;

    const receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();
    var js_args: Arguments = .{ .across_worlds = callback_realm.acrossWorlds() };
    defer js_args.release();

    const Args = @TypeOf(args);
    var body: struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        function: *ffi.Value,
        receiver: ?*ffi.Value,
        args: Args,
        js_args: *Arguments,
        allocator: std.mem.Allocator,
        result: Error!Converted(R) = error.OperationFailed,

        pub fn run(self: *@This()) void {
            // 10. Convert args to a JavaScript arguments list.
            self.js_args.convertTuple(self.isolate, self.context, self.args) catch |err| {
                self.result = err;
                return;
            };
            // 11-12. Call(F, thisArg, jsArgs).
            const raw = callRaw(self.context, self.function, self.receiver, self.js_args.slice()) catch |err| {
                self.result = err;
                return;
            };
            // 13. Convert normal return to R inside prepared scopes.
            self.result = switch (raw) {
                .thrown => |t| .{ .thrown = t },
                .normal => |v| convertRawAs(R, return_options, self.allocator, self.isolate, self.context, v),
            };
        }
    } = .{
        .isolate = entered.isolate,
        .context = callback_realm.context,
        .function = function.?,
        .receiver = receiver.value,
        .args = args,
        .js_args = &js_args,
        .allocator = allocator,
    };

    // 9 & 14.1. Prepare to run a callback / clean up after running a callback.
    withCallbackContext(entered.isolate, callback.context, &body);
    // 14.2. Clean up after running script.
    callback_realm.leave();
    in_callback_realm = false;
    // 14.3-14.6. Return value or handle abrupt completion under `behavior`.
    return finishTyped(R, try body.result, entered.context(), callback_realm.realm, behavior);
}

/// WebIDL "invoke a callback function" (3.12) for a callback returning a
/// Promise type: step 13 converts a normal return via ECMAScript
/// `PromiseResolve(%Promise%, V)` in F's associated realm (golden rule 2
/// 2-of-3 Chrome+Firefox majority; see `engine_protocol.zig`); step 14.7-14.9
/// wraps an abrupt completion (from the call or from `Get(V, "constructor")`)
/// in a rejected `%Promise%` in F's associated realm.
pub fn invokeCallbackFunctionToPromise(
    realm: Context,
    callback: *const engine.CallbackFunction,
    this_arg: engine.CallbackThis,
    args: anytype,
) Error!engine.Owned {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 3-4. If IsCallable(F) is false, return a promise resolved with undefined.
    const function = support.handleOf(callback.function.value);
    if (function == null or ffi.v8_Global_IsEmpty(function.?) or !ffi.v8_Value_IsFunction(function.?)) {
        const undef = ffi.v8_Undefined(entered.isolate) orelse return error.OperationFailed;
        defer ffi.v8_Global_Dispose(undef);
        return settledPromiseInContext(entered.context(), undef, true);
    }

    // 5-8. Prepare to run script with F's associated realm's settings object.
    const callback_realm = try CallbackRealm.enter(function.?, entered);
    var scope_active = true;
    defer if (scope_active) callback_realm.scope.deinit();
    defer ffi.v8_Context_Dispose(callback_realm.context);
    if (!callback_realm.runnable()) return error.OperationFailed;

    const receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();
    var js_args: Arguments = .{ .across_worlds = callback_realm.acrossWorlds() };
    defer js_args.release();

    const PromiseOutcome = union(enum) {
        resolved: engine.Owned,
        thrown: Thrown,
    };

    const Args = @TypeOf(args);
    var body: struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        function: *ffi.Value,
        receiver: ?*ffi.Value,
        args: Args,
        js_args: *Arguments,
        result: Error!PromiseOutcome = error.OperationFailed,

        pub fn run(self: *@This()) void {
            // 10. Convert args to a JavaScript arguments list.
            self.js_args.convertTuple(self.isolate, self.context, self.args) catch |err| {
                self.result = err;
                return;
            };
            // 11-12. Call(F, thisArg, jsArgs).
            const raw = callRaw(self.context, self.function, self.receiver, self.js_args.slice()) catch |err| {
                self.result = err;
                return;
            };
            // 13. Convert normal return via PromiseResolve(%Promise%, V) inside
            // prepared scopes (same-realm %Promise% passes through unchanged,
            // matching Chrome 157 + Firefox 159/161 across all 5 Promise
            // callback APIs; non-promises, thenables, subclasses and
            // cross-realm promises wrap in a new %Promise% of F's realm).
            const at: struct {
                isolate: *ffi.Isolate,
                ctx: *ffi.Context,
                pub fn context(s: @This()) *ffi.Context {
                    return s.ctx;
                }
            } = .{ .isolate = self.isolate, .ctx = self.context };
            switch (raw) {
                .thrown => |t| self.result = .{ .thrown = t },
                .normal => |v| {
                    defer ffi.v8_Global_Dispose(v);
                    const resolved = support.promiseResolve(at, v) catch |err| {
                        self.result = err;
                        return;
                    };
                    switch (resolved) {
                        .normal => |promise| self.result = .{ .resolved = support.owned(promise) },
                        .thrown => |exc| self.result = .{ .thrown = .{ .value = exc } },
                    }
                },
            }
        }
    } = .{
        .isolate = entered.isolate,
        .context = callback_realm.context,
        .function = function.?,
        .receiver = receiver.value,
        .args = args,
        .js_args = &js_args,
    };

    // 9 & 14.1. Prepare to run a callback / clean up after running a callback.
    withCallbackContext(entered.isolate, callback.context, &body);
    // 14.2. Clean up after running script (keep `callback_realm.context` until
    // step 14.7-14.9 creates any rejected promise in F's associated realm).
    callback_realm.scope.deinit();
    scope_active = false;

    const outcome = try body.result;
    return switch (outcome) {
        .resolved => |promise| promise,
        .thrown => |thrown| blk: {
            defer ffi.v8_Global_Dispose(thrown.value);
            defer ffi.v8_FreeErrorInfo(thrown.site);
            // 14.7-14.9. Return a promise rejected with completion.[[Value]]
            // in F's associated realm.
            ffi.v8_Context_Enter(callback_realm.context);
            defer ffi.v8_Context_Exit(callback_realm.context);
            break :blk settledPromiseInContext(callback_realm.context, thrown.value, false);
        },
    };
}

/// WebIDL "construct a callback function" (3.12) with typed arguments (step 9)
/// and typed return conversion to `R` (step 12, inside the prepared scopes).
pub fn constructCallbackFunctionAs(
    comptime R: type,
    comptime return_options: engine.ReturnOptions,
    realm: Context,
    callback: *const engine.CallbackFunction,
    args: anytype,
    allocator: std.mem.Allocator,
) Error!engine.Returned(R) {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 2-3. If IsConstructor(F) is false, throw a TypeError in the entered realm.
    const function = support.handleOf(callback.function.value) orelse return .{
        .throw = support.owned(try support.newTypeError(entered.isolate, entered.context(), "The callback is not a constructor")),
    };
    if (ffi.v8_Global_IsEmpty(function) or !ffi.v8_Value_IsConstructor(function)) {
        return .{
            .throw = support.owned(try support.newTypeError(entered.isolate, entered.context(), "The callback is not a constructor")),
        };
    }

    // 4-7. Prepare to run script with F's associated realm's settings object.
    const callback_realm = try CallbackRealm.enter(function, entered);
    var in_callback_realm = true;
    defer if (in_callback_realm) callback_realm.leave();
    if (!callback_realm.runnable()) return error.OperationFailed;

    var js_args: Arguments = .{ .across_worlds = callback_realm.acrossWorlds() };
    defer js_args.release();

    const Args = @TypeOf(args);
    var body: struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        function: *ffi.Value,
        args: Args,
        js_args: *Arguments,
        allocator: std.mem.Allocator,
        result: Error!Converted(R) = error.OperationFailed,

        pub fn run(self: *@This()) void {
            // 9. Convert args to a JavaScript arguments list.
            self.js_args.convertTuple(self.isolate, self.context, self.args) catch |err| {
                self.result = err;
                return;
            };
            // 10-11. Construct(F, jsArgs).
            const raw = constructRaw(self.context, self.function, self.js_args.slice()) catch |err| {
                self.result = err;
                return;
            };
            // 12. Convert constructed object to R inside prepared scopes.
            self.result = switch (raw) {
                .thrown => |t| .{ .thrown = t },
                .normal => |v| convertRawAs(R, return_options, self.allocator, self.isolate, self.context, v),
            };
        }
    } = .{
        .isolate = entered.isolate,
        .context = callback_realm.context,
        .function = function,
        .args = args,
        .js_args = &js_args,
        .allocator = allocator,
    };

    // 8 & 13.1. Prepare to run a callback / clean up after running a callback.
    withCallbackContext(entered.isolate, callback.context, &body);
    // 13.2. Clean up after running script.
    callback_realm.leave();
    in_callback_realm = false;
    // 13.3-13.4. Always rethrow on abrupt completion.
    return finishTyped(R, try body.result, entered.context(), callback_realm.realm, .rethrow);
}

/// WebIDL "call a user object's operation" (3.11) with typed arguments
/// (step 11) and typed return conversion to `R` (step 14, inside the prepared
/// scopes).
pub fn callUserObjectOperationAs(
    comptime R: type,
    comptime return_options: engine.ReturnOptions,
    realm: Context,
    callback: *const engine.CallbackInterface,
    operation: []const u8,
    this_arg: engine.CallbackThis,
    args: anytype,
    behavior: engine.ExceptionBehavior,
    allocator: std.mem.Allocator,
) Error!engine.Returned(R) {
    const entered = try support.enter(realm);
    defer entered.leave();

    // 3. Let O be the JavaScript object corresponding to value.
    const object = support.handleOf(callback.object.value) orelse return error.TypeError;
    if (ffi.v8_Global_IsEmpty(object)) return error.TypeError;
    if (!ffi.v8_Value_IsObject(object)) return error.TypeError;

    // 4-7. Prepare to run script with O's associated realm's settings object.
    const callback_realm = try CallbackRealm.enter(object, entered);
    var in_callback_realm = true;
    defer if (in_callback_realm) callback_realm.leave();
    if (!callback_realm.runnable()) return error.OperationFailed;

    const receiver = try Receiver.of(entered, this_arg);
    defer receiver.release();
    var js_args: Arguments = .{ .across_worlds = callback_realm.acrossWorlds() };
    defer js_args.release();

    const Args = @TypeOf(args);
    var body: struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        object: *ffi.Value,
        operation: []const u8,
        receiver: ?*ffi.Value,
        args: Args,
        js_args: *Arguments,
        allocator: std.mem.Allocator,
        got: ?*ffi.Value = null,
        result: Error!Converted(R) = error.OperationFailed,

        pub fn run(self: *@This()) void {
            self.result = self.steps();
        }

        fn steps(self: *@This()) Error!Converted(R) {
            // 9. Let X be O.
            var function = self.object;
            var this_value = self.receiver;
            // 10. If IsCallable(O) is false, get O[opName].
            if (!ffi.v8_Value_IsFunction(self.object)) {
                var threw = false;
                var site: ?*ffi.V8ErrorInfo = null;
                const get_result = ffi.v8_Object_GetCatchingWithSite(self.context, self.object, self.operation.ptr, @intCast(self.operation.len), &threw, &site);
                if (threw) {
                    const value = get_result orelse {
                        ffi.v8_FreeErrorInfo(site);
                        return error.OperationFailed;
                    };
                    return .{ .thrown = .{ .value = value, .site = site } };
                }
                self.got = get_result orelse return error.OperationFailed;
                function = self.got.?;
                if (!ffi.v8_Value_IsFunction(function)) {
                    return .{ .thrown = .{ .value = try support.newTypeError(self.isolate, self.context, "The callback's operation is not callable") } };
                }
                this_value = self.object;
            }
            // 11. Convert args to a JavaScript arguments list.
            try self.js_args.convertTuple(self.isolate, self.context, self.args);
            // 12-13. Call(X, thisArg, jsArgs).
            const raw = try callRaw(self.context, function, this_value, self.js_args.slice());
            // 14. Convert normal return to R inside prepared scopes.
            return switch (raw) {
                .thrown => |t| .{ .thrown = t },
                .normal => |v| convertRawAs(R, return_options, self.allocator, self.isolate, self.context, v),
            };
        }
    } = .{
        .isolate = entered.isolate,
        .context = callback_realm.context,
        .object = object,
        .operation = operation,
        .receiver = receiver.value,
        .args = args,
        .js_args = &js_args,
        .allocator = allocator,
    };
    defer if (body.got) |got| ffi.v8_Global_Dispose(got);

    // 8 & 15.1. Prepare to run a callback / clean up after running a callback.
    withCallbackContext(entered.isolate, callback.context, &body);
    // 15.2. Clean up after running script.
    callback_realm.leave();
    in_callback_realm = false;
    // 15.3-15.4. Return value or handle abrupt completion under `behavior`.
    return finishTyped(R, try body.result, entered.context(), callback_realm.realm, behavior);
}

/// Convert a JavaScript value to WebIDL type `T` in `realm` (for spec prose
/// dictionary / value conversions), catching any thrown exception.
pub fn convertFromJS(
    comptime T: type,
    comptime options: engine.ReturnOptions,
    realm: Context,
    value: JSValue,
    allocator: std.mem.Allocator,
) Error!engine.Returned(T) {
    const entered = try support.enter(realm);
    defer entered.leave();

    const raw = try support.ownGlobal(entered, value);
    const converted = try convertRawAs(T, options, allocator, entered.isolate, entered.context(), raw);
    return finishTyped(T, converted, entered.context(), realm, .rethrow);
}

/// Release what a `Held(R)` owns: the converted value's allocations/handles
/// (allocated with `allocator`) and the underlying `js` handle.
pub fn releaseReturned(comptime R: type, allocator: std.mem.Allocator, held: engine.Held(R)) void {
    if (comptime R == void) {
        held.js.release();
        return;
    }
    if (comptime R == JSValue) {
        // `held.value` borrows `held.js`'s Global directly; do not release twice.
        held.js.release();
        return;
    }
    if (comptime interface.argHandleIsCopied(R)) {
        interface.freeConvertedArg(R, allocator, held.value);
    } else {
        interface.freeArgument(R, allocator, held.value);
    }
    held.js.release();
}

/// A borrowed callback function value (the binding's Global, BORROWED for the
/// call: an argument's, or a dictionary member's, union arm's or sequence
/// element's own Get handle), kept as a CallbackFunction of the caller's own:
/// the function MOVES out of the binding's Global into one of the caller's
/// (`keptHandle`), tagged with the realm whose API keeps it, with its callback
/// context - the incumbent realm now, which is the conversion's (WebIDL 3.2.19
/// step 2): a borrowed value lives only for its call. Blink records the same
/// realm when it converts (CallbackFunctionBase's constructor,
/// `isolate->GetIncumbentContext()`). A value kept already gives undefined.
pub fn keepCallbackFunction(callback: engine.BorrowedCallbackFunction) engine.CallbackFunction {
    const function = keptHandle(callback.function);
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return .{ .function = .{ .value = function }, .context = null };
    tagWithCurrentRealm(isolate, function);
    return .{ .function = .{ .value = function }, .context = incumbentRealm(isolate) };
}

/// engine.keepCallbackFunctionTraced: the function's value in a traced hold
/// (v8_TracedHold_New: a TracedReference its owner traces, no root, in a
/// cell of the agent's hold slab), with its
/// callback context the incumbent realm now. The binding's Global stays the
/// binding's, released when the call returns; no realm tag - a traced value
/// roots nothing, so a detached realm has nothing to weaken. A value with no
/// handle gives an empty hold.
pub fn keepCallbackFunctionTraced(callback: engine.BorrowedCallbackFunction) engine.TracedCallback {
    return keptTraced(callback.function);
}

/// engine.keepCallbackInterfaceTraced, as keepCallbackFunctionTraced.
pub fn keepCallbackInterfaceTraced(callback: engine.BorrowedCallbackInterface) engine.TracedCallback {
    return keptTraced(callback.object);
}

fn keptTraced(value: JSValue) engine.TracedCallback {
    const handle = support.handleOf(value) orelse return .{ .hold = .{}, .context = null };
    const hold: engine.TracedHold = .{ .handle = ffi.v8_TracedHold_New(handle) };
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return .{ .hold = hold, .context = null };
    return .{ .hold = hold, .context = incumbentRealm(isolate) };
}

/// A borrowed callback interface value, kept as keepCallbackFunction keeps a
/// function (WebIDL 3.2.16 step 2).
pub fn keepCallbackInterface(callback: engine.BorrowedCallbackInterface) engine.CallbackInterface {
    const object = keptHandle(callback.object);
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return .{ .object = .{ .value = object }, .context = null };
    tagWithCurrentRealm(isolate, object);
    return .{ .object = .{ .value = object }, .context = incumbentRealm(isolate) };
}

/// The value the binding's Global holds, MOVED into a Global of the caller's
/// own (v8_Global_TakeOver: no V8 handle made, one 16 B box; a weak Global is
/// copied instead, its arm left on the box). The binding's Global is left
/// empty, still the binding's to free when the call returns
/// (v8_Global_DisposeCallbackValue deletes an emptied one without the general
/// dispose's lookups). An empty one - kept already - gives undefined.
fn keptHandle(value: JSValue) JSValue {
    const handle = support.handleOf(value) orelse return JSValue.jsUndefined;
    const own = ffi.v8_Global_TakeOver(handle) orelse return JSValue.jsUndefined;
    return realm_entry.owned(@ptrCast(own));
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
