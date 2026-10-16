//! `conversions.memberValueIsOwned` - is the Global toV8Value makes for a
//! value it puts INTO an object or array it is building (a dictionary member,
//! a sequence element, a record value) made for this conversion, so that the
//! converter releases it once CreateDataProperty has copied the value in?
//!
//! The dictionary member branch of toV8Value and toV8Sequence asked the TYPE
//! (`dictionaryMemberValueIsOwned`), which has no union, webidl.Opt or `any`
//! arm and so keeps every value of those: a string or dictionary made for a
//! union member, for a sequence<union> element inside a dictionary, or for an
//! Opt(?DOMString) member kept a Global forever. Sanitizer.get() (Codex row
//! 41, Q21) leaked 5,687 of them on sanitizer-config.html.
//!
//! The answer is per VALUE (docs/lessons/architecture-a-jsvalue-s-type-
//! cannot-say-whether-its-conversion-is-fresh.md): a union by its active
//! member, an Opt by whether it was passed and then its inner value, an
//! optional by null (a fresh Null) or its child, a runtime.JSValue by its arm.
//! It is an ALLOWLIST (retention_predicate_test.zig says why): a value it does
//! not name answers false - keep the handle, keep the leak - and a test below
//! pins that default.
//!
//! The second half converts dictionaries of each shape thousands of times and
//! reads V8's own live count of global handle bytes (flat once fixed).
//!
//! Shares tests/v8's process: the conversions run on a thread of their own,
//! with an isolate of their own, so no entered isolate is inherited or left.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;

const owned = v8.conversions.memberValueIsOwned;

// Shapes as codegen emits them (SanitizerConfig, AlgorithmIdentifier).

/// (DOMString or object): `object` is a runtime.JSValue.
const StringOrObject = union(enum) {
    domstring: runtime.DOMString,
    object: runtime.JSValue,
};

/// A nullable member whose presence matters: webidl.Opt(?DOMString).
const Namespaced = struct {
    name: runtime.DOMString,
    namespace: webidl.Opt(?runtime.DOMString) = .notPassed(),
};

/// (DOMString or Namespaced), as SanitizerElementWithAttributes.
const Element = union(enum) {
    domstring: runtime.DOMString,
    namespaced: Namespaced,
};

const Inner = struct {
    either: ?StringOrObject = null,
    elements: ?[]const Element = null,
    namespace: webidl.Opt(?runtime.DOMString) = .notPassed(),
};

const Config = struct {
    either: ?StringOrObject = null,
    elements: ?[]const Element = null,
    namespace: webidl.Opt(?runtime.DOMString) = .notPassed(),
    detail: ?runtime.JSValue = null,
    nested: ?Inner = null,
};

fn str(s: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(s);
}

// ---------------------------------------------------------------------------
// The predicate
// ---------------------------------------------------------------------------

test "a union member is owned as its active member is" {
    var slot: u64 align(8) = 0;
    try testing.expect(owned(StringOrObject, .{ .domstring = str("a") }));
    try testing.expect(owned(Element, .{ .namespaced = .{ .name = str("b") } }));
    // An object member's handle is the impl's: kept.
    try testing.expect(!owned(StringOrObject, .{ .object = .{ .handle = .{ .ptr = @ptrCast(&slot) } } }));
    // A nullable union: null is a fresh Null, a member as above.
    try testing.expect(owned(?StringOrObject, null));
    try testing.expect(owned(?StringOrObject, .{ .domstring = str("c") }));
    try testing.expect(!owned(?StringOrObject, .{ .object = .{ .instance = @ptrCast(&slot) } }));
}

test "an Opt member is owned when not passed (a fresh undefined) or as its inner value" {
    const Namespace = webidl.Opt(?runtime.DOMString);
    try testing.expect(owned(Namespace, .notPassed()));
    try testing.expect(owned(Namespace, .passed(null)));
    try testing.expect(owned(Namespace, .passed(str("http://www.w3.org/1999/xhtml"))));
    // Its inner value decides: an Opt of an instance pointer stays kept.
    var slot: u64 align(8) = 0;
    const Registry = webidl.Opt(?*runtime.Instance);
    try testing.expect(owned(Registry, .notPassed()));
    try testing.expect(owned(Registry, .passed(null)));
    try testing.expect(!owned(Registry, .passed(@ptrCast(&slot))));
}

