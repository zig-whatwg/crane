//! Implementation for the TrustedTypePolicyFactory interface (Trusted Types
//! 2.3.1): `trustedTypes` on a Window or a WorkerGlobalScope.
//!
//! A factory has a default policy (initially null) and an ordered set of
//! created policy names (initially empty). createPolicy runs 3.1 "create a
//! Trusted Type policy" - the CSP check of 4.2.5 against the factory's
//! relevant global's CSP list first. The global keeps its factory as a
//! traced child (global_settings `trusted_types`); the factory keeps its
//! default policy and its empty values the same way.
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#trusted-type-policy-factory

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const csp = @import("csp");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const TrustedTypePolicyFactory = interfaces.TrustedTypePolicyFactory;

const Kind = dom.trusted_types.Kind;

pub const State = TrustedTypePolicyFactory.State;

/// A child the factory hands out and keeps: the default policy, emptyHTML,
/// emptyScript.
const Kept = struct {
    value: ?*runtime.Instance = null,
    edge: same_object.Traced,

    fn hold(self: *Kept, owner: *runtime.Instance, child: *runtime.Instance) void {
        self.value = child;
        self.edge.hold(owner, child);
    }

    fn release(self: *Kept, owner: *runtime.Instance) void {
        self.edge.release(owner);
        self.value = null;
    }
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// "Created policy names", an ordered set; each name owned.
    created_policy_names: std.ArrayListUnmanaged([]u8) = .empty,
    /// "Default policy", initially null.
    default_policy: Kept = .{ .edge = .{ .slot = .{ .name = "defaultPolicy" } } },
    empty_html: Kept = .{ .edge = .{ .slot = .{ .name = "emptyHTML" } } },
    empty_script: Kept = .{ .edge = .{ .slot = .{ .name = "emptyScript" } } },

    fn deinit(self: *InternalState, factory: *runtime.Instance) void {
        self.default_policy.release(factory);
        self.empty_html.release(factory);
        self.empty_script.release(factory);
        for (self.created_policy_names.items) |name| self.allocator.free(name);
        self.created_policy_names.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(instance);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

pub fn installHooks() void {
    dom.trusted_types.installFactory(.{ .default_policy = &defaultPolicy });
}

fn internalOf(instance: *runtime.Instance) ?*InternalState {
    if (instance.vtable != &TrustedTypePolicyFactory.vtable) return null;
    return instance.getState(State).own._internal;
}

fn defaultPolicy(factory: *runtime.Instance) ?*runtime.Instance {
    const internal = internalOf(factory) orelse return null;
    return internal.default_policy.value;
}

/// emptyHTML / emptyScript: a value of `kind` whose data is the empty
/// string, made once and kept.
fn emptyValue(instance: *runtime.Instance, kind: Kind) anyerror!*runtime.Instance {
    const internal = internalOf(instance) orelse return error.TypeError;
    const kept = switch (kind) {
        .html => &internal.empty_html,
        .script => &internal.empty_script,
        .script_url => unreachable,
    };
    if (kept.value) |value| return value;
    const value = try dom.trusted_types.createValue(instance.ctx, kind, "");
    kept.hold(instance, value);
    return value;
}

/// "is a TrustedHTML object with its data value set to an empty string."
pub fn get_emptyHTML(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return emptyValue(instance, .html);
}

/// "is a TrustedScript object with its data value set to an empty string."
pub fn get_emptyScript(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return emptyValue(instance, .script);
}

/// "Returns the value of default policy."
pub fn get_defaultPolicy(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = internalOf(instance) orelse return error.TypeError;
    return internal.default_policy.value;
}

/// createPolicy(policyName, policyOptions): 3.1 "Create a Trusted Type
/// Policy" with this, policyName, policyOptions and this's relevant global
/// object.
pub fn call_createPolicy(instance: *runtime.Instance, policyName: runtime.DOMString, policyOptions: webidl.Opt(dictionaries.TrustedTypePolicyOptions)) anyerror!*runtime.Instance {
    // The options' callbacks, which the binding made for this call and
    // nothing else releases: taken here, released when the policy has its
    // own traced copies (or creation failed).
    var options: dom.trusted_types.PolicyOptions = .{};
    if (policyOptions.wasPassed()) {
        const given = policyOptions.getValue();
        if (given.createHTML) |f| options.html = engine.takeCallbackFunction(@ptrCast(f));
        if (given.createScript) |f| options.script = engine.takeCallbackFunction(@ptrCast(f));
        if (given.createScriptURL) |f| options.script_url = engine.takeCallbackFunction(@ptrCast(f));
    }
    defer for ([_]Kind{ .html, .script, .script_url }) |kind| {
        if (options.get(kind)) |callback| callback.release();
    };

    const internal = internalOf(instance) orelse return error.TypeError;
    const name = policyName.asSlice();
    const global = dom.trusted_types.relevantGlobalOf(instance);

    // 1-2. "Let allowedByCSP be the result of executing should Trusted Type
    // policy creation be blocked by content security policy? with global,
    // policyName and factory's created policy names. If allowedByCSP is
    // "Blocked", throw a TypeError."
    if (global) |g| {
        if (dom.trusted_types.cspListOf(g)) |list| {
            const blocked = csp.directives.trusted_types.shouldPolicyCreationBeBlocked(
                list,
                name,
                internal.created_policy_names.items,
                dom.csp_violations.reporterFor(g),
            );
            if (blocked == .blocked) return error.TypeError;
        }
    }
    // 3. "If policyName is default and the factory's default policy value is
    // not null, throw a TypeError."
    const is_default = std.mem.eql(u8, name, "default");
    if (is_default and internal.default_policy.value != null) return error.TypeError;

    // 4-6. A new policy with policyName and the options.
    const policy = try dom.trusted_types.createPolicy(instance.ctx, name, options);
    // 7. "If the policyName is default, set the factory's default policy
    // value to policy."
    if (is_default) internal.default_policy.hold(instance, policy);
    // 8. "Append policyName to factory's created policy names" - a set:
    // a name already there is not appended again.
    if (!containsName(internal, name)) {
        const copy = try internal.allocator.dupe(u8, name);
        errdefer internal.allocator.free(copy);
        try internal.created_policy_names.append(internal.allocator, copy);
    }
    // 9. "Return policy."
    return policy;
}

fn containsName(internal: *const InternalState, name: []const u8) bool {
    for (internal.created_policy_names.items) |created| {
        if (std.mem.eql(u8, created, name)) return true;
    }
    return false;
}

/// isHTML/isScript/isScriptURL: "Returns true if value is an instance of
/// TrustedHTML and has an associated data value set, false otherwise" - a
/// platform object, not an object whose prototype is one.
fn isTrusted(instance: *runtime.Instance, value: runtime.JSValue, kind: Kind) bool {
    const realm = engine.currentRealm() orelse instance.ctx;
    const object = engine.convertToPlatformObject(realm, value) orelse return false;
    return dom.trusted_types.dataOf(object, kind) != null;
}

pub fn call_isHTML(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
    return isTrusted(instance, value, .html);
}

pub fn call_isScript(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
    return isTrusted(instance, value, .script);
}

pub fn call_isScriptURL(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
    return isTrusted(instance, value, .script_url);
}

/// An optional `DOMString? = ""` argument: "" when not passed.
fn optionalNamespace(argument: webidl.Opt(?runtime.DOMString)) ?[]const u8 {
    if (!argument.wasPassed()) return "";
    const value = argument.getValue() orelse return null;
    return value.asSlice();
}

/// getPropertyType(tagName, property, elementNs) (2.3.1).
pub fn call_getPropertyType(instance: *runtime.Instance, tagName: runtime.DOMString, property: runtime.DOMString, elementNs: webidl.Opt(?runtime.DOMString)) anyerror!?runtime.DOMString {
    const kind = try dom.trusted_types.getPropertyType(instance.ctx.allocator, tagName.asSlice(), property.asSlice(), optionalNamespace(elementNs)) orelse return null;
    return runtime.DOMString.initInterned(kind.interfaceName());
}

/// getAttributeType(tagName, attribute, elementNs, attrNs) (2.3.1).
pub fn call_getAttributeType(instance: *runtime.Instance, tagName: runtime.DOMString, attribute: runtime.DOMString, elementNs: webidl.Opt(?runtime.DOMString), attrNs: webidl.Opt(?runtime.DOMString)) anyerror!?runtime.DOMString {
    const kind = try dom.trusted_types.getAttributeType(instance.ctx.allocator, tagName.asSlice(), attribute.asSlice(), optionalNamespace(elementNs), optionalNamespace(attrNs)) orelse return null;
    return runtime.DOMString.initInterned(kind.interfaceName());
}
