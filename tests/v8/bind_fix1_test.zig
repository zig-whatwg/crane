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

// ============================================================================
// Item 2: Union `bigint` arm — WebIDL 3.2.25 steps 16 & 19 + zero handle leaks
// ============================================================================

const BigintOrDouble = union(enum) {
    bigint: runtime.JSValue,
    double: f64,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "bigint", .kind = .bigint },
        .{ .field = "double", .kind = .numeric },
    };
};

/// A union with `bigint` and NO numeric arm (WebIDL 3.2.25 step 19).
const BigintOrBoolean = union(enum) {
    bigint: runtime.JSValue,
    boolean: bool,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "bigint", .kind = .bigint },
        .{ .field = "boolean", .kind = .boolean },
    };
};

fn convertArgCatching(comptime T: type, value: *ffi.Value) struct { result: anyerror!T, thrown: ?*ffi.Value } {
    const e = test_env.?;
    const Body = struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        value: *ffi.Value,
        result: anyerror!T = error.NotRun,
        fn call(data: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = iface.convertArgReleasing(T, testing.allocator, self.isolate, self.context, self.value);
        }
    };
    var body = Body{ .isolate = e.isolate, .context = e.context, .value = value };
    var thrown: ?*ffi.Value = null;
    _ = ffi.v8_RunCatching(e.isolate, Body.call, &body, &thrown);
    return .{ .result = body.result, .thrown = thrown };
}

fn handleToString(e: Env, js: runtime.JSValue) ![]u8 {
    try testing.expect(js == .handle);
    const val: *ffi.Value = @ptrCast(@alignCast(js.handle.ptr));
    const str = ffi.v8_Value_ToString(val, e.context) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(str);
    const len: usize = @intCast(ffi.v8_String_Utf8Length(str));
    const buf = try testing.allocator.alloc(u8, len);
    _ = ffi.v8_String_WriteUtf8(str, buf.ptr, @intCast(len));
    return buf;
}

test "WebIDL 3.2.25 step 16: ToNumeric runs valueOf once for BigInt and Number results, and propagates throws" {
    defer test_agent.close();
    const e = try env();

    // Object whose valueOf returns a BigInt -> bigint arm, valueOf runs once.
    {
        const obj = try eval("globalThis._calls = 0; ({ valueOf() { globalThis._calls++; return 7n; } })");
        const outcome = convertArgCatching(BigintOrDouble, obj);
        try testing.expect(outcome.thrown == null);
        const converted = try outcome.result;
        defer iface.freeArgument(BigintOrDouble, testing.allocator, converted);
        try testing.expect(converted == .bigint);
        const text = try handleToString(e, converted.bigint);
        defer testing.allocator.free(text);
        try testing.expectEqualStrings("7", text);
        const calls_val = try eval("globalThis._calls");
        defer ffi.v8_Value_Dispose(calls_val);
        try testing.expectEqual(@as(i32, 1), ffi.v8_Value_Int32Value(calls_val, e.context));
    }

    // Object whose valueOf returns a Number -> numeric arm, valueOf runs once.
    {
        const obj = try eval("globalThis._calls = 0; ({ valueOf() { globalThis._calls++; return 3.5; } })");
        const outcome = convertArgCatching(BigintOrDouble, obj);
        try testing.expect(outcome.thrown == null);
        const converted = try outcome.result;
        defer iface.freeArgument(BigintOrDouble, testing.allocator, converted);
        try testing.expect(converted == .double);
        try testing.expectEqual(@as(f64, 3.5), converted.double);
        const calls_val = try eval("globalThis._calls");
        defer ffi.v8_Value_Dispose(calls_val);
        try testing.expectEqual(@as(i32, 1), ffi.v8_Value_Int32Value(calls_val, e.context));
    }

    // Throwing valueOf propagates the pending exception.
    {
        const obj = try eval("({ valueOf() { throw new RangeError('boom'); } })");
        const outcome = convertArgCatching(BigintOrDouble, obj);
        try testing.expectError(error.ExceptionPending, outcome.result);
        const thrown = outcome.thrown orelse return error.ExpectedThrow;
        ffi.v8_Value_Dispose(thrown);
    }

    // Symbol throws TypeError from ToNumeric.
    {
        const sym = try eval("Symbol()");
        const outcome = convertArgCatching(BigintOrDouble, sym);
        try testing.expectError(error.ExceptionPending, outcome.result);
        const thrown = outcome.thrown orelse return error.ExpectedThrow;
        ffi.v8_Value_Dispose(thrown);
    }
}

