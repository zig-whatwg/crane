//! WebIDL 3.2.25, converting a JavaScript value to a union, step by step,
//! from the union's arms table (lane bind1 batch B, B3): every "types
//! includes" is a question of codegen's `pub const arms` - the member types'
//! kinds - never of the Zig types' shapes or the fields' names.
//!
//! - step 5.1: a platform object goes to the first member interface it
//!   implements, in member order (a File to Blob); one implementing none goes
//!   on through the later steps - to `object`, else to the string type;
//! - step 9.1: a typed array goes to the member of its [[TypedArrayName]];
//!   another typed array goes on;
//! - step 10.1: a callable goes to the callback function member;
//! - step 11.2: an object with an @@iterator goes to the sequence member - a
//!   Set as well as an Array - and one without to the dictionary (11.4);
//! - step 11.5: an object goes to the record member;
//! - step 14: a BigInt goes to the bigint member. Before the arms tables a
//!   union's `bigint` member (MLNumber, CryptoKeyID) took nothing: a BigInt
//!   reached the numeric member's ToNumber, a TypeError;
//! - step 15: an object no step took goes to the string type, and what its
//!   toString throws propagates.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const conv = v8.conversions;

var test_isolate: ?*ffi.Isolate = null;
var test_context: ?*ffi.Context = null;
var test_realm: ?runtime.Context = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
    test_context = null;
    test_realm = null;
}

/// The test agent's realm, with every interface registered (`new File`,
/// `new AbortController`).
fn realm() !runtime.Context {
    const i = try test_agent.open(.{ .realm_allocator = std.heap.page_allocator });
    if (test_realm == null) {
        const context = test_agent.context.?;
        const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        v8.interface_bindings.registerAllInterfaces(i, context);
        test_isolate = i;
        test_context = context;
        test_realm = r;
    }
    return test_realm.?;
}

fn eval(code: []const u8) !*ffi.Value {
    _ = try realm();
    const context = test_context.?;
    const text = ffi.v8_String_NewFromUtf8(test_isolate.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

/// Convert `value` to `T` under a TryCatch: the conversion's error, if any,
/// and what script saw thrown (OWNED), if anything.
fn convertCatching(comptime T: type, value: *ffi.Value) struct { result: anyerror!T, thrown: ?*ffi.Value } {
    const Body = struct {
        value: *ffi.Value,
        result: anyerror!T = error.NotRun,
        fn call(data: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = conv.fromV8Value(T, testing.allocator, test_isolate.?, test_context.?, self.value);
        }
    };
    var body = Body{ .value = value };
    var thrown: ?*ffi.Value = null;
    _ = ffi.v8_RunCatching(test_isolate.?, Body.call, &body, &thrown);
    return .{ .result = body.result, .thrown = thrown };
}

/// `code`'s value converted to `T`, nothing thrown. The value's handle is
/// released here: a member that refers to it (an `object`, a typed array,
/// a bigint, a callback function) is read before `check` returns.
fn expectConverted(comptime T: type, code: []const u8, check: fn (T) anyerror!void) !void {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    const outcome = convertCatching(T, value);
    if (outcome.thrown) |thrown| {
        ffi.v8_Value_Dispose(thrown);
        return error.ConversionThrew;
    }
    const result = try outcome.result;
    defer freeOwned(T, result);
    try check(result);
}

/// What a converted test union owns: a string member's copy, a sequence's
/// elements and slice, a record's entries.
fn freeOwned(comptime T: type, result: T) void {
    switch (result) {
        inline else => |payload| {
            const P = @TypeOf(payload);
            if (comptime P == runtime.DOMString) {
                var copy = payload;
                copy.deinit(testing.allocator);
            } else if (comptime P == []const runtime.DOMString) {
                for (payload) |item| {
                    var copy = item;
                    copy.deinit(testing.allocator);
                }
                testing.allocator.free(payload);
            } else if (comptime P == []const RecordEntry) {
                for (payload) |entry| {
                    var key = entry.key;
                    key.deinit(testing.allocator);
                    var item = entry.value;
                    item.deinit(testing.allocator);
                }
                testing.allocator.free(payload);
            }
        },
    }
}

/// (Blob or AbortSignal or DOMString), as codegen describes one.
const BlobSignalOrString = union(enum) {
    blob: *runtime.Instance,
    abort_signal: *runtime.Instance,
    domstring: runtime.DOMString,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "blob", .kind = .{ .interface = "Blob" } },
        .{ .field = "abort_signal", .kind = .{ .interface = "AbortSignal" } },
        .{ .field = "domstring", .kind = .string },
    };
};

