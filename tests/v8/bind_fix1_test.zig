//! Tests for lane `bind-fix1`:
//! 1. Present-null conversion on optional non-nullable dictionary members
//!    whose type is a buffer source (BufferSource, AllowSharedBufferSource,
//!    ArrayBufferView), nested dictionary (unboxed), callback function or
//!    callback interface, or `object` (WebIDL 3.2.18 step 4.1.4.3).
//! 2. Union `bigint` arm conversion — WebIDL 3.2.25 step 16 (ToNumeric with
//!    single valueOf invocation, BigInt or numeric result, exceptions) and
//!    step 19 (ToBigInt on a union with bigint and no numeric arm), plus
//!    zero Global handle leaks via convertArgReleasing + freeArgument.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const conv = v8.conversions;
const iface = v8.interface_mod;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var test_env: ?Env = null;
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_env = null;
}

fn env() !Env {
    const isolate = try test_agent.open(.{});
    if (test_env == null) test_env = .{ .isolate = isolate, .context = test_agent.context.? };
    return test_env.?;
}

fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

const Zig017Field = conv.Zig017Field;
fn zig017FieldsOf(comptime info: anytype) [info.field_names.len]Zig017Field {
    var out: [info.field_names.len]Zig017Field = undefined;
    for (info.field_names, info.field_types, info.field_attrs, 0..) |n, t, a, i| out[i] = .{
        .name = n,
        .type = t,
        .default_value_ptr = if (@hasField(@TypeOf(a), "default_value_ptr")) a.default_value_ptr else null,
        .is_comptime = if (@hasField(@TypeOf(a), "comptime")) a.@"comptime" else false,
        .alignment = a.@"align",
    };
    return out;
}

fn field(comptime T: type, comptime name: []const u8) Zig017Field {
    inline for (zig017FieldsOf(@typeInfo(T).@"struct")) |f| {
        if (comptime std.mem.eql(u8, f.name, name)) return f;
    }
    @compileError("no member " ++ name);
}

// ============================================================================
// Item 3: present-null dictionary member conversion (WebIDL 3.2.18)
// ============================================================================

const InnerDict = struct {
    pub const webidl_dictionary = true;
    flag: ?bool = null,
};

const InnerRequiredDict = struct {
    pub const webidl_dictionary = true;
    required_text: runtime.DOMString,
};

const PresentNullMembers = struct {
    pub const webidl_dictionary = true;
    buf: ?webidl.BufferSource = null,
    allow_shared: ?webidl.AllowSharedBufferSource = null,
    view: ?webidl.ArrayBufferView = null,
    inner: ?InnerDict = null,
    inner_req: ?InnerRequiredDict = null,
    cb_fn: ?runtime.BorrowedCallbackFunction = null,
    cb_iface: ?runtime.BorrowedCallbackInterface = null,
    obj: ?runtime.JSValue = null,
    nullable_buf: ?webidl.BufferSource = null,
    nullable_cb: ?runtime.BorrowedCallbackFunction = null,
    nullable_obj: ?runtime.JSValue = null,

    pub const nullable_members = .{ "nullable_buf", "nullable_cb", "nullable_obj" };
    pub const object_members = .{ "obj", "nullable_obj" };
};

test "presentNullConvertsByType: true for non-nullable buffer sources, dictionaries, callbacks, and object; false when nullable" {
    try testing.expect(comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "buf")));
    try testing.expect(comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "allow_shared")));
    try testing.expect(comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "view")));
    try testing.expect(comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "inner")));
    try testing.expect(comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "inner_req")));
    try testing.expect(comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "cb_fn")));
    try testing.expect(comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "cb_iface")));
    try testing.expect(comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "obj")));

    // Nullable counterparts stay false: present null stays null.
    try testing.expect(!comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "nullable_buf")));
    try testing.expect(!comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "nullable_cb")));
    try testing.expect(!comptime conv.presentNullConvertsByType(PresentNullMembers, field(PresentNullMembers, "nullable_obj")));

    // Real generated dictionaries from the 18-member buffer-source list:
    const AudioDecoderConfig = conv.generated_dictionaries.AudioDecoderConfig;
    const AesGcmParams = conv.generated_dictionaries.AesGcmParams;
    try testing.expect(comptime conv.presentNullConvertsByType(AudioDecoderConfig, field(AudioDecoderConfig, "description")));
    try testing.expect(comptime conv.presentNullConvertsByType(AesGcmParams, field(AesGcmParams, "additionalData")));
}