test "WebIDL 3.2.25 step 19: union with bigint and no numeric arm converts via ToBigInt" {
    defer test_agent.close();
    const e = try env();

    // Step 12 (Boolean) runs before step 19.
    {
        const val = try eval("true");
        const outcome = convertArgCatching(BigintOrBoolean, val);
        try testing.expect(outcome.thrown == null);
        const converted = try outcome.result;
        defer iface.freeArgument(BigintOrBoolean, testing.allocator, converted);
        try testing.expect(converted == .boolean and converted.boolean == true);
    }

    // Step 14 (direct BigInt).
    {
        const val = try eval("9n");
        const outcome = convertArgCatching(BigintOrBoolean, val);
        try testing.expect(outcome.thrown == null);
        const converted = try outcome.result;
        defer iface.freeArgument(BigintOrBoolean, testing.allocator, converted);
        try testing.expect(converted == .bigint);
        const text = try handleToString(e, converted.bigint);
        defer testing.allocator.free(text);
        try testing.expectEqualStrings("9", text);
    }

    // Step 18 (boolean) runs BEFORE step 19 (bigint)!
    // So test a union with bigint and NO boolean/numeric/string arms: (bigint or object) -> string '42' reaches step 19.
    const BigintOrArrayBuffer = union(enum) {
        bigint: runtime.JSValue,
        array_buffer: runtime.JSValue,
        pub const arms = [_]webidl.UnionArm{
            .{ .field = "bigint", .kind = .bigint },
            .{ .field = "array_buffer", .kind = .array_buffer },
        };
    };

    // String '42' reaches step 19 -> ToBigInt('42') = 42n.
    {
        const val = try eval("'42'");
        const outcome = convertArgCatching(BigintOrArrayBuffer, val);
        try testing.expect(outcome.thrown == null);
        const converted = try outcome.result;
        defer iface.freeArgument(BigintOrArrayBuffer, testing.allocator, converted);
        try testing.expect(converted == .bigint);
        const text = try handleToString(e, converted.bigint);
        defer testing.allocator.free(text);
        try testing.expectEqualStrings("42", text);
    }

    // Object with valueOf returning BigInt reaches step 19 -> 123n.
    {
        const val = try eval("({ valueOf() { return 123n; } })");
        const outcome = convertArgCatching(BigintOrArrayBuffer, val);
        try testing.expect(outcome.thrown == null);
        const converted = try outcome.result;
        defer iface.freeArgument(BigintOrArrayBuffer, testing.allocator, converted);
        try testing.expect(converted == .bigint);
        const text = try handleToString(e, converted.bigint);
        defer testing.allocator.free(text);
        try testing.expectEqualStrings("123", text);
    }

    // Invalid string, number, and null throw in ToBigInt (ExceptionPending).
    inline for (.{ "'not-a-bigint'", "3.5", "null" }) |code| {
        const val = try eval(code);
        const outcome = convertArgCatching(BigintOrArrayBuffer, val);
        try testing.expectError(error.ExceptionPending, outcome.result);
        const thrown = outcome.thrown orelse return error.ExpectedThrow;
        ffi.v8_Value_Dispose(thrown);
    }
}