test "step 5.1: a platform object is the first member interface it implements - a File is a Blob" {
    defer test_agent.close();
    try expectConverted(BlobSignalOrString, "new File([], 'f')", struct {
        fn check(result: BlobSignalOrString) !void {
            try testing.expect(result == .blob);
        }
    }.check);
    try expectConverted(BlobSignalOrString, "new AbortController().signal", struct {
        fn check(result: BlobSignalOrString) !void {
            try testing.expect(result == .abort_signal);
        }
    }.check);
}

test "step 5.1, then 15: a platform object implementing no member interface is the string type" {
    defer test_agent.close();
    try expectConverted(BlobSignalOrString, "new Headers()", struct {
        fn check(result: BlobSignalOrString) !void {
            try testing.expect(result == .domstring);
            try testing.expectEqualStrings("[object Headers]", result.domstring.asSlice());
        }
    }.check);
}

/// (AbortSignal or object).
const SignalOrObject = union(enum) {
    abort_signal: *runtime.Instance,
    object: runtime.JSValue,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "abort_signal", .kind = .{ .interface = "AbortSignal" } },
        .{ .field = "object", .kind = .object },
    };
};

test "step 5.2: a platform object implementing no member interface is a reference, given object" {
    defer test_agent.close();
    try expectConverted(SignalOrObject, "new Blob()", struct {
        fn check(result: SignalOrObject) !void {
            try testing.expect(result == .object and result.object == .handle);
        }
    }.check);
}

/// (Float32Array or DOMString).
const FloatsOrString = union(enum) {
    float32array: runtime.JSValue,
    domstring: runtime.DOMString,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "float32array", .kind = .{ .typed_array = "Float32Array" } },
        .{ .field = "domstring", .kind = .string },
    };
};

test "step 9.1: a typed array is the member of its name; another is converted by a later step" {
    defer test_agent.close();
    try expectConverted(FloatsOrString, "new Float32Array(2)", struct {
        fn check(result: FloatsOrString) !void {
            try testing.expect(result == .float32array and result.float32array == .handle);
        }
    }.check);
    // A Uint8Array: no member of its name and no object (9.2), no callback
    // (10), none of step 11's members: step 15's ToString.
    try expectConverted(FloatsOrString, "new Uint8Array([1, 2])", struct {
        fn check(result: FloatsOrString) !void {
            try testing.expect(result == .domstring);
            try testing.expectEqualStrings("1,2", result.domstring.asSlice());
        }
    }.check);
}

/// (Function or DOMString), a callback function member.
const FunctionOrString = union(enum) {
    function: runtime.BorrowedCallbackFunction,
    domstring: runtime.DOMString,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "function", .kind = .callback_function },
        .{ .field = "domstring", .kind = .string },
    };
};

test "step 10.1: a callable is the callback function member" {
    defer test_agent.close();
    try expectConverted(FunctionOrString, "(function f() {})", struct {
        fn check(result: FunctionOrString) !void {
            try testing.expect(result == .function);
        }
    }.check);
}

/// A dictionary as codegen emits one.
const Options = struct {
    pub const webidl_dictionary = true;
    flag: ?bool = null,
};

/// (sequence<DOMString> or Options).
const SequenceOrOptions = union(enum) {
    domstring_sequence: []const runtime.DOMString,
    options: Options,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring_sequence", .kind = .{ .sequence = null } },
        .{ .field = "options", .kind = .dictionary },
    };
};

