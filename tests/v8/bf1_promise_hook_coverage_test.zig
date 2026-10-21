//! Pin the public V8 hooks' coverage before relying on them for HTML jobs.
const std = @import("std");
const engine = @import("engine");
const v8 = @import("v8");
const ffi = v8.ffi;

const Counts = struct {
    init: usize = 0,
    before: usize = 0,
    after: usize = 0,
    fn hook(kind: c_int, data: ?*anyopaque) callconv(.c) void {
        const self: *@This() = @ptrCast(@alignCast(data.?));
        // v8-promise.h: kInit, kResolve, kBefore, kAfter.
        switch (kind) {
            0 => self.init += 1,
            2 => self.before += 1,
            3 => self.after += 1,
            else => {},
        }
    }
};
fn eval(isolate: *ffi.Isolate, context: *ffi.Context, source: []const u8) !*ffi.Value {
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.NoString;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.NoScript;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.NoValue;
}
fn check() !void {
    try engine.initializeEngine(.{});
    const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.NoScope;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    const cases = [_]struct { name: []const u8, setup: []const u8, register: []const u8, init: usize }{
        .{ .name = "plain then", .setup = "globalThis.p = Promise.resolve(); globalThis.ran = false;", .register = "p.then(() => { ran = true; })", .init = 1 },
        .{ .name = "species returning existing promise", .setup =
        \\globalThis.p = Promise.resolve(); globalThis.ran = false;
        \\globalThis.existing = Promise.resolve();
        \\p.constructor = { [Symbol.species]: function(executor) {
        \\  executor(() => {}, () => {}); return existing;
        \\} };
        , .register = "p.then(() => { ran = true; })", .init = 0 },
        .{ .name = "species returning plain object", .setup =
        \\globalThis.p = Promise.resolve(); globalThis.ran = false;
        \\p.constructor = { [Symbol.species]: function(executor) {
        \\  executor(() => {}, () => {}); return {};
        \\} };
        , .register = "p.then(() => { ran = true; })", .init = 0 },
        .{ .name = "thenable assimilation", .setup = "globalThis.ran = false; globalThis.resolveP = null; globalThis.p = new Promise(r => { resolveP = r; });", .register = "resolveP({ then(resolve) { ran = true; resolve(3); } })", .init = 0 },
    };
    for (cases) |case| {
        ffi.v8_Value_Dispose(try eval(isolate, context, case.setup));
        var counts: Counts = .{};
        try std.testing.expect(ffi.v8_test_Isolate_SetPromiseHook(isolate, Counts.hook, &counts));
        defer _ = ffi.v8_test_Isolate_SetPromiseHook(isolate, null, null);
        ffi.v8_Value_Dispose(try eval(isolate, context, case.register));
        ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
        try std.testing.expect(ffi.v8_test_Isolate_SetPromiseHook(isolate, null, null));
        std.debug.print("promise hook probe: {s}: init={d}, before={d}, after={d}\n", .{ case.name, counts.init, counts.before, counts.after });
        try std.testing.expectEqual(case.init, counts.init);
        try std.testing.expectEqual(counts.before, counts.after);
        const ran = try eval(isolate, context, "ran");
        defer ffi.v8_Value_Dispose(ran);
        try std.testing.expect(try v8.conversions.fromV8Value(bool, std.testing.allocator, isolate, context, ran));
    }
}
test "public promise lifecycle hooks miss valid job registration forms" {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}
