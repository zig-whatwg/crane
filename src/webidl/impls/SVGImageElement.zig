//! Implementation for SVGImageElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGImageElement = interfaces.SVGImageElement;
const dom = @import("dom");
const images = dom.style.engine.available_images;
const resources = dom.style.engine.resource_loading.svg_resources;

pub const State = SVGImageElement.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    loader: ?*images.Loader = null,

    pub fn deinit(self: *InternalState) void {
        const loader = self.loader;
        self.loader = null;
        if (loader) |value| value.destroy();
    }
};
const Registry = runtime.InstanceRegistry(.svg_image_element, InternalState);

pub fn installHooks() void {
    resources.installAttributeSteps();
    dom.style.hooks.install(.{ .svg_image_resource_changed = resourceChanged });
    dom.mutation.registerInsertionStepsCallback(insertionSteps) catch {};
    dom.adopting_steps.install(adoptingSteps);
    dom.orphan_states.installRegistrySweep(Registry);
    dom.document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareAbort, .abort = abortDocument });
}

/// The generated SVGGraphicsElement construction/destruction chain owns
/// the ancestors. This registry owns only this element's resource state.
pub fn initOwn(instance: *runtime.Instance, _: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = .{};
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| internal.deinit();
    if (instance.stateAs(State)) |state| state.own._internal = null;
    Registry.remove(instance);
}

/// SVG 2 §§12.3, 16.1.7: href changes load independently of display.
/// WebKit SVGImageElement::svgAttributeChanged and insertionSteps both
/// update ImageLoader; its document canEverRender check excludes inert XML.
fn resourceChanged(instance: *runtime.Instance) void {
    const internal = Registry.get(instance) orelse return;
    const source = resources.href(instance) orelse {
        if (internal.loader) |loader| loader.cancel();
        return;
    };
    if (internal.loader == null) internal.loader = images.Loader.create(instance) catch return;
    const data = dom.element_data.of(instance) orelse return;
    const cors = if (data.findAttribute(null, "crossorigin")) |attribute| attribute.value else null;
    internal.loader.?.start(source, .{
        .initiator = .image,
        .cors = images.CorsSetting.fromAttribute(cors),
        .invalid_source = .queue_error,
    }) catch {};
}

fn insertionSteps(node: *dom.NodeBase) void {
    if (node.node_type != dom.NodeBase.ELEMENT_NODE or !node.is_connected) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    const internal = Registry.get(instance) orelse return;
    // An href set while detached may already have started. Insertion must
    // not duplicate it; an inert document's attempt has no document owner.
    if (internal.loader) |loader| if (loader.document != null) return;
    resourceChanged(instance);
}

fn adoptingSteps(instance: *runtime.Instance, _: ?*runtime.Instance) void {
    const internal = Registry.get(instance) orelse return;
    if (internal.loader) |loader| loader.cancel();
    resourceChanged(instance);
}

fn discardRealm(realm: runtime.Context) void {
    var iterator = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (iterator.next()) |entry| if (entry.internal.loader) |loader| {
        if (loader.realm == realm) loader.cancel();
    };
}

fn prepareAbort(document: *runtime.Instance) bool {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return false;
    var marked = false;
    while (iterator.next()) |entry| if (entry.internal.loader) |loader| {
        marked = loader.markAbort(document) or marked;
    };
    return marked;
}

fn abortDocument(document: *runtime.Instance) void {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return;
    while (iterator.next()) |entry| if (entry.internal.loader) |loader| loader.abortMarked(document);
}

/// Getter for x
pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for preserveAspectRatio
pub fn get_preserveAspectRatio(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const data = dom.element_data.of(instance) orelse return null;
    const attribute = data.findAttribute(null, "crossorigin") orelse return null;
    return runtime.DOMString.initInterned(if (images.CorsSetting.fromAttribute(attribute.value) == .use_credentials) "use-credentials" else "anonymous");
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (value) |text| try dom.element_attributes.set(instance, "crossorigin", text.asSlice(), .{}) else dom.element_attributes.remove(instance, null, "crossorigin");
}
