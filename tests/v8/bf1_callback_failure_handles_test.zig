//! Rejected callback conversions adopt nothing; their input handles must go.
const std = @import("std");
const engine = @import("engine");
const v8 = @import("v8");
const ffi = v8.ffi;
const Callback = ?*const fn () void;
const Strategy = struct { size: Callback = null };
const Ordinary = struct { mode: enum { valid } = .valid };
const Case = enum { argument, callback_member, ordinary_member };

fn eval(isolate: *ffi.Isolate, context: *ffi.Context, source: []const u8) !*ffi.Value {
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.NoString;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.NoScript;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.NoValue;
}

fn convert(comptime case: Case, isolate: *ffi.Isolate, context: *ffi.Context) !void {
    const source = switch (case) {
        .argument => "42",
        .callback_member => "({size: 42})",
        .ordinary_member => "({mode: 'invalid'})",
    };
    const value = try eval(isolate, context, source);
    if (case == .argument) {
        // The binding takes this handle, including on the TypeError path.
        try std.testing.expectError(error.TypeError, v8.interface_mod.convertArgReleasing(Callback, std.testing.allocator, isolate, context, value));
    } else {
        defer ffi.v8_Value_Dispose(value);
        const T = if (case == .callback_member) Strategy else Ordinary;
        try std.testing.expectError(error.TypeError, v8.conversions.fromV8Value(T, std.testing.allocator, isolate, context, value));
    }
}

fn check(comptime case: Case) !void {
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
    try convert(case, isolate, context);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..64) |_| try convert(case, isolate, context);
    try std.testing.expectEqual(before, ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
}

fn onThread(comptime case: Case) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check(case);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

test "rejected nullable callback arguments release their handles" {
    try onThread(.argument);
}
test "rejected dictionary callbacks release their Get handles" {
    try onThread(.callback_member);
}
test "ordinary dictionary member failure still releases its Get handle" {
    try onThread(.ordinary_member);
}

// Pin the ownership predicate's default before using it on an open set of types.
test "only raw callback conversions adopt their input on success" {
    const adopts = v8.conversions.callbackConversionAdoptsInput;
    try std.testing.expect(adopts(*const fn () void));
    try std.testing.expect(adopts(Callback));
    try std.testing.expect(!adopts(*anyopaque));
    try std.testing.expect(!adopts(?*anyopaque));
    try std.testing.expect(!adopts(struct { unknown: *anyopaque }));
    try std.testing.expect(!adopts(@import("runtime").JSValue));
    try std.testing.expect(!adopts(Ordinary));
}
