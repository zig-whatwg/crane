//! The Engine table's built-in functions, as V8 implements them
//! (worker_realm.zig): defineBuiltinFunction and isCallable - what a worker
//! host installs its timers with, and checks a timer's handler with.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const engine = &v8.engine.v8_engine_interface;

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
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine = engine, .engine_ctx = context });
    data.agent = @ptrCast(i);
    isolate_once = i;
    context_once = context;
    data_once = data;
    return data;
}

fn eval(code: []const u8) !*ffi.Value {
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

fn asValue(handle: *ffi.Value) runtime.JSValue {
    return .{ .handle = .{ .ptr = @ptrCast(handle), .needs_disposal = false, .handle_scope = .global } };
}

/// What a built-in saw of its arguments.
const Recorder = struct {
    calls: usize = 0,
    kinds: [4]std.meta.Tag(runtime.JSValue) = undefined,
    count: usize = 0,
    text: [16]u8 = undefined,
    text_len: usize = 0,
    callable: bool = false,

    fn steps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Recorder = @ptrCast(@alignCast(data.?));
        self.calls += 1;
        self.count = @min(args.len, self.kinds.len);
        for (args[0..self.count], 0..) |arg, i| self.kinds[i] = std.meta.activeTag(arg);
        for (args) |arg| switch (arg) {
            .string => |s| {
                self.text_len = @min(s.data.len, self.text.len);
                @memcpy(self.text[0..self.text_len], s.data[0..self.text_len]);
            },
            .handle => self.callable = engine.isCallable.?(arg),
            else => {},
        };
        return runtime.JSValue.fromNumber(@floatFromInt(args.len * 10));
    }
};

var recorder: Recorder = .{};
var recorder_function: runtime.BuiltinFunction = .{ .steps = Recorder.steps, .data = &recorder };

test "a built-in is an own property of the global, with its length, and sees its arguments" {
    const ctx = try realm();
    try engine.defineBuiltinFunction.?(ctx, "record", 2, &recorder_function);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("Object.getOwnPropertyDescriptor(globalThis, 'record').writable && record.length === 2 ? 1 : 0"));
    try std.testing.expectEqual(@as(i32, 40), try evalInt("record(1, 'txt', function () {}, undefined)"));
    try std.testing.expectEqual(@as(usize, 1), recorder.calls);
    try std.testing.expectEqual(@as(usize, 4), recorder.count);
    try std.testing.expectEqual(std.meta.Tag(runtime.JSValue).number, recorder.kinds[0]);
    try std.testing.expectEqual(std.meta.Tag(runtime.JSValue).string, recorder.kinds[1]);
    try std.testing.expectEqual(std.meta.Tag(runtime.JSValue).handle, recorder.kinds[2]);
    try std.testing.expectEqual(std.meta.Tag(runtime.JSValue).undefined, recorder.kinds[3]);
    try std.testing.expectEqualStrings("txt", recorder.text[0..recorder.text_len]);
    try std.testing.expect(recorder.callable);
    try std.testing.expectEqual(@as(i32, 10), try evalInt("record({ notCallable: true })"));
    try std.testing.expect(!recorder.callable);
}

fn failing(_: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
    return runtime.EngineError.TypeError;
}
var failing_function: runtime.BuiltinFunction = .{ .steps = failing, .data = null };

test "an error from a built-in's steps is thrown as WebIDL throws an impl's" {
    const ctx = try realm();
    try engine.defineBuiltinFunction.?(ctx, "fails", 0, &failing_function);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("(() => { try { fails(); } catch (e) { return e instanceof TypeError ? 1 : 0; } return -1; })()"));
}

test "isCallable" {
    _ = try realm();
    const function = try eval("(() => 1)");
    defer ffi.v8_Value_Dispose(function);
    try std.testing.expect(engine.isCallable.?(asValue(function)));
    const object = try eval("({})");
    defer ffi.v8_Value_Dispose(object);
    try std.testing.expect(!engine.isCallable.?(asValue(object)));
    try std.testing.expect(!engine.isCallable.?(.{ .number = 1 }));
}

test "isCallable of an argument as the binding hands it over" {
    _ = try realm();
    // conversions.fromV8Value's runtime.JSValue branch: a `.handle` tagged
    // `.local` whose pointer is the argument's Global<Value>.
    const function = try eval("(function () {})");
    defer ffi.v8_Value_Dispose(function);
    const argument = try v8.conversions.fromV8Value(runtime.JSValue, std.testing.allocator, isolate_once.?, context_once.?, function);
    try std.testing.expect(engine.isCallable.?(argument));
    const object = try eval("({ notCallable: true })");
    defer ffi.v8_Value_Dispose(object);
    const not_callable = try v8.conversions.fromV8Value(runtime.JSValue, std.testing.allocator, isolate_once.?, context_once.?, object);
    try std.testing.expect(!engine.isCallable.?(not_callable));
}
