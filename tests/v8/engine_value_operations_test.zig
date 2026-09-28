//! The Engine table's operations on values held across the seam, as V8
//! implements them: retainValue, throwValue and
//! convertToSequenceOfPlatformObjects.
//!
//! Code outside the adapter (AGENTS.md, "The engine boundary") holds a script
//! value as a runtime.JSValue and must be able to keep it past the call that
//! handed it over, throw it back into script, and convert an iterable of
//! platform objects - without a V8 type in sight.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const engine = &v8.engine.v8_engine_interface;

/// One isolate, context and realm for the file, as in
/// engine_realm_operations_test.zig - V8 is never torn down here.
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var data_once: ?*runtime.ContextData = null;

fn realm() !runtime.Context {
    if (data_once) |d| return d;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    ffi.v8_Isolate_SetMicrotasksPolicy(i, @intFromEnum(ffi.MicrotasksPolicy.Explicit));
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const r = try runtime.Realm.init(std.heap.page_allocator, .{ .v8_context = context, .isolate = i });
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{
        .engine = engine,
        .engine_ctx = context,
        .realm = r,
    });
    isolate_once = i;
    context_once = context;
    data_once = data;
    return data;
}

/// The completion value of `code`: an owned Global.
fn eval(code: []const u8) !*ffi.Value {
    const i = isolate_once.?;
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(i, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

/// `code`'s completion value as an integer.
fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

/// Set global `name` to the value `handle` holds (borrowed).
fn setGlobal(name: []const u8, handle: *anyopaque) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(@alignCast(handle)));
}

fn asValue(handle: *ffi.Value) runtime.JSValue {
    return .{ .handle = .{ .ptr = @ptrCast(handle), .needs_disposal = false, .handle_scope = .global } };
}

/// An argument as the binding hands it to an impl: conversions.fromV8Value's
/// runtime.JSValue branch. An object is a `.handle` tagged `.local` - borrowed
/// for the call - whose pointer is the argument's Global<Value>, not a Local.
fn asArgument(argument: *ffi.Value) !runtime.JSValue {
    return v8.conversions.fromV8Value(runtime.JSValue, std.testing.allocator, isolate_once.?, context_once.?, argument);
}

// ----------------------------------------------------------------------------
// retainValue
// ----------------------------------------------------------------------------

