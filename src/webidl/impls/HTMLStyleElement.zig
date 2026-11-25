//! Implementation for HTMLStyleElement interface
//!
//! Spec: HTML Standard § 4.2.6 The style element
//! https://html.spec.whatwg.org/multipage/semantics.html#the-style-element
//!
//! "Update a style block" itself is src/html/style_block.zig, which an SVG
//! style element runs too; what is here is the times it runs: when the
//! element becomes connected or disconnected, when its children change, and
//! - for an element the HTML parser made - when the parser pops it off the
//! stack of open elements, and not before (`dom.style_sheet_owners`). Each
//! update makes a new style sheet; its critical subresources (its @import
//! rules), the load or error event after them, and the delay they put on
//! the document's load event are `style_sheet_loading`'s.
//!
//! Step 5, Content Security Policy's inline check, is
//! dom.csp_violations.shouldBlockInline; a blocked block fires `error`.
//!
//! Step 6 creates the element's CSS style sheet (dom.style.SheetRecord,
//! which the element owns and the document's style engine applies - lane
//! style1); step 2 removes it. `disabled` reads and sets its disabled flag.
//!
//! `sheet` is the sheet's CSSStyleSheet object (dom.style.objects), which
//! the element keeps until the sheet is removed. A style element the parser
//! made, or one whose blocking attribute says `render`, blocks rendering
//! until its critical subresources are obtained (style_sheet_loading). Critical imports of parser-created stylesheets block scripts.
//! HTML names the XML parser
//! too, but Crane has none (DOMParser's XML types are a TODO): only the HTML
//! parser drivers make style elements. The fragment parser's (innerHTML)
//! elements are not marked, and update as they are inserted and filled.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLStyleElement = interfaces.HTMLStyleElement;

// Everything the element reads of its HTMLElement, Element and Node state,
// it reads through the generated interfaces: no impl is named here. The
// load of its style sheet is HTML's (src/html/style_sheet_loading.zig).
const style_sheet_loading = @import("html").style_sheet_loading;
// "Update a style block", which an SVG style element runs too.
const style_block = @import("html").style_block;

// The hooks the element installs its steps into: the insertion, removing
// and children changed steps (DOM 4.2.3), and dom.style_sheet_owners - the
// load delay its style sheets put on their document, and the parser's word
// that it made and popped the element.
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

const log = std.log.scoped(.style);

pub const State = HTMLStyleElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The element's own state: its style block (src/html/style_block.zig),
/// which an SVG style element has too.
pub const InternalState = style_block.StyleBlock;

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom_module.style_sheet_owners.installLoadDelay(.{ .delays = &style_sheet_loading.delaysLoadEvent, .blocks_scripts = &style_sheet_loading.blocksScripts });
    dom_module.style_sheet_owners.installParserSteps(.{ .created = &createdByParser, .popped = &poppedByParser });
    dom_module.attribute_change_steps.install("style", &attributeChangeSteps);
    // The CSS style sheet the element owns, which the style engine applies.
    dom_module.style.hooks.install(.{ .style_sheet_of = &sheetOf });
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch |err| {
        log.warn("style insertion steps not registered: {}", .{err});
    };
    dom_module.mutation.registerRemovingStepsCallback(&removingSteps) catch |err| {
        log.warn("style removing steps not registered: {}", .{err});
    };
    dom_module.mutation.registerChildrenChangedCallback(&childrenChangedSteps) catch |err| {
        log.warn("style children changed steps not registered: {}", .{err});
    };
}

/// Initialize instance: the chain to HTMLElement.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);
    // From the arena that holds the element's state, as every element's
    // internal state is: teardown does not always run `deinit`.
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its style sheets' loads end with it.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        style_sheet_loading.elementGone(instance);
        style_block.removeSheet(instance, internal);
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(instance: *runtime.Instance) !void {
    _ = instance;
}

// ============================================================================
// Update a style block
// ============================================================================

/// dom.style's `style_sheet_of`.
fn sheetOf(element: *runtime.Instance) ?*dom_module.style.SheetRecord {
    const internal = getInternal(element) orelse return null;
    return internal.sheet;
}

