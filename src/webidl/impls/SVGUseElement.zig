//! Implementation for SVGUseElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGUseElement = interfaces.SVGUseElement;
const dom = @import("dom");
const resources = dom.style.engine.resource_loading.svg_resources;

pub const State = SVGUseElement.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    load: ?*resources.UseLoad = null,
    pub fn deinit(self: *InternalState) void {
        const load = self.load;
        self.load = null;
        if (load) |value| value.destroy();
    }
};
const Registry = runtime.InstanceRegistry(.svg_use_element, InternalState);

pub fn installHooks() void {
    resources.installAttributeSteps();
    dom.style.hooks.install(.{
        .svg_use_resource_changed = resourceChanged,
        .svg_parse_resource_document = parseResourceDocument,
    });
    dom.mutation.registerInsertionStepsCallback(insertionSteps) catch {};
    dom.mutation.registerRemovingStepsCallback(removingSteps) catch {};
    dom.adopting_steps.install(adoptingSteps);
    dom.orphan_states.installRegistrySweep(Registry);
    dom.document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareAbort, .abort = abortDocument });
}

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

/// One decoder adapter (liaison Q18). Switch to the strict shared
/// xml_document_encoding.decodeDocumentBytes after the authorized row-113
/// dependency merge. The BASE path already selects BOM/transport/XML encoding.
fn parseResourceDocument(document: *runtime.Instance, bytes: []const u8, content_type: []const u8) !bool {
    const xml_parser = @import("html").xml_document_parser;
    const sniffing = @import("html_core").parser.encoding_sniffing;
    const allocator = document.ctx.allocator;
    const transport = sniffing.transportEncoding(allocator, content_type);
    // SVG 2 secure-static documents still obey XML 1.0 §4.3.3: malformed
    // encoded input is fatal, rather than a replacement character stream.
    const decoded = (try @import("html").xml_document_encoding.decodeDocumentBytes(allocator, bytes, transport)) orelse return false;
    defer allocator.free(decoded.text);
    try dom.document_internals.setEncoding(document, sniffing.canonicalName(decoded.encoding));
    return (try xml_parser.parseInto(document, decoded.text, .{ .scripting = false })) == null;
}

fn resourceChanged(instance: *runtime.Instance) void {
    const internal = Registry.get(instance) orelse return;
    const source = resources.href(instance) orelse {
        if (internal.load) |load| load.cancel();
        return;
    };
    if (internal.load == null) internal.load = resources.UseLoad.create(instance) catch return;
    internal.load.?.start(source) catch {};
}

fn insertionSteps(node: *dom.NodeBase) void {
    if (node.node_type != dom.NodeBase.ELEMENT_NODE or !node.is_connected) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    if (Registry.get(instance) == null) return;
    resourceChanged(instance);
}

/// WebKit SVGUseElement::removingSteps detaches the external document
/// client; the document cache itself may continue to serve other references.
fn removingSteps(node: *dom.NodeBase, _: ?*dom.NodeBase) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    const internal = Registry.get(instance) orelse return;
    if (internal.load) |load| load.cancel();
}

fn adoptingSteps(instance: *runtime.Instance, _: ?*runtime.Instance) void {
    const internal = Registry.get(instance) orelse return;
    if (internal.load) |load| load.cancel();
    resourceChanged(instance);
}

fn discardRealm(realm: runtime.Context) void {
    var iterator = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (iterator.next()) |entry| if (entry.internal.load) |load| {
        if (load.realm == realm) load.cancel();
    };
}

fn prepareAbort(document: *runtime.Instance) bool {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return false;
    var marked = false;
    while (iterator.next()) |entry| if (entry.internal.load) |load| {
        marked = load.markAbort(document) or marked;
    };
    return marked;
}

fn abortDocument(document: *runtime.Instance) void {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return;
    while (iterator.next()) |entry| if (entry.internal.load) |load| load.abortMarked(document);
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
