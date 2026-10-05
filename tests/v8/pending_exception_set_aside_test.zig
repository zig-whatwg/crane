//! engine.withPendingExceptionSetAside, as V8 implements it, through the real
//! binding: a [CEReactions] member's dispatch runs in a binding catch scope;
//! what the member's steps leave pending is set aside while the bracket's end
//! runs the reactions, then made pending again in that same scope.
//!
//! HTML 4.13.6 [CEReactions]: "2. Run the originally-specified steps for this
//! construct, catching any exceptions. ... 4. Invoke custom element reactions
//! in queue. 5. If an exception exception was thrown by the original steps,
//! rethrow exception." V8 hands an exception only to a TryCatch made before
//! the throw, and its next Function::Call clears a pending one silently - so
//! the reactions `end` invokes would swallow the member's exception unless the
//! dispatch holds a TryCatch, as Blink's CEReactionsScope does. The operation
//! is agent-scoped: `end` holds no realm (any can end while the member runs)
//! and no exception value crosses the seam.
//!
//! The probe below is a generated interface's shape: static operations (the
//! binding's StaticMethodCallback - no instance to make), listed in
//! `ce_reactions` or not, each running a bracket whose `end` does what the
//! custom element reactions stack's will: when a reaction is queued, run it
//! with the pending exception set aside (it reports its own exception).

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = v8.ffi;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

/// What the probe's last bracket saw.
const Outcome = enum { not_called, ran, not_supported, terminating, failed };
var last_outcome: Outcome = .not_called;
/// The reaction's exception, as the reporter was handed it (OWNED).
var reported: ?engine.Owned = null;

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
    r.agent = @ptrCast(i);
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
    last_outcome = .not_called;
}

fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    if (reported) |r| r.release();
    reported = engine.retainValue(realm_once.?, info.error_value) catch null;
}

/// A custom element reactions bracket, as `runtime.CEReactions` will be: an
/// element queue of at most one reaction here, and the agent `begin`
/// captured.
const Bracket = struct {
    agent: ?*engine.Agent,
    reaction: ?engine.CallbackFunction = null,
    /// The reaction's steps also leave an exception pending - which the
    /// operation must clear, not restore in the member's place.
    leaky: bool = false,

    fn begin() Bracket {
        const r = engine.currentRealm() orelse return .{ .agent = null };
        return .{ .agent = r.agent };
    }

    fn enqueue(self: *Bracket, reaction: runtime.JSValue) !void {
        const r = engine.currentRealm() orelse return error.NoRealm;
        if (engine.typeOf(r, reaction) != .object) return;
        self.reaction = .{ .function = try engine.retainValue(r, reaction), .context = null };
    }

    const Run = struct {
        reaction: *const engine.CallbackFunction,
        leaky: bool,

        fn steps(data: ?*anyopaque) void {
            const self: *Run = @ptrCast(@alignCast(data.?));
            last_outcome = .ran;
            const r = engine.currentRealm() orelse return;
            // Each reaction reports its own exception.
            const completion = engine.invokeCallbackFunction(r, self.reaction, .undefined, &.{}, .{ .report = .{ .report = report } }) catch null;
            if (completion) |c| switch (c) {
                .normal, .throw => |v| v.release(),
            };
            if (self.leaky) engine.throwValue(r, runtime.JSValue.fromNumber(99)) catch {};
        }
    };

    fn end(self: *Bracket) void {
        // An empty queue makes no engine call.
        const reaction = self.reaction orelse return;
        defer reaction.release();
        const agent = self.agent orelse return;
        var run: Run = .{ .reaction = &reaction, .leaky = self.leaky };
        engine.withPendingExceptionSetAside(agent, Run.steps, &run) catch |err| {
            last_outcome = switch (err) {
                // Pending and out of reach: no script runs - the reaction
                // would go to the backup element queue (dropped here).
                error.NotSupported => .not_supported,
                error.ExceptionPending => .terminating,
                else => .failed,
            };
        };
    }
};

/// The steps every probe runs in its bracket: queue `reaction` when it is a
/// function, then throw `thrown` unless it is undefined, else return 42.
fn mutateSteps(bracket: *Bracket, thrown: runtime.JSValue, reaction: runtime.JSValue) anyerror!i32 {
    try bracket.enqueue(reaction);
    if (thrown == .undefined) return 42;
    const r = engine.currentRealm() orelse return error.NoRealm;
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
            .{ "mutateLeaky", "call_static_mutateLeaky", 2 },
            .{ "mutateUnscoped", "call_static_mutateUnscoped", 2 },
        };
        pub const own_methods = .{ "mutate", "mutateLeaky", "mutateUnscoped" };
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
    pub const ce_reactions = .{ "call_static_mutate", "call_static_mutateLeaky" };

    pub fn call_static_mutate(instance: *runtime.Instance, thrown: runtime.JSValue, reaction: runtime.JSValue) anyerror!i32 {
        _ = instance;
        var bracket = Bracket.begin();
        defer bracket.end();
        return mutateSteps(&bracket, thrown, reaction);
    }

    pub fn call_static_mutateLeaky(instance: *runtime.Instance, thrown: runtime.JSValue, reaction: runtime.JSValue) anyerror!i32 {
        _ = instance;
        var bracket = Bracket.begin();
        bracket.leaky = true;
        defer bracket.end();
        return mutateSteps(&bracket, thrown, reaction);
    }

    pub fn call_static_mutateUnscoped(instance: *runtime.Instance, thrown: runtime.JSValue, reaction: runtime.JSValue) anyerror!i32 {
        _ = instance;
        var bracket = Bracket.begin();
        defer bracket.end();
        return mutateSteps(&bracket, thrown, reaction);
    }
};

test "a member's throw survives its reactions: set aside, the reaction runs, the same value is pending again in the scope" {
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
    try std.testing.expectEqual(Outcome.ran, last_outcome);
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
}

test "nothing pending: the reactions run and the member's result stands" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  let ran = 0;
        \\  const v = BceCEReactionsProbe.mutate(undefined, () => { ran++; });
        \\  return v === 42 && ran === 1 ? 1 : 0;
        \\})()
    ));
    try std.testing.expectEqual(Outcome.ran, last_outcome);
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
    try exposeOwned("reported", reported);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.reported === globalThis.reactionError ? 1 : 0"));
}

test "steps that leave an exception pending: it is cleared, never restored in the member's place" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const err = new Error("member");
        \\  try { BceCEReactionsProbe.mutateLeaky(err, () => {}); return -1; }
        \\  catch (e) { return e === err ? 1 : 0; }
        \\})()
    ));
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  try { return BceCEReactionsProbe.mutateLeaky(undefined, () => {}) === 42 ? 1 : 0; }
        \\  catch (e) { return -1; }
        \\})()
    ));
}

test "nested: a reaction's member that throws is set aside and rethrown at its own level, then reported" {
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

test "outside a binding catch scope a pending exception is NotSupported: the steps do not run, and it stays pending" {
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
    try std.testing.expectEqual(Outcome.not_supported, last_outcome);
}

test "outside a scope with nothing pending, the steps run" {
    _ = try realm();
    defer clearKept();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  let ran = 0;
        \\  return BceCEReactionsProbe.mutateUnscoped(undefined, () => { ran++; }) === 42 && ran === 1 ? 1 : 0;
        \\})()
    ));
    try std.testing.expectEqual(Outcome.ran, last_outcome);
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