/// The style element `node` is, if it is one: a brand check on its instance,
/// not its node name (which is "" for most elements).
fn styleOf(node: *NodeBase) ?*runtime.Instance {
    const ptr = instance_bridge.getInstance(node) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
    if (getInternal(instance) == null) return null;
    return instance;
}

/// "The element is not on the stack of open elements of an HTML parser or
/// XML parser, and it becomes connected". Called for every node inserted.
fn insertionSteps(node: *NodeBase) void {
    if (node.node_type != 1 or !node.is_connected) return;
    const instance = styleOf(node) orelse return;
    const internal = getInternal(instance) orelse return;
    if (internal.parser_inserting) return;
    style_block.update(instance, internal);
}

/// "... or disconnected". Called for every node removed.
fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.node_type != 1) return;
    const instance = styleOf(node) orelse return;
    const internal = getInternal(instance) orelse return;
    if (internal.parser_inserting) return;
    style_block.update(instance, internal);
}

/// "The element's children changed steps run." Called for every parent
/// whose children change.
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

/// dom.style_sheet_owners: "The element is popped off the stack of open
/// elements of an HTML parser".
fn poppedByParser(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    internal.parser_inserting = false;
    style_block.update(element, internal);
}

fn attributeChangeSteps(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    _ = old_value;
    const internal = getInternal(element) orelse return;
    if (namespace != null) return;
    // HTML 3.1.6: a render-blocking element whose blocking attribute no
    // longer makes it potentially render-blocking is unblocked.
    if (std.mem.eql(u8, local_name, "blocking")) {
        const parser_made = if (internal.parser_document) |d| (interfaces.Node.get_ownerDocument(element) catch null) == d else false;
        if (!style_sheet_loading.potentiallyRenderBlocking(element, parser_made)) dom_module.document_rendering.unblock(element);
        return;
    }
    // HTML lists no type change among the times "update a style block"
    // runs, but the browsers update the block when the type changes - Blink's
    // HTMLStyleElement::ParseAttribute, Gecko's HTMLStyleElement::AfterSetAttr
    // (UpdateStyleSheetInternal) - so a block whose type becomes text/css
    // gets its sheet and one whose type stops being it loses it
    // (html/semantics/document-metadata/the-style-element/style_type_change
    // .html; Chrome 157, Firefox 160 and Safari 27.2 pass). Golden rule 2.
    if (std.mem.eql(u8, local_name, "type")) {
        if (!internal.parser_inserting) style_block.update(element, internal);
        return;
    }
    if (!std.mem.eql(u8, local_name, "media")) return;
    // The associated CSS style sheet's media follows the attribute.
    if (internal.sheet) |record| {
        record.setMedia(value orelse "") catch {};
        if (internal.sheet_document) |document| dom_module.style.sheetsChanged(document);
    }
    if (interfaces.Node.get_ownerDocument(element) catch null) |document| style_sheet_loading.queueBlockingMayHaveEnded(document);
}

// ============================================================================
// Attributes
// ============================================================================

/// Getter for disabled: "If this does not have an associated CSS style
/// sheet, return false. If this's associated CSS style sheet's disabled flag
/// is set, return true. Return false."
pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const record = internal.sheet orelse return false;
    return record.disabled;
}

/// Getter for sheet (LinkStyle, CSSOM 6.3.2): "the associated CSS style
/// sheet of the node or null if there is no associated CSS style sheet" -
/// its CSSStyleSheet object, made on first read and kept by the element.
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const record = internal.sheet orelse return null;
    return try dom_module.style.objects.sheetObject(record, instance.ctx);
}

/// Setter for disabled: "If this does not have an associated CSS style
/// sheet, return. If the given value is true, set this's associated CSS
/// style sheet's disabled flag. Otherwise, unset this's associated CSS style
/// sheet's disabled flag."
pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const record = internal.sheet orelse return;
    if (record.disabled == value) return;
    record.disabled = value;
    if (internal.sheet_document) |document| dom_module.style.sheetsChanged(document);
}
