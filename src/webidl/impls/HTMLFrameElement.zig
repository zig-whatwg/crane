//! Implementation for HTMLFrameElement interface (HTML 16.3.2).
//!
//! "The frame element has a content navigable similar to the iframe element,
//! but rendered within a frameset element" - and, with no layout, rendered
//! nowhere: a frame outside a frameset has its content navigable too (as in
//! every browser). Its post-connection steps create a new child navigable
//! and process the frame attributes; its removing steps destroy it; a src
//! attribute set, changed or removed while it has one processes the frame
//! attributes again. The navigable machinery - "create a new child
//! navigable", "destroy a child navigable", "navigate an iframe or frame" -
//! is reached through dom.navigables, as the object and embed elements reach
//! it. The reflected attributes (name, src, scrolling, frameBorder,
//! longDesc, noResize, marginHeight, marginWidth) are the generated
//! interface's.
//!
//! Spec: https://html.spec.whatwg.org/multipage/obsolete.html#frames

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const html_core = @import("html_core");
const HTMLFrameElement = interfaces.HTMLFrameElement;
const IFrameIntegration = html_core.IFrameIntegration;

pub const State = HTMLFrameElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The element's content navigable, made the first time it is connected to
/// a document with a browsing context, and released with the element.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// An html_core IFrameIntegration from the runtime arena, as every
    /// container's content navigable is (dom.navigables.releaseContentNavigable
    /// returns it there).
    integration: ?*IFrameIntegration = null,
};

/// `instance`'s state, or null when it is no HTMLFrameElement - the DOM's
/// steps reach this with any element named "frame".
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The frame HTML element post-connection steps and removing steps.
    dom.mutation.registerPostConnectionStepsCallback(&postConnectionSteps) catch {};
    dom.mutation.registerRemovingStepsCallback(&removingSteps) catch {};
    // "Whenever a frame element with a non-null content navigable has its
    // src attribute set, changed, or removed".
    dom.attribute_change_steps.install("frame", &attributeChangeSteps);
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);
    // The DOM's removing and post-connection steps hand their callbacks a
    // NodeBase, found to be this type's by its node name - which an
    // element's naming leaves empty. Named here, as the iframe and embed
    // elements are.
    if (dom.instance_bridge.getNodeBase(instance)) |node_base| {
        if (!node_base.node_name_allocated) node_base.node_name = "FRAME";
    }
    // From the runtime arena, as the iframe's state is: an element torn
    // down with its tree may never run its own deinit.
    const arena = runtime.ArenaAllocator.get();
    const internal = try arena.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: the content navigable, if it made one, goes with
/// the element.
pub fn deinit(instance: *runtime.Instance) void {
    if (instance.stateAs(State)) |state| {
        if (state.own._internal) |internal| {
            // A second deinit must find nothing to free.
            state.own._internal = null;
            if (internal.integration) |integration| {
                internal.integration = null;
                dom.navigables.releaseContentNavigable(integration);
            }
            if (runtime.ArenaAllocator.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        }
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLFrameElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

// ============================================================================
// The DOM's steps for the element
// ============================================================================

/// The instance of `node` when it is a frame element.
fn frameOf(node: *dom.NodeBase) ?*runtime.Instance {
    if (node.node_type != 1 or !std.ascii.eqlIgnoreCase(node.node_name, "frame")) return null;
    const ptr = dom.instance_bridge.getInstance(node) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
    if (getInternal(instance) == null) return null;
    return instance;
}

/// The frame HTML element post-connection steps, given `node`.
fn postConnectionSteps(node: *dom.NodeBase) void {
    const element = frameOf(node) orelse return;
    if (!(interfaces.Node.get_isConnected(element) catch false)) return;
    // Step 1: "If insertedNode's node document's browsing context is null,
    // then return."
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    // Step 2: "Create a new child navigable for insertedNode."
    const integration = createChildNavigable(element) orelse return;
    // Step 3: "Process the frame attributes for insertedNode, with
    // initialInsertion set to true."
    dom.navigables.processFrameAttributes(element, integration, true);
}

/// The frame HTML element removing steps: "destroy a child navigable given
/// removedNode".
fn removingSteps(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    _ = old_parent;
    const element = frameOf(node) orelse return;
    const internal = getInternal(element) orelse return;
    const integration = internal.integration orelse return;
    if (integration.state == .discarded or integration.browsing_context == null) return;
    dom.navigables.destroyChildNavigable(element, integration);
}

/// "Whenever a frame element with a non-null content navigable has its src
/// attribute set, changed, or removed, the user agent must process the
/// frame attributes."
fn attributeChangeSteps(
    element: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    _ = old_value;
    _ = value;
    if (namespace != null or !std.mem.eql(u8, local_name, "src")) return;
    const internal = getInternal(element) orelse return;
    const integration = internal.integration orelse return;
    if (integration.state == .discarded or integration.browsing_context == null) return;
    dom.navigables.processFrameAttributes(element, integration, false);
}

/// HTML "create a new child navigable" for `element` (dom.navigables): its
/// content navigable, made now - or made again after an earlier one was
/// destroyed, whose realm is retired first - with the name attribute's
/// value as its target name, "if present when the element's content
/// navigable is created". Null when none could be made.
fn createChildNavigable(element: *runtime.Instance) ?*IFrameIntegration {
    const internal = getInternal(element) orelse return null;
    const integration = internal.integration orelse blk: {
        const made = runtime.ArenaAllocator.get().create(IFrameIntegration) catch return null;
        made.* = IFrameIntegration.init(internal.allocator);
        internal.integration = made;
        break :blk made;
    };
    // Still showing its navigable (connected again without having left).
    if (integration.state != .discarded and integration.hasRealmContext() and integration.browsing_context != null) return integration;
    // A navigable destroyed earlier: its realm is retired, and a new one made.
    if (integration.state == .discarded or integration.hasRealmContext()) {
        integration.retireRealmContext() catch return null;
    }
    if (!dom.navigables.createChildNavigable(element, integration)) return null;
    if (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("name")) catch null) |name| {
        if (name.len() > 0) {
            integration.setName(name.asSlice()) catch {};
            dom.navigables.registerNamedProperty(integration, name.asSlice());
        }
    }
    return integration;
}

// ============================================================================
// IDL members
// ============================================================================

/// Getter for contentDocument: this's content document - its content
/// navigable's active document, when same origin-domain with this's node
/// document.
pub fn get_contentDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const integration = internal.integration orelse return null;
    if (integration.browsing_context == null) return null;
    return dom.navigables.contentDocument(integration, integration.container_origin);
}

/// Getter for contentWindow: this's content window - its content
/// navigable's active WindowProxy.
pub fn get_contentWindow(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return null;
    const integration = internal.integration orelse return null;
    if (integration.browsing_context == null) return null;
    return dom.navigables.contentWindow(integration);
}
