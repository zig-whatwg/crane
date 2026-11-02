//! The Engine table's built-in functions, as V8 implements them
//! (worker_realm.zig): defineBuiltinFunction and isCallable - what a worker
//! host installs its timers with, and checks a timer's handler with.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

var test_isolate: ?*ffi.Isolate = null;
var test_context: ?*ffi.Context = null;
var test_data: ?*runtime.ContextData = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
    test_context = null;
    test_data = null;
}

fn realm() !runtime.Context {
    const i = try test_agent.open(.{});
    if (test_data == null) {
        ffi.v8_Isolate_SetMicrotasksPolicy(i, @backingInt(ffi.MicrotasksPolicy.Explicit));
        const context = test_agent.context.?;
        const data = try test_agent.contextData(std.heap.page_allocator, .{ .engine_ctx = context });
        data.agent = @ptrCast(i);
        test_isolate = i;
        test_context = context;
        test_data = data;
    }
    return test_data.?;
}

fn eval(code: []const u8) !*ffi.Value {
    const context = test_context.?;
    const text = ffi.v8_String_NewFromUtf8(test_isolate.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, test_context.?);
}

fn asValue(handle: *ffi.Value) runtime.JSValue {
    return .{ .handle = .{ .ptr = @ptrCast(handle) } };
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
            .handle => self.callable = v8.worker_realm.isCallable(arg),
            else => {},
        };
        return runtime.JSValue.fromNumber(@floatFromInt(args.len * 10));
    }
};

var recorder: Recorder = .{};
var recorder_function: runtime.BuiltinFunction = .{ .steps = Recorder.steps, .data = &recorder };

test "a built-in is an own property of the global, with its length, and sees its arguments" {
    defer test_agent.close();
    const ctx = try realm();
    try v8.worker_realm.defineBuiltinFunction(ctx, "record", 2, &recorder_function);
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
    defer test_agent.close();
    const ctx = try realm();
    try v8.worker_realm.defineBuiltinFunction(ctx, "fails", 0, &failing_function);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("(() => { try { fails(); } catch (e) { return e instanceof TypeError ? 1 : 0; } return -1; })()"));
}

test "isCallable" {
    defer test_agent.close();
    _ = try realm();
    const function = try eval("(() => 1)");
    defer ffi.v8_Value_Dispose(function);
    try std.testing.expect(v8.worker_realm.isCallable(asValue(function)));
    const object = try eval("({})");
    defer ffi.v8_Value_Dispose(object);
    try std.testing.expect(!v8.worker_realm.isCallable(asValue(object)));
    try std.testing.expect(!v8.worker_realm.isCallable(.{ .number = 1 }));
}

test "isCallable of an argument as the binding hands it over" {
    defer test_agent.close();
    _ = try realm();
    // conversions.fromV8Value's runtime.JSValue branch: a borrowed `.handle`
    // whose pointer is the argument's Global<Value>.
    const function = try eval("(function () {})");
    defer ffi.v8_Value_Dispose(function);
    const argument = try v8.conversions.fromV8Value(runtime.JSValue, std.testing.allocator, test_isolate.?, test_context.?, function);
    try std.testing.expect(v8.worker_realm.isCallable(argument));
    const object = try eval("({ notCallable: true })");
    defer ffi.v8_Value_Dispose(object);
    const not_callable = try v8.conversions.fromV8Value(runtime.JSValue, std.testing.allocator, test_isolate.?, test_context.?, object);
    try std.testing.expect(!v8.worker_realm.isCallable(not_callable));
}