test "an any member is owned as its arm is" {
    var slot: u64 align(8) = 0;
    try testing.expect(owned(runtime.JSValue, runtime.JSValue.fromStringRef("x")));
    try testing.expect(owned(?runtime.JSValue, .{ .number = 2 }));
    try testing.expect(owned(?runtime.JSValue, null));
    try testing.expect(!owned(runtime.JSValue, .{ .handle = .{ .ptr = @ptrCast(&slot) } }));
    try testing.expect(!owned(?runtime.JSValue, .{ .instance = @ptrCast(&slot) }));
}

test "a runtime.JSValue is never read as a union of its arms" {
    // toV8Value converts a JSValue by its own branch, not the generic union
    // one: `.handle` is the impl's handle. Read as a union, its EngineHandle
    // arm looked like a dictionary (a plain struct) and answered "owned" -
    // so toV8Sequence released the impl's handle of a sequence<any> element.
    var slot: u64 align(8) = 0;
    const handle: runtime.JSValue = .{ .handle = .{ .ptr = @ptrCast(&slot) } };
    try testing.expect(!v8.conversions.unionValueIsOwned(runtime.JSValue, handle));
    try testing.expect(!owned(runtime.JSValue, handle));
}

test "the default is kept: values the allowlist does not name answer false" {
    var slot: u64 align(8) = 0;
    const instance: *runtime.Instance = @ptrCast(&slot);
    // A platform object's wrapper is the wrapper cache's.
    try testing.expect(!owned(*runtime.Instance, instance));
    try testing.expect(!owned(?*runtime.Instance, instance));
    // An opaque pointer converts to a wrapper (the union branch) or nothing.
    try testing.expect(!owned(*anyopaque, @ptrCast(&slot)));
    // A union whose active member is not named.
    const Opaque = union(enum) { opaque_member: *anyopaque, text: runtime.DOMString };
    try testing.expect(!owned(Opaque, .{ .opaque_member = @ptrCast(&slot) }));
    // An untagged union cannot say which member is active.
    const Untagged = union { a: f64, b: bool };
    try testing.expect(!owned(Untagged, .{ .a = 1 }));
}

// ---------------------------------------------------------------------------
// The conversions: V8's live count of global handle bytes
// ---------------------------------------------------------------------------

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,

    fn eval(self: Env, code: []const u8) !*ffi.Value {
        const text = ffi.v8_String_NewFromUtf8(self.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
        defer ffi.v8_String_Dispose(text);
        const script = ffi.v8_Script_Compile(self.context, text) orelse return error.CompileFailed;
        defer ffi.v8_Script_Dispose(script);
        return ffi.v8_Script_Run(self.context, script) orelse error.RunFailed;
    }

    fn evalInt(self: Env, code: []const u8) !i32 {
        const value = try self.eval(code);
        defer ffi.v8_Value_Dispose(value);
        return ffi.v8_Value_Int32Value(value, self.context);
    }

    /// Converts `value` once and binds it to `result` in the global scope.
    fn bind(self: Env, comptime T: type, value: T) !void {
        const object = try v8.conversions.toV8Value(T, self.isolate, self.context, value);
        defer ffi.v8_Value_Dispose(object);
        const global = ffi.v8_Context_Global(self.context) orelse return error.NoGlobal;
        defer ffi.v8_Object_Dispose(global);
        const key = ffi.v8_String_NewFromUtf8(self.isolate, "result", 6) orelse return error.StringFailed;
        defer ffi.v8_String_Dispose(key);
        if (!ffi.v8_Object_Set(global, self.context, @ptrCast(key), object)) return error.SetFailed;
    }

    /// The global handle bytes `rounds` conversions of `value` leave, each
    /// result released as the binding releases a dictionary it returned,
    /// measured after a first round has made what later ones reuse.
    fn bytesLeftBy(self: Env, comptime T: type, value: T, rounds: usize) !usize {
        for (0..64) |_| {
            const object = try v8.conversions.toV8Value(T, self.isolate, self.context, value);
            ffi.v8_Value_Dispose(object);
        }
        const before = ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate);
        for (0..rounds) |_| {
            const object = try v8.conversions.toV8Value(T, self.isolate, self.context, value);
            ffi.v8_Value_Dispose(object);
        }
        return ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate) -| before;
    }
};

