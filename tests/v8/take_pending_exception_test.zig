//! engine.takePendingException, as V8 implements it, through the real
//! binding: a [CEReactions] member's dispatch runs in a binding catch scope,
//! and what the member's steps leave pending is taken from it.
//!
//! HTML 4.13.6 [CEReactions]: "2. Run the originally-specified steps for this
//! construct, catching any exceptions. ... 4. Invoke custom element reactions
//! in queue. 5. If an exception exception was thrown by the original steps,
//! rethrow exception." V8 hands an exception only to a TryCatch made before
//! the throw, and its next Function::Call clears a pending one silently - so
//! the reactions `end` invokes would swallow the member's exception unless the
//! dispatch holds a TryCatch, as Blink's CEReactionsScope does.
//!
//! The probe below is a generated interface's shape: static operations (the
//! binding's StaticMethodCallback - no instance to make), one listed in
//! `ce_reactions` and one not, each running a bracket whose `end` does what
//! the custom element reactions stack's will: when a reaction is queued,
//! take the pending exception, invoke the reaction (it reports its own
//! exception), rethrow what was taken.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = v8.ffi;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

/// What the probe's last bracket saw: takePendingException's answer.
const Take = enum { not_called, taken, nothing, not_supported, terminating, failed };
var last_take: Take = .not_called;
/// The reaction's exception, as the reporter was handed it (OWNED).
var reported: ?engine.Owned = null;
/// The value `swallow` took (OWNED).
var swallowed: ?engine.Owned = null;

/// One isolate and realm for the file, registered with the context manager
/// as a page's is, the probe installed as a global; V8 is never torn down.
fn realm() !runtime.Context {
    if (realm_once) |r| return r;
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    v8.V8Interface(Probe).registerGlobal(i, context, Probe.Meta.name);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
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

fn setGlobal(name: []const u8, value: *ffi.Value) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), value)) return error.SetFailed;
}

/// Expose an Owned the test kept as `globalThis[name]`.
fn exposeOwned(name: []const u8, value: ?engine.Owned) !void {
    const held = value orelse return error.NothingKept;
    try setGlobal(name, @ptrCast(@alignCast(held.value.handle.ptr)));
}

fn clearKept() void {
    if (reported) |r| r.release();
    reported = null;
    if (swallowed) |s| s.release();
    swallowed = null;
    last_take = .not_called;
}

fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    if (reported) |r| r.release();
    reported = engine.retainValue(realm_once.?, info.error_value) catch null;
}

/// A custom element reactions bracket, as `runtime.CEReactions` will be: an
/// element queue of at most one reaction here.
const Bracket = struct {
    reaction: ?engine.CallbackFunction = null,

    fn enqueue(self: *Bracket, r: runtime.Context, reaction: runtime.JSValue) !void {
        if (engine.typeOf(r, reaction) != .object) return;
        self.reaction = .{ .function = try engine.retainValue(r, reaction), .context = null };
    }

    fn end(self: *Bracket) void {
        // An empty queue makes no engine call.
        const reaction = self.reaction orelse return;
        defer reaction.release();
        const r = engine.currentRealm() orelse return;
        const pending = engine.takePendingException(r) catch |err| {
            last_take = switch (err) {
                // Pending and out of reach: run no script - the reaction would
                // go to the backup element queue (dropped here).
                error.NotSupported => .not_supported,
                error.ExceptionPending => .terminating,
                else => .failed,
            };
            return;
        };
        last_take = if (pending != null) .taken else .nothing;
        // Each reaction reports its own exception.
        const completion = engine.invokeCallbackFunction(r, &reaction, .undefined, &.{}, .{ .report = .{ .report = report } }) catch null;
        if (completion) |c| switch (c) {
            .normal, .throw => |v| v.release(),
        };
        // 5. If an exception was thrown by the original steps, rethrow it.
        if (pending) |p| {
            defer p.release();
            engine.throwValue(r, p.borrow()) catch {};
        }
    }
};

/// The steps both probes run in their bracket: queue `reaction` when it is
/// a function, then throw `thrown` unless it is undefined, else return 42.
fn mutateSteps(instance: *runtime.Instance, bracket: *Bracket, thrown: runtime.JSValue, reaction: runtime.JSValue) anyerror!i32 {
    const r = engine.currentRealm() orelse instance.ctx;
    try bracket.enqueue(r, reaction);
    if (thrown == .undefined) return 42;
    try engine.throwValue(r, thrown);
    return error.ExceptionPending;
}

const Probe = struct {
    pub const Meta = struct {
        pub const name = "BceCEReactionsProbe";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        pub const exposed_in_all_contexts = true;
        pub const properties = .{};
        pub const methods = .{};
        pub const static_methods = .{
            .{ "mutate", "call_static_mutate", 2 },
            .{ "mutateUnscoped", "call_static_mutateUnscoped", 2 },
            .{ "swallow", "call_static_swallow", 1 },
        };
        pub const own_methods = .{ "mutate", "mutateUnscoped", "swallow" };
        pub const inherited_methods = .{};
        pub const eager_properties = .{};
        pub const lazy_properties = .{};
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, struct {});

    /// As a generated interface writes it: the functions that bracket and
    /// that the binding dispatches in a catch scope. `mutateUnscoped`
    /// brackets too but is left out - a [CEReactions] member reached without
    /// a scope, as one called from Zig is.
    pub const ce_reactions = .{ "call_static_mutate", "call_static_swallow" };

    pub fn call_static_mutate(instance: *runtime.Instance, thrown: runtime.JSValue, reaction: runtime.JSValue) anyerror!i32 {
        var bracket: Bracket = .{};
        defer bracket.end();
        return mutateSteps(instance, &bracket, thrown, reaction);
    }

    pub fn call_static_mutateUnscoped(instance: *runtime.Instance, thrown: runtime.JSValue, reaction: runtime.JSValue) anyerror!i32 {
        var bracket: Bracket = .{};
        defer bracket.end();
        return mutateSteps(instance, &bracket, thrown, reaction);
    }

    /// Throw `thrown` the way an impl does, take it back, and return
    /// normally: if anything were still pending, script would see it.
    pub fn call_static_swallow(instance: *runtime.Instance, thrown: runtime.JSValue) anyerror!i32 {
        const r = engine.currentRealm() orelse instance.ctx;
        try engine.throwValue(r, thrown);
        if (swallowed) |s| s.release();
        swallowed = try engine.takePendingException(r);
        return if (swallowed != null) 7 else 0;
    }
};