test "a retained value is the caller's own handle, and outlives the one it came from" {
    const ctx = try realm();
    const object = try eval("globalThis.original = { tag: 5 }; globalThis.original");
    const kept = try engine.retainValue.?(ctx, asValue(object));
    // The argument stays the caller's: releasing it leaves the retained one.
    ffi.v8_Value_Dispose(object);
    defer engine.releaseValue.?(kept);
    try std.testing.expect(kept == .handle);
    try std.testing.expect(kept.handle.needs_disposal);
    try std.testing.expectEqual(runtime.JSValue.EngineHandle.HandleScope.global, kept.handle.handle_scope);
    try setGlobal("kept", kept.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.kept === globalThis.original ? 1 : 0"));
}

test "primitives and strings are retained as values of the realm" {
    const ctx = try realm();
    const number = try engine.retainValue.?(ctx, .{ .number = 42 });
    defer engine.releaseValue.?(number);
    try setGlobal("n", number.handle.ptr);
    try std.testing.expectEqual(@as(i32, 42), try evalInt("globalThis.n"));

    const text = try engine.retainValue.?(ctx, runtime.JSValue.fromStringRef("abc"));
    defer engine.releaseValue.?(text);
    try setGlobal("s", text.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.s === 'abc' ? 1 : 0"));

    const nothing = try engine.retainValue.?(ctx, runtime.JSValue.jsUndefined);
    defer engine.releaseValue.?(nothing);
    try setGlobal("u", nothing.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.u === undefined ? 1 : 0"));
}

// ----------------------------------------------------------------------------
// throwValue
// ----------------------------------------------------------------------------

/// A native function that throws its first argument through the Engine
/// table, as an impl does: `throwValue`, then return.
fn throwFirstArgument(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    engine.throwValue.?(data_once.?, asValue(argument)) catch {};
}

fn installNative(name: []const u8, callback: ffi.FunctionCallback) !void {
    const context = context_once.?;
    const template = ffi.v8_FunctionTemplate_New(isolate_once.?, callback, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const function = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionFailed;
    defer ffi.v8_Function_Dispose(function);
    try setGlobal(name, @ptrCast(function));
}

test "a thrown value reaches the calling script's catch, as itself" {
    _ = try realm();
    try installNative("rethrow", throwFirstArgument);
    try std.testing.expectEqual(@as(i32, 7), try evalInt("(() => { try { rethrow(7); return -1; } catch (e) { return e; } })()"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => { const o = { reason: 1 }; try { rethrow(o); } catch (e) { return e === o ? 1 : 0; } return -1; })()
    ));
}

/// What `keep` retained, as an impl retains an argument it must outlive the
/// call with.
var kept_argument: ?runtime.JSValue = null;

fn keepFirstArgument(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    const value = asArgument(argument) catch return;
    kept_argument = engine.retainValue.?(data_once.?, value) catch null;
}

fn throwFirstArgumentAsBound(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    const value = asArgument(argument) catch return;
    engine.throwValue.?(data_once.?, value) catch {};
}

test "an argument as the binding hands it over is retained and thrown as itself" {
    _ = try realm();
    try installNative("keep", keepFirstArgument);
    try installNative("rethrowBound", throwFirstArgumentAsBound);
    try std.testing.expectEqual(@as(i32, 0), try evalInt("globalThis.handed = { k: 1 }; keep(globalThis.handed); 0"));
    const kept = kept_argument orelse return error.NotKept;
    kept_argument = null;
    defer engine.releaseValue.?(kept);
    try setGlobal("keptHanded", kept.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.keptHanded === globalThis.handed ? 1 : 0"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => { const o = { reason: 2 }; try { rethrowBound(o); } catch (e) { return e === o ? 1 : 0; } return -1; })()
    ));
}

test "throwing a value made from a Zig string" {
    const ctx = try realm();
    _ = ctx;
    try installNative("throwText", struct {
        fn f(_: *const ffi.FunctionCallbackInfo) callconv(.c) void {
            engine.throwValue.?(data_once.?, runtime.JSValue.fromStringRef("from zig")) catch {};
        }
    }.f);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("(() => { try { throwText(); } catch (e) { return e === 'from zig' ? 1 : 0; } return -1; })()"));
}

// ----------------------------------------------------------------------------
// convertToSequenceOfPlatformObjects
// ----------------------------------------------------------------------------

const mock_methods: u8 = 0;
const mock_vtable = runtime.VTable{
    .name = "MockSignal",
    .deinit = null,
    .methods_ptr = &mock_methods,
};

var mock_instances: [2]runtime.Instance = undefined;

/// Globals `a` and `b`: objects with internal fields whose field 0 is a mock
/// Instance, as the bindings wrap platform objects.
fn installPlatformObjects() !void {
    const context = context_once.?;
    const template = ffi.v8_ObjectTemplate_New(isolate_once.?);
    defer ffi.v8_ObjectTemplate_Dispose(template);
    ffi.v8_ObjectTemplate_SetInternalFieldCount(template, 2);
    for (&mock_instances, [_][]const u8{ "a", "b" }) |*instance, name| {
        instance.* = .{ .vtable = &mock_vtable, .state = undefined, .ctx = data_once.? };
        const object = ffi.v8_ObjectTemplate_NewInstance(template, context) orelse return error.InstanceFailed;
        defer ffi.v8_Object_Dispose(object);
        ffi.v8_Object_SetAlignedPointerInInternalField(object, 0, @ptrCast(instance));
        ffi.v8_Object_SetAlignedPointerInInternalField(object, 1, null);
        try setGlobal(name, @ptrCast(object));
    }
}

test "an array of platform objects converts to their instances, in order" {
    const ctx = try realm();
    try installPlatformObjects();
    const array = try eval("[b, a, b]");
    defer ffi.v8_Value_Dispose(array);
    const list = try engine.convertToSequenceOfPlatformObjects.?(ctx, asValue(array), std.testing.allocator);
    defer std.testing.allocator.free(list);
    try std.testing.expectEqual(@as(usize, 3), list.len);
    try std.testing.expectEqual(&mock_instances[1], list[0]);
    try std.testing.expectEqual(&mock_instances[0], list[1]);
    try std.testing.expectEqual(&mock_instances[1], list[2]);
}

test "any iterable converts, not only an Array" {
    const ctx = try realm();
    try installPlatformObjects();
    const set = try eval("new Set([a, b])");
    defer ffi.v8_Value_Dispose(set);
    const list = try engine.convertToSequenceOfPlatformObjects.?(ctx, asValue(set), std.testing.allocator);
    defer std.testing.allocator.free(list);
    try std.testing.expectEqual(@as(usize, 2), list.len);
    try std.testing.expectEqual(&mock_instances[0], list[0]);

    const generated = try eval("(function* () { yield a; })()");
    defer ffi.v8_Value_Dispose(generated);
    const one = try engine.convertToSequenceOfPlatformObjects.?(ctx, asValue(generated), std.testing.allocator);
    defer std.testing.allocator.free(one);
    try std.testing.expectEqual(@as(usize, 1), one.len);

    const empty = try eval("[]");
    defer ffi.v8_Value_Dispose(empty);
    const none = try engine.convertToSequenceOfPlatformObjects.?(ctx, asValue(empty), std.testing.allocator);
    defer std.testing.allocator.free(none);
    try std.testing.expectEqual(@as(usize, 0), none.len);
}

test "a non-object, a non-iterable, and a non-platform item are TypeErrors" {
    const ctx = try realm();
    try installPlatformObjects();
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.TypeError, engine.convertToSequenceOfPlatformObjects.?(ctx, .{ .number = 1 }, allocator));
    try std.testing.expectError(error.TypeError, engine.convertToSequenceOfPlatformObjects.?(ctx, runtime.JSValue.jsNull, allocator));

    const plain = try eval("({ length: 1, 0: a })");
    defer ffi.v8_Value_Dispose(plain);
    try std.testing.expectError(error.TypeError, engine.convertToSequenceOfPlatformObjects.?(ctx, asValue(plain), allocator));

    const mixed = try eval("[a, {}]");
    defer ffi.v8_Value_Dispose(mixed);
    try std.testing.expectError(error.TypeError, engine.convertToSequenceOfPlatformObjects.?(ctx, asValue(mixed), allocator));
}