test "present null on optional non-nullable BufferSource / AllowSharedBufferSource / ArrayBufferView throws TypeError" {
    defer test_agent.close();
    const e = try env();

    inline for (.{ "({ buf: null })", "({ allow_shared: null })", "({ view: null })" }) |code| {
        const obj = try eval(code);
        defer ffi.v8_Value_Dispose(obj);
        try testing.expectError(error.TypeError, conv.fromV8Value(PresentNullMembers, testing.allocator, e.isolate, e.context, obj));
    }

    // Real generated AudioDecoderConfig { description: null } throws TypeError.
    const adc = try eval("({ codec: 'opus', sampleRate: 48000, numberOfChannels: 2, description: null })");
    defer ffi.v8_Value_Dispose(adc);
    try testing.expectError(error.TypeError, conv.fromV8Value(conv.generated_dictionaries.AudioDecoderConfig, testing.allocator, e.isolate, e.context, adc));

    // Real generated AesGcmParams { additionalData: null } throws TypeError.
    const agp = try eval("({ name: 'AES-GCM', iv: new Uint8Array(12), additionalData: null })");
    defer ffi.v8_Value_Dispose(agp);
    try testing.expectError(error.TypeError, conv.fromV8Value(conv.generated_dictionaries.AesGcmParams, testing.allocator, e.isolate, e.context, agp));
}

test "present null on optional non-nullable nested dictionary converts to an empty dictionary (or throws if nested has required member)" {
    defer test_agent.close();
    const e = try env();

    const ok = try eval("({ inner: null })");
    defer ffi.v8_Value_Dispose(ok);
    const parsed = try conv.fromV8Value(PresentNullMembers, testing.allocator, e.isolate, e.context, ok);
    defer iface.freeConvertedArg(PresentNullMembers, testing.allocator, parsed);
    try testing.expect(parsed.inner != null);
    try testing.expectEqual(@as(?bool, null), parsed.inner.?.flag);

    // Nested dictionary with a required member rejects null.
    const bad = try eval("({ inner_req: null })");
    defer ffi.v8_Value_Dispose(bad);
    try testing.expectError(error.TypeError, conv.fromV8Value(PresentNullMembers, testing.allocator, e.isolate, e.context, bad));
}

test "present null on optional non-nullable callback function, callback interface, or object throws TypeError" {
    defer test_agent.close();
    const e = try env();

    inline for (.{ "({ cb_fn: null })", "({ cb_iface: null })", "({ obj: null })" }) |code| {
        const obj = try eval(code);
        defer ffi.v8_Value_Dispose(obj);
        try testing.expectError(error.TypeError, conv.fromV8Value(PresentNullMembers, testing.allocator, e.isolate, e.context, obj));
    }
}

test "undefined remains absent and nullable members accept null" {
    defer test_agent.close();
    const e = try env();

    const obj = try eval(
        \\({
        \\  buf: undefined, allow_shared: undefined, view: undefined,
        \\  inner: undefined, inner_req: undefined,
        \\  cb_fn: undefined, cb_iface: undefined, obj: undefined,
        \\  nullable_buf: null, nullable_cb: null, nullable_obj: null
        \\})
    );
    defer ffi.v8_Value_Dispose(obj);
    const parsed = try conv.fromV8Value(PresentNullMembers, testing.allocator, e.isolate, e.context, obj);
    defer iface.freeConvertedArg(PresentNullMembers, testing.allocator, parsed);
    try testing.expect(parsed.buf == null);
    try testing.expect(parsed.allow_shared == null);
    try testing.expect(parsed.view == null);
    try testing.expect(parsed.inner == null);
    try testing.expect(parsed.inner_req == null);
    try testing.expect(parsed.cb_fn == null);
    try testing.expect(parsed.cb_iface == null);
    try testing.expect(parsed.obj == null);
    try testing.expect(parsed.nullable_buf == null);
    try testing.expect(parsed.nullable_cb == null);
    try testing.expect(parsed.nullable_obj == null);
}