test "a member's throw survives its reactions: script catches the original value, and the reactions ran" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const err = new Error("member");
        \\  let ran = 0;
        \\  try { BceCEReactionsProbe.mutate(err, () => { ran++; }); return -1; }
        \\  catch (e) { return e === err && ran === 1 ? 1 : 0; }
        \\})()
    ));
    try std.testing.expectEqual(Take.taken, last_take);
}

test "a primitive thrown by the member comes back as itself" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  let ran = 0;
        \\  try { BceCEReactionsProbe.mutate(17, () => { ran++; }); return -1; }
        \\  catch (e) { return e === 17 && ran === 1 ? 1 : 0; }
        \\})()
    ));
    try std.testing.expectEqual(Take.taken, last_take);
}

test "nothing pending is null: the reactions run and the member's result stands" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  let ran = 0;
        \\  const v = BceCEReactionsProbe.mutate(undefined, () => { ran++; });
        \\  return v === 42 && ran === 1 ? 1 : 0;
        \\})()
    ));
    try std.testing.expectEqual(Take.nothing, last_take);
}

test "a reaction's throw is reported, and the member's result stands" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 42), try evalInt(
        \\(() => {
        \\  globalThis.reactionError = new Error("reaction");
        \\  return BceCEReactionsProbe.mutate(undefined, () => { throw reactionError; });
        \\})()
    ));
    try std.testing.expectEqual(Take.nothing, last_take);
    try exposeOwned("reported", reported);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.reported === globalThis.reactionError ? 1 : 0"));
}

test "nested: a reaction's member that throws is taken and rethrown at its own level, then reported" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const outer = new Error("outer");
        \\  globalThis.innerError = new Error("inner");
        \\  let outerRan = 0, innerRan = 0;
        \\  try {
        \\    BceCEReactionsProbe.mutate(outer, () => {
        \\      outerRan++;
        \\      BceCEReactionsProbe.mutate(innerError, () => { innerRan++; });
        \\    });
        \\    return -1;
        \\  } catch (e) { return e === outer && outerRan === 1 && innerRan === 1 ? 1 : 0; }
        \\})()
    ));
    // The inner member's exception left the reaction, which reported it; it
    // never reached the outer member.
    try exposeOwned("reported", reported);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.reported === globalThis.innerError ? 1 : 0"));
}

test "a taken exception is no longer pending: the member returns normally" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  globalThis.swallowError = new Error("swallowed");
        \\  try { return BceCEReactionsProbe.swallow(swallowError) === 7 ? 1 : 0; }
        \\  catch (e) { return -1; }
        \\})()
    ));
    try exposeOwned("taken", swallowed);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.taken === globalThis.swallowError ? 1 : 0"));
}

test "outside a binding catch scope a pending exception is NotSupported, stays pending, and no script runs" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const err = new Error("unscoped");
        \\  let ran = 0;
        \\  try { BceCEReactionsProbe.mutateUnscoped(err, () => { ran++; }); return -1; }
        \\  catch (e) { return e === err && ran === 0 ? 1 : 0; }
        \\})()
    ));
    try std.testing.expectEqual(Take.not_supported, last_take);
}

test "outside a scope with nothing pending is null" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 42), try evalInt("BceCEReactionsProbe.mutateUnscoped(undefined, () => {})"));
    try std.testing.expectEqual(Take.nothing, last_take);
}

test "the binding finds a member's bracket in its interface's ce_reactions table" {
    const binding = v8.interface_mod;
    try std.testing.expect(binding.runsCEReactions(interfaces.Element, "set_id"));
    try std.testing.expect(!binding.runsCEReactions(interfaces.Element, "get_id"));
    try std.testing.expect(binding.dispatchRunsCEReactions(interfaces.Element, "call_setAttribute"));
    // An inherited mixin member, by its includer's alias.
    try std.testing.expect(binding.dispatchRunsCEReactions(interfaces.Element, "call_append"));
    try std.testing.expect(binding.dispatchRunsCEReactions(interfaces.Node, "call_appendChild"));
    // A named setter, which an interceptor calls.
    try std.testing.expect(binding.runsCEReactions(interfaces.DOMStringMap, "call_setter"));
    // An overload set whose installed first overload forwards to `__1`.
    try std.testing.expect(binding.dispatchRunsCEReactions(interfaces.HTMLSelectElement, "call_remove"));
    try std.testing.expect(!binding.dispatchRunsCEReactions(interfaces.Node, "call_contains"));
    // An interface with no [CEReactions] member has no table.
    try std.testing.expect(!binding.dispatchRunsCEReactions(interfaces.URL, "call_toJSON"));
}