/// Runs `body` on a thread of its own with a fresh isolate and context.
fn withEnv(comptime body: fn (Env) anyerror!void) !void {
    const Thread = struct {
        fn run(result: *anyerror!void) void {
            result.* = runBody();
        }

        fn runBody() anyerror!void {
            try engine.initializeEngine(.{});
            const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
            defer ffi.v8_Isolate_Dispose(isolate);
            ffi.v8_Isolate_Enter(isolate);
            defer ffi.v8_Isolate_Exit(isolate);
            const scope = ffi.v8_HandleScope_New(isolate) orelse return error.HandleScopeFailed;
            defer ffi.v8_HandleScope_Dispose(scope);
            const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
            defer ffi.v8_Context_Dispose(context);
            ffi.v8_Context_Enter(context);
            defer ffi.v8_Context_Exit(context);
            try body(.{ .isolate = isolate, .context = context });
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Thread.run, .{&result});
    thread.join();
    try result;
}

// 4,000 conversions that each kept even one Global (32 B of V8's global
// handle space) would leave 125 KiB; a flat loop leaves none. The margin is
// for the handle table's own bookkeeping, never a handle per conversion.
const conversion_rounds = 4000;
const margin = 16 * 1024;

fn expectFlat(env: Env, comptime T: type, value: T, comptime what: []const u8) !void {
    const left = try env.bytesLeftBy(T, value, conversion_rounds);
    if (left >= margin) {
        std.debug.print("{s}: {d} B of global handles left by {d} conversions\n", .{ what, left, conversion_rounds });
        return error.HandlesKept;
    }
}

test "a (DOMString or object) union member's string is released" {
    try withEnv(struct {
        fn body(env: Env) !void {
            try expectFlat(env, Config, .{ .either = .{ .domstring = str("text/html") } }, "union member");
        }
    }.body);
}

test "a sequence<union> member's elements are released" {
    try withEnv(struct {
        fn body(env: Env) !void {
            const elements = [_]Element{
                .{ .domstring = str("div") },
                .{ .namespaced = .{ .name = str("span"), .namespace = .passed(str("http://www.w3.org/1999/xhtml")) } },
                .{ .namespaced = .{ .name = str("p"), .namespace = .passed(null) } },
            };
            try expectFlat(env, Config, .{ .elements = &elements }, "sequence<union> member");
        }
    }.body);
}

test "an Opt(?DOMString) member is released, passed or null" {
    try withEnv(struct {
        fn body(env: Env) !void {
            try expectFlat(env, Config, .{ .namespace = .passed(str("http://www.w3.org/2000/svg")) }, "Opt string");
            try expectFlat(env, Config, .{ .namespace = .passed(null) }, "Opt null");
            try expectFlat(env, Config, .{}, "Opt not passed");
        }
    }.body);
}

test "an any member's string is released" {
    try withEnv(struct {
        fn body(env: Env) !void {
            try expectFlat(env, Config, .{ .detail = runtime.JSValue.fromStringRef("detail") }, "any member");
        }
    }.body);
}

test "a nested dictionary's union, sequence and Opt members are released" {
    try withEnv(struct {
        fn body(env: Env) !void {
            const elements = [_]Element{
                .{ .domstring = str("b") },
                .{ .namespaced = .{ .name = str("i"), .namespace = .passed(str("http://www.w3.org/1999/xhtml")) } },
            };
            try expectFlat(env, Config, .{ .nested = .{
                .either = .{ .domstring = str("x") },
                .elements = &elements,
                .namespace = .passed(null),
            } }, "nested dictionary");
        }
    }.body);
}

test "an object member's handle is kept: the impl's, alive after the conversions" {
    try withEnv(struct {
        fn body(env: Env) !void {
            const object = try env.eval("({ tag: 7 })");
            defer ffi.v8_Value_Dispose(object);
            const value: Config = .{ .either = .{ .object = .{ .handle = .{ .ptr = @ptrCast(object) } } } };
            _ = try env.bytesLeftBy(Config, value, 64);
            try env.bind(Config, value);
            try testing.expectEqual(@as(i32, 7), try env.evalInt("result.either.tag"));
        }
    }.body);
}

test "an Opt member is a property only when passed (WebIDL 3.2.18: if it exists)" {
    try withEnv(struct {
        fn body(env: Env) !void {
            try env.bind(Config, .{});
            try testing.expectEqual(@as(i32, 0), try env.evalInt("'namespace' in result ? 1 : 0"));
            try env.bind(Config, .{ .namespace = .passed(null) });
            try testing.expectEqual(@as(i32, 1), try env.evalInt("result.namespace === null ? 1 : 0"));
            try env.bind(Config, .{ .namespace = .passed(str("ns")) });
            try testing.expectEqual(@as(i32, 1), try env.evalInt("result.namespace === 'ns' ? 1 : 0"));
            const elements = [_]Element{.{ .namespaced = .{ .name = str("a") } }};
            try env.bind(Config, .{ .elements = &elements });
            try testing.expectEqual(@as(i32, 1), try env.evalInt("result.elements[0].name === 'a' && !('namespace' in result.elements[0]) ? 1 : 0"));
        }
    }.body);
}
