//! SVGScriptElement: the script element in the SVG namespace.
//!
//! Spec: https://svgwg.org/svg2-draft/interact.html#ScriptElement
//! "A script element is equivalent to the script element in HTML and thus is
//! the place for scripts". Its processing model is HTML's "prepare the script
//! element", with SVG's differences - its URL is `href` (or the deprecated
//! `xlink:href`), never `src`, and it has no async or defer - which html's
//! script_execution runs for it (as Blink runs its SVGScriptElement through
//! the same ScriptLoader as HTMLScriptElement).
//!
//! This impl keeps the element's script element state (parser-inserted,
//! already started), reached through the dom.script_elements hook, and runs
//! HTML's triggers for preparing it: becoming connected, and its children
//! changing while connected.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const SVGScriptElement = interfaces.SVGScriptElement;

const SVGElementImpl = @import("SVGElement.zig");
const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");

const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;
const ScriptFlags = dom_module.script_elements.ScriptFlags;

pub const State = SVGScriptElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The element's script element state (HTML § 4.12.1.1): parser-inserted and
/// already started.
pub const InternalState = struct {
    flags: ScriptFlags = .{},
    /// The allocator this block came from.
    allocator: std.mem.Allocator,
};

/// Initialize instance, through the chain SVGElement -> Element -> Node ->
/// EventTarget.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // The parsers and html's script processing reach its state through
    // dom.script_elements, and a connected one prepares on insertion and on
    // children changing: installed before any SVG script exists.
    dom_module.script_elements.installSvg(.{ .flags = &flagsOf });
    ensureStepsRegistered();

    const instance = try SVGElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer SVGElementImpl.deinit(instance);

    // The node's name, which the DOM's insertion and children-changed steps
    // dispatch on.
    try NodeImpl.setLocalName(instance, runtime.DOMString.initInterned("script"));

    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// Deinitialize instance, through its ancestors' impls.
pub fn deinit(instance: *runtime.Instance) void {
    if (instance.stateAs(State)) |state| {
        if (state.own._internal) |internal| {
            internal.allocator.destroy(internal);
            state.own._internal = null;
        }
    }
    SVGElementImpl.deinit(instance);
}

/// dom.script_elements: `element`'s script element state, if it is an SVG
/// script element.
fn flagsOf(element: *runtime.Instance) ?*ScriptFlags {
    const state = element.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.flags;
}

/// Getter for type: reflects the `type` content attribute.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const value = ElementImpl.getAttributeValue(instance, "type", null);
    return runtime.DOMString.initInterned(value);
}

/// Setter for type: DOM "set an attribute value" for `type`.
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try ElementImpl.setAttributeValue(instance, "type", value.asSlice(), null, null);
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

// =============================================================================
// Insertion and children-changed steps
// =============================================================================

var steps_registered: bool = false;

fn ensureStepsRegistered() void {
    if (steps_registered) return;
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch return;
    dom_module.mutation.registerChildrenChangedCallback(&childrenChangedSteps) catch return;
    steps_registered = true;
}

/// The SVG script element `node` stands for, if it is one.
fn svgScriptOf(node: *NodeBase) ?*runtime.Instance {
    if (node.node_type != 1) return null;
    if (!std.ascii.eqlIgnoreCase(node.node_name, "script")) return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(node) orelse return null));
    if (instance.stateAs(State) == null) return null;
    return instance;
}

/// HTML: "When a script element el that is not parser-inserted experiences
/// one of the events listed in the following list, the user agent must
/// immediately prepare the script element: The script element becomes
/// connected."
fn insertionSteps(node: *NodeBase) void {
    const instance = svgScriptOf(node) orelse return;
    @import("html").script_execution.svgScriptInsertionOrChildrenChanged(instance.ctx.allocator, instance);
}

/// HTML's script children changed steps: "1. If the script element is not
/// connected, then return. 2. Run the script HTML element post-connection
/// steps" - which prepare a script that is not parser-inserted.
fn childrenChangedSteps(node: *NodeBase) void {
    if (!node.is_connected) return;
    const instance = svgScriptOf(node) orelse return;
    @import("html").script_execution.svgScriptInsertionOrChildrenChanged(instance.ctx.allocator, instance);
}
