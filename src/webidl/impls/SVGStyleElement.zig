//! Implementation for SVGStyleElement interface
//!
//! SVG 2 15.3 "The 'style' element": "The semantics and processing of a
//! 'style' and its attributes must be the same as is defined for the HTML
//! 'style' element." So an SVG style element runs HTML 4.2.6's "update a
//! style block" (src/html/style_block.zig, the algorithm HTMLStyleElement
//! runs) at the same times: when it becomes connected or disconnected, when
//! its children change, and - for an element the HTML parser made - when the
//! parser removes it from its stack of open elements, and not before
//! (`dom.style_sheet_owners`; Blink's SVGStyleElement is a StyleElement with
//! created_by_parser_ and FinishParsingChildren). Its sheet is in
//! document.styleSheets (dom.style's `svg_style_sheet_of`), its `sheet`
//! is LinkStyle's, and `type`, `media` and `title` reflect their content
//! attributes (SVG 2 15.3's IDL: "reflect").
//!
//! Spec: https://svgwg.org/svg2-draft/styling.html#StyleElement

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGStyleElement = interfaces.SVGStyleElement;

const style_sheet_loading = @import("html").style_sheet_loading;
const style_block = @import("html").style_block;

const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

const log = std.log.scoped(.style);

const svg_namespace = "http://www.w3.org/2000/svg";

pub const State = SVGStyleElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The element's own state: its style block, as an HTML style element's.
pub const InternalState = style_block.StyleBlock;

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start.
pub fn installHooks() void {
    dom_module.style_sheet_owners.installSvgStyleParserSteps(.{ .created = &createdByParser, .popped = &poppedByParser });
    // The associated CSS style sheet's media follows the attribute (HTML
    // 4.2.6, by SVG 2 15.3). The step is the SVG namespace's for `media`;
    // it leaves alone every element that is not an SVG style element.
    dom_module.attribute_change_steps.installForAttribute(svg_namespace, "media", .{ .change = &mediaChanged });
    dom_module.style.hooks.install(.{ .svg_style_sheet_of = &sheetOf });
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch |err| {
        log.warn("SVG style insertion steps not registered: {}", .{err});
    };
    dom_module.mutation.registerRemovingStepsCallback(&removingSteps) catch |err| {
        log.warn("SVG style removing steps not registered: {}", .{err});
    };
    dom_module.mutation.registerChildrenChangedCallback(&childrenChangedSteps) catch |err| {
        log.warn("SVG style children changed steps not registered: {}", .{err});
    };
}

/// Its own construction steps, after SVGElement's: an empty style block,
/// from the arena that holds the element's state (teardown does not always
/// run `deinitOwn`), as HTMLStyleElement's.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = args;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(StateType).own._internal = internal;
}

/// Its own teardown, before SVGElement's: its style sheet's load ends and
/// its sheet goes.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        style_sheet_loading.elementGone(instance);
        style_block.removeSheet(instance, internal);
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
}

/// dom.style's `svg_style_sheet_of`.
fn sheetOf(element: *runtime.Instance) ?*dom_module.style.SheetRecord {
    const internal = getInternal(element) orelse return null;
    return internal.sheet;
}

/// The SVG style element `node` is, if it is one: a brand check on its
/// instance.
fn styleOf(node: *NodeBase) ?*runtime.Instance {
    const ptr = instance_bridge.getInstance(node) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
    if (getInternal(instance) == null) return null;
    return instance;
}

/// "The element is not on the stack of open elements of an HTML parser or
/// XML parser, and it becomes connected".
fn insertionSteps(node: *NodeBase) void {
    if (node.node_type != 1 or !node.is_connected) return;
    const instance = styleOf(node) orelse return;
    const internal = getInternal(instance) orelse return;
    if (internal.parser_inserting) return;
    style_block.update(instance, internal);
}

/// "... or disconnected".
fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.node_type != 1) return;
    const instance = styleOf(node) orelse return;
    const internal = getInternal(instance) orelse return;
    if (internal.parser_inserting) return;
    style_block.update(instance, internal);
}

/// "The element's children changed steps run."
fn childrenChangedSteps(parent: *NodeBase, _: dom_module.mutation.ChildrenChange) void {
    if (parent.node_type != 1) return;
    const instance = styleOf(parent) orelse return;
    const internal = getInternal(instance) orelse return;
    if (internal.parser_inserting) return;
    style_block.update(instance, internal);
}

/// dom.style_sheet_owners: the HTML parser made `element`, whose text starts
/// at `start` in its document.
fn createdByParser(element: *runtime.Instance, start: ?dom_module.style_sheet_owners.Position) void {
    const internal = getInternal(element) orelse return;
    internal.parser_inserting = true;
    internal.start = start;
    internal.parser_document = interfaces.Node.get_ownerDocument(element) catch null;
    internal.parser_document_generation = if (internal.parser_document) |document| runtime.SlabAllocator.generationOf(document) else 0;
}

/// dom.style_sheet_owners: the parser removed `element` from its stack of
/// open elements, its children parsed.
fn poppedByParser(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    if (!internal.parser_inserting) return;
    internal.parser_inserting = false;
    style_block.update(element, internal);
}

/// The SVG namespace's `media` attribute change steps.
fn mediaChanged(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    _ = local_name;
    _ = old_value;
    if (namespace != null) return;
    const internal = getInternal(element) orelse return;
    const record = internal.sheet orelse return;
    record.setMedia(value orelse "") catch {};
    if (internal.sheet_document) |document| dom_module.style.sheetsChanged(document);
}

// ============================================================================
// Attributes
// ============================================================================

/// The value of the content attribute `name` (no namespace), "" when absent:
/// the getter of a reflected DOMString.
fn reflected(instance: *runtime.Instance, name: []const u8) !runtime.DOMString {
    const value = try interfaces.Element.call_getAttributeNS(instance, null, runtime.DOMString.initInterned(name));
    return value orelse runtime.DOMString.initInterned("");
}

fn setReflected(instance: *runtime.Instance, name: []const u8, value: runtime.DOMString) !void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned(name), .{ .domstring = value });
}

/// Getter for type: reflects the type content attribute.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflected(instance, "type");
}

/// Getter for media: reflects the media content attribute.
pub fn get_media(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflected(instance, "media");
}

/// Getter for title: reflects the title content attribute.
pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflected(instance, "title");
}

/// Getter for disabled, as HTMLStyleElement's: "If this does not have an
/// associated CSS style sheet, return false. If this's associated CSS style
/// sheet's disabled flag is set, return true. Return false."
pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const record = internal.sheet orelse return false;
    return record.disabled;
}

/// Getter for sheet (LinkStyle, CSSOM 6.3.2): the associated CSS style
/// sheet's CSSStyleSheet object, or null.
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const record = internal.sheet orelse return null;
    return try dom_module.style.objects.sheetObject(record, instance.ctx);
}

/// Setter for type: reflects.
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setReflected(instance, "type", value);
}

/// Setter for media: reflects.
pub fn set_media(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setReflected(instance, "media", value);
}

/// Setter for title: reflects.
pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setReflected(instance, "title", value);
}

/// Setter for disabled, as HTMLStyleElement's: "If this does not have an
/// associated CSS style sheet, return. If the given value is true, set this's
/// associated CSS style sheet's disabled flag. Otherwise, unset this's
/// associated CSS style sheet's disabled flag."
pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const record = internal.sheet orelse return;
    if (record.disabled == value) return;
    record.disabled = value;
    if (internal.sheet_document) |document| dom_module.style.sheetsChanged(document);
}
