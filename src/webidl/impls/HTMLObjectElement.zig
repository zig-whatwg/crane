//! Implementation for HTMLObjectElement interface (HTML 4.8.7).
//!
//! An object element fetches its data URL and represents what came back: an
//! image, a child navigable for a document, or its fallback content -
//! "(re)determine what the object element represents", run as a task
//! whenever the parser pops the element, it is inserted or removed, or its
//! data or type attribute changes. The processing is shared with the embed
//! element (src/html/embedded_content.zig); this impl holds the element's
//! record and hears the DOM's steps for it. The reflected attributes (data,
//! type, name, width, height) are the generated interface's.
//!
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const embedded_content = @import("html").embedded_content;
const HTMLObjectElement = interfaces.HTMLObjectElement;

pub const State = HTMLObjectElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The element's processing record (src/html/embedded_content.zig), made
/// with the element and handed back when it goes.
pub const InternalState = struct {
    content: *embedded_content.Content,
};

/// `instance`'s state, or null when it is no HTMLObjectElement - the DOM's
/// steps reach this with any element named "object".
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    embedded_content.installDocumentAbort();
    // "The element is popped off the stack of open elements of an HTML
    // parser": its children - the fallback content - are parsed.
    dom.finish_parsing_children.install("object", .{ .created = &createdByParser, .finished = &finishedParsingChildren });
    // "Inserted into a document or removed from a document".
    dom.mutation.registerPostConnectionStepsCallback(&postConnectionSteps) catch {};
    dom.mutation.registerRemovingStepsCallback(&removingSteps) catch {};
    // "Its data attribute is set, changed, or removed", and its type.
    dom.attribute_change_steps.install("object", &attributeChangeSteps);
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
    // The DOM's insertion, removing and post-connection steps hand their
    // callbacks a NodeBase, found to be this type's by its node name - which
    // an element's naming leaves empty. Named here, as the iframe and script
    // elements are.
    if (dom.instance_bridge.getNodeBase(instance)) |node_base| {
        if (!node_base.node_name_allocated) node_base.node_name = "OBJECT";
    }
    // From the runtime arena, as the iframe's state is: an element torn
    // down with its tree may never run its own deinit.
    const arena = runtime.ArenaAllocator.get();
    const internal = try arena.create(InternalState);
    errdefer arena.destroy(InternalState, internal);
    internal.* = .{
        .content = try embedded_content.create(allocator, instance, .object),
    };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    if (instance.stateAs(State)) |state| {
        if (state.own._internal) |internal| {
            // A second deinit must find nothing to free.
            state.own._internal = null;
            embedded_content.elementGone(internal.content);
            if (runtime.ArenaAllocator.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        }
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLObjectElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

// ============================================================================
// The DOM's steps for the element
// ============================================================================

fn createdByParser(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    embedded_content.createdByParser(internal.content);
}

fn finishedParsingChildren(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    embedded_content.finishedParsingChildren(internal.content);
}

/// The instance of `node` when it is an object element.
fn objectOf(node: *dom.NodeBase) ?*InternalState {
    if (node.node_type != 1 or !std.ascii.eqlIgnoreCase(node.node_name, "object")) return null;
    const ptr = dom.instance_bridge.getInstance(node) orelse return null;
    return getInternal(@ptrCast(@alignCast(ptr)));
}

fn postConnectionSteps(node: *dom.NodeBase) void {
    const internal = objectOf(node) orelse return;
    if (!(interfaces.Node.get_isConnected(internal.content.element) catch false)) return;
    embedded_content.inserted(internal.content);
}

fn removingSteps(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    _ = old_parent;
    const internal = objectOf(node) orelse return;
    embedded_content.removed(internal.content);
}

fn attributeChangeSteps(
    element: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    _ = old_value;
    _ = value;
    if (namespace != null) return;
    const internal = getInternal(element) orelse return;
    embedded_content.attributeChanged(internal.content, local_name);
}

// ============================================================================
// IDL members
// ============================================================================

/// Getter for form
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// The contentDocument getter steps: "return this's content document".
pub fn get_contentDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return embedded_content.contentDocument(internal.content);
}

/// The contentWindow getter steps: "return this's content window".
pub fn get_contentWindow(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return null;
    return embedded_content.contentWindow(internal.content);
}

/// Getter for willValidate
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for validity
pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for validationMessage
pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    _ = instance;
    _ = @"error";
    return error.NotImplemented;
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getSVGDocument - this's content document, if it was made for
/// an image/svg+xml resource; otherwise null.
pub fn call_getSVGDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return embedded_content.svgDocument(internal.content);
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}