test "step 11.2: an object with an @@iterator is the sequence member - a Set too" {
    defer test_agent.close();
    try expectConverted(SequenceOrOptions, "new Set(['a', 'b'])", struct {
        fn check(result: SequenceOrOptions) !void {
            try testing.expect(result == .domstring_sequence);
            try testing.expectEqual(@as(usize, 2), result.domstring_sequence.len);
            try testing.expectEqualStrings("b", result.domstring_sequence[1].asSlice());
        }
    }.check);
}

test "step 11.4: an object without an @@iterator is the dictionary member" {
    defer test_agent.close();
    try expectConverted(SequenceOrOptions, "({ flag: true })", struct {
        fn check(result: SequenceOrOptions) !void {
            try testing.expect(result == .options and result.options.flag.? == true);
        }
    }.check);
}

const RecordEntry = struct {
    pub const webidl_record_entry = true;
    key: runtime.DOMString,
    value: runtime.DOMString,
};

/// (record<DOMString, DOMString> or long).
const RecordOrLong = union(enum) {
    domstring_domstring_record: []const RecordEntry,
    long: i32,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring_domstring_record", .kind = .record },
        .{ .field = "long", .kind = .numeric },
    };
};

test "step 11.5: an object is the record member; a Number the numeric one" {
    defer test_agent.close();
    try expectConverted(RecordOrLong, "({ a: 'x' })", struct {
        fn check(result: RecordOrLong) !void {
            try testing.expect(result == .domstring_domstring_record);
            try testing.expectEqual(@as(usize, 1), result.domstring_domstring_record.len);
            try testing.expectEqualStrings("a", result.domstring_domstring_record[0].key.asSlice());
        }
    }.check);
    try expectConverted(RecordOrLong, "7", struct {
        fn check(result: RecordOrLong) !void {
            try testing.expect(result == .long and result.long == 7);
        }
    }.check);
}

/// (bigint or unrestricted double): MLNumber's shape.
const BigintOrDouble = union(enum) {
    bigint: runtime.JSValue,
    double: f64,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "bigint", .kind = .bigint },
        .{ .field = "double", .kind = .numeric },
    };
};

test "step 14: a BigInt is the bigint member; a Number the numeric one" {
    defer test_agent.close();
    try expectConverted(BigintOrDouble, "5n", struct {
        fn check(result: BigintOrDouble) !void {
            try testing.expect(result == .bigint and result.bigint == .handle);
        }
    }.check);
    try expectConverted(BigintOrDouble, "2.5", struct {
        fn check(result: BigintOrDouble) !void {
            try testing.expect(result == .double and result.double == 2.5);
        }
    }.check);
    // Step 16 for a String: ToNumeric("3") is the Number 3.
    try expectConverted(BigintOrDouble, "'3'", struct {
        fn check(result: BigintOrDouble) !void {
            try testing.expect(result == .double and result.double == 3);
        }
    }.check);
}

/// Which later steps of lane bind1 have landed: a red test pinning what one
/// must achieve passes while it is red, and fails when it turns green
/// unannounced (lesson testing-a-red-test-for-an-unlanded-step-asserts-that-
/// it-is-still-red.md; tests/html/refcount_probe.zig's `knownRed`).
const landed = struct {
    /// Step 16/19: a union's bigint member can hold a newly allocated BigInt
    /// handle from ToNumeric / ToBigInt (released by releaseAnyArgument while
    /// conversionLeavesInputHandle disposes the input handle).
    const bigint_member_copied_b1 = true;
};

/// Assert `holds`, or - while `step_landed` is false - that it does not.
fn knownRed(comptime step_landed: bool, holds: bool, what: []const u8) !void {
    if (step_landed) {
        if (!holds) {
            std.debug.print("REGRESSION (its step has landed): {s}\n", .{what});
            return error.PropertyLost;
        }
        return;
    }
    if (holds) {
        std.debug.print("UNEXPECTEDLY GREEN (flip its `landed` flag in tests/v8/union_conversion_steps_test.zig): {s}\n", .{what});
        return error.RedTestTurnedGreen;
    }
    std.debug.print("known red until its step: {s}\n", .{what});
}

