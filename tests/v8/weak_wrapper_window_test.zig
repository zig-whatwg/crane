//! A C++ helper handed a wrapper the wrapper cache holds weakly must read it
//! before it allocates.
//!
//! The cache hands out its own `Global*`, weak; a wrapper made a moment ago is
//! reachable from nothing else. A helper that allocates first - a descriptor
//! object, a name string - can start a scavenge that collects the wrapper,
//! and the first-pass callback resets the very handle the helper reads next:
//! it gets an empty Local (docs/lessons/
//! architecture-a-weakly-held-wrapper-dies-at-the-next-allocation.md).
//! leaks2's audit of every caller of a cache handle found three live ones:
//! `v8_CreateDataPropertyDescriptor` (an indexed or named property
//! descriptor of a platform object: Object.getOwnPropertyDescriptor(list, 0)),
//! `v8_CompileEventHandlerWithParameters` (an event handler's scope
//! wrappers) and `v8_Module_CreateDefaultExportSyntheticModule` (a CSS module
//! script's CSSStyleSheet).
//!
//! As in private_edge_weak_member_test.zig: no V8 flag forces a collection at
//! one allocation in this build, so each round makes a fresh weak member and
//! does little else, and the window's allocations are a large share of the
//! young generation's. A canary counts collections so a pass is not vacuous.

const std = @import("std");
const testing = std.testing;
const v8 = @import("v8");
const ffi = v8.ffi;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var env_once: ?Env = null;

fn env() !Env {
    if (env_once) |e| return e;
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    env_once = .{ .isolate = isolate, .context = context };
    return env_once.?;
}

fn noop(_: ?*anyopaque, _: usize) callconv(.c) void {}

fn countCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const counter: *usize = @ptrCast(@alignCast(data orelse return));
    counter.* += 1;
}

/// Weak canaries, one every `every` rounds: how many the collector took.
const Canaries = struct {
    collected: usize = 0,
    list: std.ArrayListUnmanaged(*ffi.Object) = .empty,

    fn plant(self: *Canaries, isolate: *ffi.Isolate) !void {
        const canary = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
        ffi.v8_Global_SetWeak(@ptrCast(canary), @ptrCast(&self.collected), countCollected);
        try self.list.append(testing.allocator, canary);
    }

    fn deinit(self: *Canaries) void {
        for (self.list.items) |c| ffi.v8_Object_Dispose(c);
        self.list.deinit(testing.allocator);
    }
};

/// A member as the wrapper cache holds a wrapper script has not kept: a
/// fresh object, armed weak, held by nothing else.
fn weakMember(isolate: *ffi.Isolate) !*ffi.Object {
    const member = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
    ffi.v8_Global_SetWeak(@ptrCast(member), null, noop);
    return member;
}

test "a data property descriptor of a value only a weak handle holds carries the value" {
    const e = try env();
    var canaries: Canaries = .{};
    defer canaries.deinit();
    const value_key = ffi.v8_String_NewFromUtf8(e.isolate, "value", 5) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(value_key);

    const rounds: usize = 100_000;
    for (0..rounds) |round| {
        const member = try weakMember(e.isolate);
        defer ffi.v8_Object_Dispose(member);
        const descriptor = ffi.v8_CreateDataPropertyDescriptor(e.context, @ptrCast(member), true, true, true) orelse return error.NoDescriptor;
        defer ffi.v8_Object_Dispose(descriptor);
        // The descriptor holds its value: an object, whatever collection ran.
        const value = ffi.v8_Object_Get(descriptor, e.context, @ptrCast(value_key)) orelse return error.NoValue;
        defer ffi.v8_Value_Dispose(value);
        try testing.expect(ffi.v8_Value_IsObject(value));
        if (round % 1000 == 0) try canaries.plant(e.isolate);
    }
    try testing.expect(canaries.collected > 0);
}

test "an event handler compiled with a scope only a weak handle holds sees that scope" {
    const e = try env();
    var canaries: Canaries = .{};
    defer canaries.deinit();
    const x_key = ffi.v8_String_NewFromUtf8(e.isolate, "lk2Scope", 8) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(x_key);
    const marker = ffi.v8_Number_New(e.isolate, 7);
    defer ffi.v8_Value_Dispose(@ptrCast(marker));
    const receiver = ffi.v8_Undefined(e.isolate) orelse return error.UndefinedFailed;
    defer ffi.v8_Value_Dispose(receiver);
    var no_arguments: [1]*ffi.Value = undefined;

    // A long body: its string is most of what each round allocates before
    // the scopes are read.
    const body_text = "return lk2Scope;" ++ (" " ** 16_000);
    const name = "onlk2";
    const parameters = [_][*:0]const u8{"event"};

    const rounds: usize = 20_000;
    for (0..rounds) |round| {
        const scope = try weakMember(e.isolate);
        defer ffi.v8_Object_Dispose(scope);
        if (!ffi.v8_Object_Set(scope, e.context, @ptrCast(x_key), @ptrCast(marker))) return error.SetFailed;
        var scopes = [_]?*ffi.Object{scope};
        var parse_error: ?*ffi.V8ErrorInfo = null;
        defer ffi.v8_FreeErrorInfo(parse_error);
        const function = ffi.v8_CompileEventHandlerWithParameters(
            e.context,
            name.ptr,
            name.len,
            body_text.ptr,
            body_text.len,
            &parameters,
            parameters.len,
            &scopes,
            1,
            &parse_error,
        ) orelse return error.CompileFailed;
        defer ffi.v8_Value_Dispose(function);
        if (round % 1000 == 0) {
            // The function closes over the scope it was given.
            const result = ffi.v8_Function_Call(@ptrCast(function), e.context, receiver, 0, &no_arguments) orelse return error.CallFailed;
            defer ffi.v8_Value_Dispose(result);
            try testing.expectEqual(@as(i32, 7), ffi.v8_Value_Int32Value(result, e.context));
            try canaries.plant(e.isolate);
        }
    }
    try testing.expect(canaries.collected > 0);
}