/// A native function that converts its argument, as an impl does, and
/// reports what came back: the length, or -1 for a TypeError. An
/// ExceptionPending returns nothing, so the exception reaches the script.
fn convertFirstArgument(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    const i = info.getIsolate();
    // As an impl gets it: the binding's form of the argument.
    const value = asArgument(argument) catch return;
    const result: f64 = if (engine.convertToSequenceOfPlatformObjects.?(data_once.?, value, std.testing.allocator)) |list| blk: {
        defer std.testing.allocator.free(list);
        break :blk @floatFromInt(list.len);
    } else |err| switch (err) {
        error.ExceptionPending => return,
        else => -1,
    };
    const number = ffi.v8_Number_New(i, result);
    defer ffi.v8_Value_Dispose(@ptrCast(number));
    info.setReturnValue(@ptrCast(number));
}

test "what the iteration throws propagates to the calling script" {
    _ = try realm();
    try installPlatformObjects();
    try installNative("convert", convertFirstArgument);
    try std.testing.expectEqual(@as(i32, 2), try evalInt("convert([a, b])"));
    try std.testing.expectEqual(@as(i32, -1), try evalInt("convert(5)"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const boom = new Error("boom");
        \\  const bad = { [Symbol.iterator]() { return { next() { throw boom; } }; } };
        \\  try { convert(bad); } catch (e) { return e === boom ? 1 : 0; }
        \\  return -1;
        \\})()
    ));
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const boom = new Error("getter");
        \\  const bad = { get [Symbol.iterator]() { throw boom; } };
        \\  try { convert(bad); } catch (e) { return e === boom ? 1 : 0; }
        \\  return -1;
        \\})()
    ));
}