test "step 16: an object whose valueOf answers a BigInt is the bigint member" {
    defer test_agent.close();
    // WebIDL 3.2.25 step 16: ToNumeric(V) is 7n, so V converts to bigint.
    const value = try eval("({ valueOf() { return 7n } })");
    defer ffi.v8_Value_Dispose(value);
    const outcome = convertCatching(BigintOrDouble, value);
    if (outcome.thrown) |thrown| ffi.v8_Value_Dispose(thrown);
    const holds = if (outcome.result) |result| blk: {
        defer if (result == .bigint and result.bigint == .handle and result.bigint.handle.ptr != @as(*anyopaque, @ptrCast(value))) {
            ffi.v8_Value_Dispose(@ptrCast(@alignCast(result.bigint.handle.ptr)));
        };
        break :blk result == .bigint and result.bigint == .handle;
    } else |_| false;
    try knownRed(landed.bigint_member_copied_b1, holds, "step 16: ToNumeric's BigInt is the bigint member");
}

/// (sequence<DOMString> or DOMString): an object without an @@iterator
/// reaches step 15.
const SequenceOrString = union(enum) {
    domstring_sequence: []const runtime.DOMString,
    domstring: runtime.DOMString,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring_sequence", .kind = .{ .sequence = null } },
        .{ .field = "domstring", .kind = .string },
    };
};

test "step 15: an object no step took is the string type, and its toString's throw propagates" {
    defer test_agent.close();
    try expectConverted(SequenceOrString, "({ toString() { return 'text' } })", struct {
        fn check(result: SequenceOrString) !void {
            try testing.expect(result == .domstring);
            try testing.expectEqualStrings("text", result.domstring.asSlice());
        }
    }.check);
    const value = try eval("({ toString() { throw new RangeError('boom') } })");
    defer ffi.v8_Value_Dispose(value);
    const outcome = convertCatching(SequenceOrString, value);
    try testing.expectError(error.ExceptionPending, outcome.result);
    const thrown = outcome.thrown orelse return error.NothingThrown;
    ffi.v8_Value_Dispose(thrown);
}

test "every generated union typedef has an arms table naming each field once, every interface arm a generated interface" {
    defer test_agent.close();
    @setEvalBranchQuota(10_000_000);
    const typedefs = conv.generated_typedefs;
    var unions: usize = 0;
    inline for (comptime std.meta.declarations(typedefs)) |decl_name| {
        const T = @field(typedefs, decl_name);
        // Every union but the ones a typedef names that are no generated
        // union: runtime.JSValue (`any`), runtime.DOMString (a string type)
        // and the buffer sources webidl.buffer_sources defines.
        if (@TypeOf(T) == type and @typeInfo(T) == .@"union" and
            T != runtime.JSValue and T != runtime.DOMString and
            T != webidl.buffer_sources.BufferSource and T != webidl.buffer_sources.ArrayBufferView and T != webidl.buffer_sources.AllowSharedBufferSource)
        {
            const arms = comptime conv.unionArmsOf(T);
            const fields = comptime std.meta.fieldNames(T);
            try testing.expectEqual(fields.len, arms.len);
            inline for (fields, 0..) |field, i| {
                try testing.expectEqualStrings(field, arms[i].field);
                switch (comptime arms[i].kind) {
                    .interface => |name| {
                        try testing.expect(@FieldType(T, field) == *runtime.Instance);
                        try testing.expectEqualStrings(name, conv.interfaceNamed(name).Meta.name);
                    },
                    else => {},
                }
            }
            unions += 1;
        }
    }
    // BodyInit, RequestInfo, MessageEventSource, BlobPart and the rest.
    try testing.expect(unions > 80);
}
