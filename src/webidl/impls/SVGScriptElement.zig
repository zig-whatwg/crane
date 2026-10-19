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
///
/// A block of the Browser's runtime arena kept in the registry, as
/// HTMLScriptElement's is: an SVG script removed from its tree while script
/// held no wrapper of it - innerHTML = '' over one, a sanitizer's removal -
/// is an orphan nothing deinits (dom.teardown_sweeps), and its state's one
/// exit is then the sweep at its Browser's end. A block of its own
/// (`allocator.create`) had none, and leaked per orphaned script.
pub const InternalState = struct {
    flags: ScriptFlags = .{},

    /// What the state owns: its script text (Trusted Types 4.1.2.1).
    pub fn deinit(self: *InternalState) void {
        self.flags.script_text.deinit();
    }
};

const Registry = runtime.InstanceRegistry(.svg_script_element, InternalState);

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch {};
    dom_module.mutation.registerChildrenChangedCallback(&childrenChangedSteps) catch {};
    // The parsers and html's script processing reach its state through
    // dom.script_elements, and a connected one prepares on insertion and on
    // children changing: installed before any SVG script exists.
    dom_module.script_elements.installSvg(.{ .flags = &flagsOf });
    dom_module.cloning_steps.install(&cloningSteps);
    // Its states no exit reached - orphaned scripts' - at its Browser's end.
    dom_module.teardown_sweeps.install(.script_elements, &sweepRemaining);
}

/// `dom.teardown_sweeps`: free what the state of every SVG script no deinit
/// reached still owns - its script text - at its Browser's end; the arena
/// takes the blocks.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}

/// DOM clone-a-node step 3. SVG does not specify this extension, but all
/// three engines copy already-started and WPT requires it for inert imports:
/// WebKit SVGScriptElement::cloneElementWithoutAttributesAndChildren,
/// Blink SVGScriptElement::CloneWithoutAttributesAndChildren, and
/// Gecko SVGScriptElement::Clone. Their copies are not parser-inserted.
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/svg/SVGScriptElement.cpp
/// https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/svg/svg_script_element.cc
/// https://github.com/mozilla-firefox/firefox/blob/main/dom/svg/SVGScriptElement.cpp
fn cloningSteps(node: *runtime.Instance, copy: *runtime.Instance, _: bool) anyerror!void {
    const source = flagsOf(node) orelse return;
    const target = flagsOf(copy) orelse return;
    target.already_started = source.already_started;
}

/// SVGScriptElement's own construction steps: the generated chain runs SVGElement's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // The node's name, which the DOM's insertion and children-changed steps
    // dispatch on.
    try NodeImpl.setLocalName(instance, runtime.DOMString.initInterned("script"));

    _ = allocator;
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = .{};
    instance.getState(State).own._internal = internal;
}

/// SVGScriptElement's own teardown: the generated chain runs SVGElement's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    if (instance.stateAs(State)) |state| {
        if (state.own._internal) |internal| {
            internal.deinit();
            state.own._internal = null;
            Registry.remove(instance);
        }
    }
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
    // DOM "get an attribute value" given the element and "type".
    const data = dom_module.element_data.of(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initInterned(dom_module.element_data.getAttributeValue(data, "type", null));
}

/// Setter for type: DOM "set an attribute value" for `type`.
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try dom_module.element_attributes.set(instance, "type", value.asSlice(), .{});
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
fn childrenChangedSteps(node: *NodeBase, change: dom_module.mutation.ChildrenChange) void {
    // As for HTML scripts (DOM 808/1261, HTML 10188/4354), skip removal.
    // WebKit SVGScriptElement::childrenChanged delegates to ScriptElement,
    // whose childrenChanged requires childChange.isInsertion().
    if (change == .removed) return;
    if (!node.is_connected) return;
    const instance = svgScriptOf(node) orelse return;
    @import("html").script_execution.svgScriptInsertionOrChildrenChanged(instance.ctx.allocator, instance);
}
