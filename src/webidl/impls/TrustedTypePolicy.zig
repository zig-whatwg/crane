//! Implementation for the TrustedTypePolicy interface (Trusted Types 2.3.2).
//!
//! A policy has a name and options - the author's createHTML, createScript
//! and createScriptURL callbacks - and makes Trusted Type objects through
//! them (3.2 "create a trusted type", 3.3 "get trusted type policy value").
//! Only TrustedTypePolicyFactory.createPolicy makes one, through
//! dom.trusted_types; the default policy's options run from there too, when
//! a sink is handed a string (3.5).
//!
//! The callbacks are kept as values the policy's wrapper traces
//! (engine.traceValue), never as roots: a callback that closes over its
//! policy - or over the page - still goes with the policy once script holds
//! neither. Blink keeps `TrustedTypePolicyOptions` as a traced member.
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#trusted-type-policy

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const TrustedTypePolicy = interfaces.TrustedTypePolicy;

const Kind = dom.trusted_types.Kind;

pub const State = TrustedTypePolicy.State;

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The policy's name, owned.
    name: []u8,
    /// Which of options["createHTML"], ["createScript"], ["createScriptURL"]
    /// exist; the functions themselves are traced in the slot named after
    /// their option.
    has_option: std.EnumArray(Kind, bool) = .initFill(false),
};

fn slotFor(kind: Kind) engine.TracedSlot {
    return .{ .name = kind.functionName() };
}

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .name = &.{} };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // A policy freed before it was ever wrapped holds its options
        // strongly; let them go. A wrapped one's edges died with its wrapper.
        for ([_]Kind{ .html, .script, .script_url }) |kind| {
            if (internal.has_option.get(kind)) engine.forgetTracedChild(instance, slotFor(kind));
        }
        internal.allocator.free(internal.name);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

pub fn installHooks() void {
    dom.trusted_types.installPolicy(.{ .create = &create, .policy_value = &policyValue });
}

fn internalOf(instance: *runtime.Instance) ?*InternalState {
    if (instance.vtable != &TrustedTypePolicy.vtable) return null;
    return instance.getState(State).own._internal;
}

/// 3.1 steps 4-6: a new policy in `realm` named `name` (copied), with the
/// options given - each traced from the policy, which keeps no other hold.
fn create(realm: runtime.Context, name: []const u8, options: dom.trusted_types.PolicyOptions) anyerror!*runtime.Instance {
    // 4. "Let policy be a new TrustedTypePolicy object."
    const instance = try TrustedTypePolicy.init(realm.allocator, realm);
    errdefer TrustedTypePolicy.deinit(instance);
    const internal = instance.getState(State).own._internal.?;
    // 5. "Set policy's name property value to policyName."
    internal.name = try internal.allocator.dupe(u8, name);
    // 6. "Set policy's options value to «[ "createHTML" ->
    // options["createHTML"], ... ]»."
    for ([_]Kind{ .html, .script, .script_url }) |kind| {
        const callback = options.get(kind) orelse continue;
        engine.traceValue(instance, callback.function.borrow(), slotFor(kind));
        internal.has_option.set(kind, true);
    }
    return instance;
}

/// 3.3 "Get Trusted Type policy value": the option for `kind` invoked with
/// « value » + `arguments` and "rethrow", its result converted to the
/// callback's return type (DOMString?, USVString? for createScriptURL).
/// OWNED by `allocator`; null for a null or undefined result.
fn policyValue(
    policy: *runtime.Instance,
    kind: Kind,
    value: []const u8,
    arguments: []const runtime.JSValue,
    throw_if_missing: bool,
    allocator: std.mem.Allocator,
) anyerror!?[]u8 {
    const internal = internalOf(policy) orelse return error.TypeError;
    const realm = policy.ctx;
    // 1-2. "Let function be policy's options[functionName]."
    const function = if (internal.has_option.get(kind)) engine.tracedValue(policy, slotFor(kind)) else null;
    // 3. "If function is null, then: if throwIfMissing throw a TypeError,
    // else return null."
    const held = function orelse {
        if (throw_if_missing) return error.TypeError;
        return null;
    };
    defer held.release();
    // 4-5. "Let args be « value »", then each item in arguments.
    const args = try allocator.alloc(runtime.JSValue, arguments.len + 1);
    defer allocator.free(args);
    args[0] = runtime.JSValue.fromStringRef(value);
    @memcpy(args[1..], arguments);
    // 6. "Let policyValue be the result of invoking function with args and
    // "rethrow"." The callback context is not kept: the incumbent is the
    // caller's.
    const callback: engine.CallbackFunction = .{ .function = held, .context = null };
    const completion = try engine.invokeCallbackFunction(realm, &callback, .undefined, args, .rethrow);
    switch (completion) {
        .throw => |exception| {
            defer exception.release();
            try engine.throwValue(realm, exception.borrow());
            return error.ExceptionPending;
        },
        .normal => |result| {
            defer result.release();
            // The return type is nullable: null and undefined are null.
            switch (engine.typeOf(realm, result.borrow())) {
                .undefined, .null => return null,
                else => {},
            }
            // 7. Return policyValue, as the callback's return type.
            return switch (kind) {
                .script_url => try engine.convertToUSVString(realm, result.borrow(), allocator),
                .html, .script => try engine.convertToDOMString(realm, result.borrow(), allocator),
            };
        },
    }
}

/// 3.2 "Create a Trusted Type" given this policy, `kind`, `input` and
/// `arguments`.
fn createTrustedType(instance: *runtime.Instance, kind: Kind, input: runtime.DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
    const allocator = instance.ctx.allocator;
    // 1-2. Get trusted type policy value with throwIfMissing true; its error
    // is rethrown.
    const policy_value = try policyValue(instance, kind, input.asSlice(), arguments, true, allocator);
    defer if (policy_value) |v| allocator.free(v);
    // 3-4. "Let dataString be the result of stringifying policyValue"; the
    // empty string for null or undefined.
    const data = policy_value orelse "";
    // 5. A new instance with its data set to dataString, in this policy's
    // relevant realm.
    return dom.trusted_types.createValue(instance.ctx, kind, data);
}

/// "The name getter steps are to return this's name."
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = internalOf(instance) orelse return error.TypeError;
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
}

/// createHTML(input, ...arguments): create a trusted type with "TrustedHTML".
pub fn call_createHTML(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
    return createTrustedType(instance, .html, input, arguments);
}

/// createScript(input, ...arguments): create a trusted type with
/// "TrustedScript".
pub fn call_createScript(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
    return createTrustedType(instance, .script, input, arguments);
}

/// createScriptURL(input, ...arguments): create a trusted type with
/// "TrustedScriptURL".
pub fn call_createScriptURL(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
    return createTrustedType(instance, .script_url, input, arguments);
}
