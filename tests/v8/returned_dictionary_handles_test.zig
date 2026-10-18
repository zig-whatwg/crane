//! A JavaScript value an operation hands over in the dictionary it RETURNS
//! is the binding's: released once the dictionary's object holds it
//! (`conversions.releaseReturnedDictionaryHandles`, which interface.zig's
//! convertReturnValue runs after toV8Value).
//!
//! The rule is the one a runtime.JSValue result already has: an impl hands
//! its value over with engine.Owned.take(), and the binding releases it.
//! toV8Value cannot see that - a `.handle` member of a dictionary converted
//! anywhere else is the impl's own (`memberValueIsOwned` keeps it) - so the
//! object was released and its members were not. NavigationResult's
//! committed and finished promises (Navigation.derivedResult's retainValue,
//! earlyErrorWith's and settledResult's new promises) leaked two Globals per
//! navigation API call: 4 under leaks --atExit over
//! html/semantics/embedded-content/ and 1,154 of navigation-api/'s 1,170
//! with main d5762d302d's runner (lane leaks5).
//!
//! The values are made as the impl makes them - a Global per promise,
//! handed over as `.handle` - and converted as the binding converts a
//! returned dictionary: toV8Value, the object released, then the members.
//! V8's own live count of global handle bytes is read over many calls.
//!
//! Shares tests/v8's process: each body runs on a thread of its own, with
//! an isolate of its own, so no entered isolate is inherited or left.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dictionaries = @import("dictionaries");
const v8 = @import("v8");
const ffi = v8.ffi;

const NavigationResult = dictionaries.NavigationResult;
const ComputedEffectTiming = dictionaries.ComputedEffectTiming;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,

    /// Script's value of `code`, OWNED: a Global, as engine.retainValue
    /// makes one for the impl.
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

    /// A promise handed over as the impl hands one over.
    fn promise(self: Env) !runtime.JSValue {
        return .{ .handle = .{ .ptr = @ptrCast(try self.eval("Promise.resolve(1)")) } };
    }

    /// convertReturnValue's dictionary branch: the object, released as the
    /// binding releases an owned result, and - with `release_members` -
    /// the members the impl handed over.
    fn returnDictionary(self: Env, comptime T: type, value: T, release_members: bool) !void {
        defer if (release_members) v8.conversions.releaseReturnedDictionaryHandles(T, value);
        const object = try v8.conversions.toV8Value(T, self.isolate, self.context, value);
        ffi.v8_Global_Dispose(object);
    }

    fn bytes(self: Env) usize {
        return ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate);
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

// 2,000 calls that each kept even one Global (32 B of V8's global handle
// space) would leave 62.5 KiB; a flat loop leaves none. The margin is for
// the handle table's own bookkeeping, never a handle per call.
const rounds = 2000;
const margin = 16 * 1024;

/// The global handle bytes `rounds` returned NavigationResults leave, after
/// a first round has made what later ones reuse.
fn bytesLeftByNavigationResults(env: Env, release_members: bool) !usize {
    for (0..64) |_| try env.returnDictionary(NavigationResult, .{ .committed = try env.promise(), .finished = try env.promise() }, true);
    const before = env.bytes();
    for (0..rounds) |_| try env.returnDictionary(NavigationResult, .{ .committed = try env.promise(), .finished = try env.promise() }, release_members);
    return env.bytes() -| before;
}

test "a returned NavigationResult's promises are released once its object holds them" {
    try withEnv(struct {
        fn body(env: Env) !void {
            const left = try bytesLeftByNavigationResults(env, true);
            if (left >= margin) {
                std.debug.print("{d} returned NavigationResults left {d} B of global handles\n", .{ rounds, left });
                return error.HandlesKept;
            }
        }
    }.body);
}

test "toV8Value alone keeps a returned dictionary's handed-over handles: the release is the binding's, once" {
    // The control, and the reason the release exists: the conversion keeps
    // every `.handle` member (it is the impl's in every other conversion),
    // two per NavigationResult. Were toV8Value ever to release them itself,
    // the binding's release would be a second one - this fails first.
    try withEnv(struct {
        fn body(env: Env) !void {
            const left = try bytesLeftByNavigationResults(env, false);
            try testing.expect(left >= rounds * 2 * 16);
        }
    }.body);
}

test "the object still holds the promises after the members are released" {
    try withEnv(struct {
        fn body(env: Env) !void {
            const value: NavigationResult = .{ .committed = try env.promise(), .finished = try env.promise() };
            const object = try v8.conversions.toV8Value(NavigationResult, env.isolate, env.context, value);
            defer ffi.v8_Global_Dispose(object);
            v8.conversions.releaseReturnedDictionaryHandles(NavigationResult, value);
            const global = ffi.v8_Context_Global(env.context) orelse return error.NoGlobal;
            defer ffi.v8_Object_Dispose(global);
            const key = ffi.v8_String_NewFromUtf8(env.isolate, "result", 6) orelse return error.StringFailed;
            defer ffi.v8_String_Dispose(key);
            if (!ffi.v8_Object_Set(global, env.context, @ptrCast(key), object)) return error.SetFailed;
            try testing.expectEqual(@as(i32, 1), try env.evalInt("(result.committed instanceof Promise && result.finished instanceof Promise) ? 1 : 0"));
        }
    }.body);
}

test "a member that holds nothing is not released: unset, undefined, a number, an instance's wrapper" {
    try withEnv(struct {
        fn body(env: Env) !void {
            // An instance converts to the wrapper cache's wrapper, never a
            // hold of the impl's: the release never reads it. (A pointer to
            // nothing here - reading it would fail the test.)
            var slot: u64 align(8) = 0;
            const before = env.bytes();
            for (0..rounds) |_| {
                v8.conversions.releaseReturnedDictionaryHandles(NavigationResult, .{});
                v8.conversions.releaseReturnedDictionaryHandles(NavigationResult, .{ .committed = .undefined, .finished = .{ .number = 2 } });
                v8.conversions.releaseReturnedDictionaryHandles(NavigationResult, .{ .committed = .{ .instance = @ptrCast(&slot) } });
                try env.returnDictionary(NavigationResult, .{ .committed = .null, .finished = .{ .boolean = true } }, true);
            }
            try testing.expect(env.bytes() -| before < margin);
        }
    }.body);
}

test "an inherited dictionary's handed-over member is released too" {
    // ComputedEffectTiming inherits EffectTiming's `duration`, a
    // runtime.JSValue: codegen keeps it in the `base` field.
    try withEnv(struct {
        fn body(env: Env) !void {
            for (0..64) |_| try env.returnDictionary(ComputedEffectTiming, .{ .base = .{ .duration = try env.promise() } }, true);
            const before = env.bytes();
            for (0..rounds) |_| try env.returnDictionary(ComputedEffectTiming, .{ .base = .{ .duration = try env.promise() } }, true);
            const left = env.bytes() -| before;
            if (left >= margin) {
                std.debug.print("{d} returned ComputedEffectTimings left {d} B of global handles\n", .{ rounds, left });
                return error.HandlesKept;
            }
        }
    }.body);
}