test "union bigint steps 14/16/19 leak zero V8 Global handles through convertArgReleasing + freeArgument" {
    defer test_agent.close();
    const e = try env();

    const BigintOrArrayBuffer = union(enum) {
        bigint: runtime.JSValue,
        array_buffer: runtime.JSValue,
        pub const arms = [_]webidl.UnionArm{
            .{ .field = "bigint", .kind = .bigint },
            .{ .field = "array_buffer", .kind = .array_buffer },
        };
    };

    // Warm up once before measuring.
    {
        const warm = try eval("5n");
        const out = convertArgCatching(BigintOrDouble, warm);
        iface.freeArgument(BigintOrDouble, testing.allocator, try out.result);
    }
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate);

    for (0..100) |_| {
        // Step 14: direct BigInt (input handle kept & released by freeArgument).
        {
            const v = try eval("5n");
            const r = try convertArgCatching(BigintOrDouble, v).result;
            iface.freeArgument(BigintOrDouble, testing.allocator, r);
        }
        // Step 16 BigInt: new handle created; input disposed immediately, BigInt disposed by freeArgument.
        {
            const v = try eval("({ valueOf() { return 7n; } })");
            const r = try convertArgCatching(BigintOrDouble, v).result;
            iface.freeArgument(BigintOrDouble, testing.allocator, r);
        }
        // Step 16 Number: numeric handle disposed internally; input disposed immediately.
        {
            const v = try eval("({ valueOf() { return 3.5; } })");
            const r = try convertArgCatching(BigintOrDouble, v).result;
            iface.freeArgument(BigintOrDouble, testing.allocator, r);
        }
        // Step 19 BigInt: new handle created; input disposed immediately, BigInt disposed by freeArgument.
        {
            const v = try eval("'999'");
            const r = try convertArgCatching(BigintOrArrayBuffer, v).result;
            iface.freeArgument(BigintOrArrayBuffer, testing.allocator, r);
        }
    }

    const after = ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate);
    try testing.expectEqual(before, after);
}

// ============================================================================
// Item 4: Namespace operations & attributes resolve types via type_registry
// ============================================================================

test "generated namespaces resolve types through type_registry (CSS and WebAssembly)" {
    const namespaces = v8.namespace_mod.generated_namespaces;
    // CSS.registerProperty takes dictionaries.PropertyDefinition (not runtime.JSValue).
    const reg_params = @typeInfo(@TypeOf(namespaces.CSS.call_registerProperty)).@"fn".param_types;
    try testing.expect(reg_params[1].? == conv.generated_dictionaries.PropertyDefinition);
    // CSS.px returns *runtime.Instance (CSSUnitValue, not runtime.JSValue).
    const px_ret = @typeInfo(@typeInfo(@TypeOf(namespaces.CSS.call_px)).@"fn".return_type.?).error_union.payload;
    try testing.expect(px_ret == *runtime.Instance);
    // CSS.get_highlights returns *runtime.Instance (HighlightRegistry).
    const hl_ret = @typeInfo(@typeInfo(@TypeOf(namespaces.CSS.get_highlights)).@"fn".return_type.?).error_union.payload;
    try testing.expect(hl_ret == *runtime.Instance);
    // WebAssembly.validate takes typedefs.AllowSharedBufferSource and Opt(WebAssemblyCompileOptions).
    const val_params = @typeInfo(@TypeOf(namespaces.WebAssembly.call_validate)).@"fn".param_types;
    try testing.expect(val_params[1].? == conv.generated_typedefs.AllowSharedBufferSource);
    try testing.expect(val_params[2].? == webidl.Opt(conv.generated_dictionaries.WebAssemblyCompileOptions));
    // WebAssembly.instantiate__1 takes *runtime.Instance (Module).
    const inst1_params = @typeInfo(@TypeOf(namespaces.WebAssembly.call_instantiate__1)).@"fn".param_types;
    try testing.expect(inst1_params[1].? == *runtime.Instance);
}
