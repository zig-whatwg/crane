//! Implementation for the AnimationWorkletGlobalScope interface (CSS
//! Animation Worklet): the animation worklet's global scope, whose
//! registerAnimator() records an animator definition. Crane runs no worklet
//! animation, so no definition is invoked (see html.worklet_host,
//! "Registering classes").

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const callbacks = @import("callbacks");
const engine = @import("engine");
const html = @import("html");
const css = @import("css");
const AnimationWorkletGlobalScope = interfaces.AnimationWorkletGlobalScope;
const worklet_host = html.worklet_host;

pub const State = AnimationWorkletGlobalScope.State;

/// An animator definition, less its class constructor and functions, which
/// nothing invokes.
const AnimatorDefinition = struct {
    stateful: bool,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The animator definitions map.
    definitions: worklet_host.Definitions(AnimatorDefinition) = .{},
};

fn freeDefinition(_: std.mem.Allocator, _: *AnimatorDefinition) void {}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.getState(State);
    if (state.own._internal) |internal| return internal;
    const allocator = instance.ctx.allocator;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    state.own._internal = internal;
    return internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.definitions.deinit(internal.allocator, freeDefinition);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// registerAnimator(name, animatorCtor) - CSS Animation Worklet,
/// "Registering an Animator Definition".
pub fn call_registerAnimator(instance: *runtime.Instance, name: runtime.DOMString, animatorCtor: callbacks.AnimatorInstanceConstructor) anyerror!void {
    const constructor = engine.takeCallbackFunction(@ptrCast(animatorCtor));
    defer constructor.release();
    const realm = instance.ctx;
    const ctor = constructor.function.value;
    const name_slice = name.asSlice();

    // Step 1: a name that is not a valid <ident> throws a TypeError.
    if (!isIdent(name_slice)) return error.TypeError;
    // Steps 2-3: a name already defined throws a NotSupportedError.
    const internal = try internalOf(instance);
    if (internal.definitions.contains(name_slice)) return error.NotSupportedError;
    // Steps 4-5: a constructor and its prototype - which must be an Object
    // for step 6's Get.
    const prototype = try worklet_host.classPrototype(realm, ctor);
    defer prototype.release();
    // Steps 6-7: its animate function.
    try worklet_host.requireFunction(realm, prototype.value, "animate");
    // Steps 8-9: a state function makes it stateful.
    const state_value = try engine.getProperty(realm, prototype.value, "state");
    defer state_value.release();
    const stateful = engine.isCallable(realm, state_value.value);
    // Steps 10-11: the definition. Step 12's document animator definition
    // is for running animations, which Crane does not do.
    try internal.definitions.put(internal.allocator, name_slice, .{ .stateful = stateful });
}

/// Whether `name` is a valid <ident> (CSS Values 4): it tokenizes as exactly
/// one <ident-token> (CSS Syntax 3).
fn isIdent(name: []const u8) bool {
    var tokenizer = css.Tokenizer.init(name);
    const first = tokenizer.next();
    if (first.token_type != .ident) return false;
    const rest = tokenizer.next();
    return rest.isEof();
}
