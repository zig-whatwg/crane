//! Implementation for SVGElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const SVGElement = interfaces.SVGElement;
const dom = @import("dom");

pub const State = SVGElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// HTML 2.5.6's owned nonce slot. Allocated only on the first nonempty
/// nonce; ordinary SVG elements need no extra state block or registry entry.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    cryptographic_nonce: ?[]u8 = null,

    pub fn deinit(self: *InternalState) void {
        if (self.cryptographic_nonce) |nonce| self.allocator.free(nonce);
    }
};

const States = dom.orphan_states.Swept(.svg_element, InternalState);

pub fn installHooks() void {
    dom.attribute_change_steps.installForAttribute("http://www.w3.org/2000/svg", "nonce", .{ .change = &nonceAttributeChanged, .read = &nonceValueOf });
    dom.mutation.registerInsertionStepsCallback(&nonceInsertionSteps) catch @panic("out of memory installing nonce insertion steps");
    dom.cloning_steps.install(&nonceCloningSteps);
    States.installSweep();
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    if (state.own._internal == null) return;
    States.destroy(instance);
    state.own._internal = null;
}

fn nonceState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Getter for className
pub fn get_className(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ownerSVGElement
pub fn get_ownerSVGElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for viewportElement
pub fn get_viewportElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for style
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributeStyleMap
pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for correspondingElement
pub fn get_correspondingElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for correspondingUseElement
pub fn get_correspondingUseElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for dataset
pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nonce
pub fn get_nonce(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initDupe(instance.ctx.allocator, nonceValueOf(instance));
}

/// Getter for autofocus
pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for tabIndex
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for nonce
pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    if (state.own._internal == null and value.isEmpty()) return;
    const allocator = if (state.own._internal) |internal| internal.allocator else instance.ctx.allocator;
    const copy = try allocator.dupe(u8, value.asSlice());
    errdefer allocator.free(copy);
    const internal = state.own._internal orelse blk: {
        const made = try States.create(instance, .{ .allocator = allocator });
        state.own._internal = made;
        break :blk made;
    };
    if (internal.cryptographic_nonce) |old| allocator.free(old);
    internal.cryptographic_nonce = copy;
}

/// Borrowed until the next nonce change; the IDL getter copies.
fn nonceValueOf(instance: *runtime.Instance) []const u8 {
    const internal = nonceState(instance) orelse return "";
    return internal.cryptographic_nonce orelse "";
}

/// HTML 2.5.6 attribute change steps 1-4, after the hook's namespace and
/// local-name dispatch. A namespaced nonce attribute has no effect.
fn nonceAttributeChanged(instance: *runtime.Instance, _: []const u8, _: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null) return;
    if (value) |bytes| {
        set_nonce(instance, runtime.DOMString.initInterned(bytes)) catch {
            if (nonceState(instance)) |internal| {
                if (internal.cryptographic_nonce) |old| internal.allocator.free(old);
                internal.cryptographic_nonce = null;
            }
        };
    } else if (nonceState(instance)) |internal| {
        if (internal.cryptographic_nonce) |old| internal.allocator.free(old);
        internal.cryptographic_nonce = null;
    }
}

/// HTML 2.5.6 becomes-browsing-context-connected steps 1-2.3.
fn nonceInsertionSteps(node: *dom.NodeBase) void {
    if (node.node_type != 1 or !node.is_connected) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    const internal = nonceState(instance) orelse return;
    const saved = internal.cryptographic_nonce orelse return;
    const data = dom.element_data.of(instance) orelse return;
    const attribute = dom.element_data.getAttributeByNamespaceAndLocalName(data, null, "nonce") orelse return;
    if (attribute.value.len == 0) return;
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
    const container = dom.policy_containers.of(document) orelse return;
    if (!container.csp_list.contains_header_policy) return;
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    internal.cryptographic_nonce = null;
    defer {
        if (internal.cryptographic_nonce) |empty| internal.allocator.free(empty);
        internal.cryptographic_nonce = saved;
    }
    dom.element_attributes.set(instance, "nonce", "", .{}) catch {};
}

/// HTML 2.5.6 cloning steps, with an independent owned copy.
fn nonceCloningSteps(node: *runtime.Instance, copy: *runtime.Instance, _: bool) anyerror!void {
    const source = nonceState(node) orelse return;
    if (source.cryptographic_nonce) |nonce| {
        try set_nonce(copy, runtime.DOMString.initInterned(nonce));
    } else if (nonceState(copy)) |target| {
        if (target.cryptographic_nonce) |old| target.allocator.free(old);
        target.cryptographic_nonce = null;
    }
}

/// Setter for autofocus
pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for tabIndex
pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: blur
/// HTMLOrSVGElement: the unfocusing steps (src/html/focus.zig, shared with
/// HTMLElement and the mixin).
pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    @import("html").focus.blurMethod(instance);
}

/// Operation: focus
/// HTMLOrSVGElement: the focusing steps (src/html/focus.zig, shared with
/// HTMLElement and the mixin).
pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FocusOptions)) anyerror!void {
    // preventScroll and focusVisible: nothing is rendered or scrolled.
    _ = options;
    @import("html").focus.focusMethod(instance);
}
