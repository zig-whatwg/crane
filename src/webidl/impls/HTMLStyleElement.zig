//! Implementation for HTMLStyleElement interface
//!
//! Spec: HTML Standard § 4.2.6 The style element
//! https://html.spec.whatwg.org/multipage/semantics.html#the-style-element
//!
//! What is here is "update a style block" and the times it runs: when the
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

/// The element's own state.
pub const InternalState = struct {
    /// The load of the element's style sheet (`style_sheet_loading`), by id,
    /// while it fetches its critical subresources or its event waits; 0 when
    /// there is none. It stands for the associated CSS style sheet.
    load: u64 = 0,
    /// The HTML parser made the element and has not yet popped it off its
    /// stack of open elements: until it does, the element is not updated.
    parser_inserting: bool = false,
    parser_document: ?*runtime.Instance = null,
    parser_document_generation: u64 = 0,
    /// The element's associated CSS style sheet ("create a CSS style
    /// sheet", step 6), owned; null when it has none.
    sheet: ?*dom_module.style.SheetRecord = null,
    /// The document whose style engine applies it, and that document's
    /// generation when it was registered.
    sheet_document: ?*runtime.Instance = null,
    sheet_document_generation: u64 = 0,
};

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
        removeSheet(instance, internal);
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLStyleElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

// ============================================================================
// Update a style block
// ============================================================================

/// HTML "update a style block".
fn updateStyleBlock(element: *runtime.Instance) void {
    // 1. Let element be the style element.
    const internal = getInternal(element) orelse return;
    // 2. If element has an associated CSS style sheet, remove the CSS style
    // sheet in question. A load still fetching its critical subresources
    // ends; an event already queued for it still fires.
    const previous_load = internal.load;
    internal.load = 0;
    defer if (previous_load != 0) style_sheet_loading.abandon(previous_load);
    removeSheet(element, internal);
    // 3. If element is not connected, then return.
    if (!(interfaces.Node.get_isConnected(element) catch false)) return;
    // 4. If element's type attribute is present and its value is neither the
    // empty string nor an ASCII case-insensitive match for "text/css", then
    // return. ("text/css; charset=utf-8" returns here too.)
    if (interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned("type")) catch null) |type_attr| {
        const value = type_attr.asSlice();
        if (value.len != 0 and !std.ascii.eqlIgnoreCase(value, "text/css")) return;
    }
    const text = childTextContent(element) catch |err| {
        log.warn("style block not updated: {}", .{err});
        return;
    };
    defer element.ctx.allocator.free(text);
    // 5. "If the Should element's inline behavior be blocked by Content
    // Security Policy? algorithm returns "Blocked" when executed upon
    // element, "style", and element's child text content, then return."
    // The element is nonceable when it has a nonce attribute (CSP 6.7.3.1
    // step 1; steps 2-3 concern script elements and the parser). A blocked
    // block fires error, as a failed sheet would (startBlockedStyle states
    // that deviation).
    if (dom_module.csp_violations.shouldBlockInline(element, .style, text, .{ .nonce = nonceOf(element) })) {
        internal.load = style_sheet_loading.startBlockedStyle(element) orelse 0;
        return;
    }
    // 6. Create a CSS style sheet - its text, the element's child text
    // content - and, once its critical subresources are fetched, queue the
    // task that fires load or error at the element.
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    createSheet(element, internal, document, text) catch |err| log.warn("style sheet not created: {}", .{err});
    const parser_created = internal.parser_document == document and
        runtime.SlabAllocator.generationOf(document) == internal.parser_document_generation;
    internal.load = style_sheet_loading.startStyle(element, text, parser_created) orelse 0;
}

/// HTML "create a CSS style sheet" (step 6): type text/css, owner node the
/// element, media its media attribute, title its title attribute when it is
/// in a document tree, location null (its base URL is the document's), and
/// the origin-clean flag set. CSSOM's "add a CSS style sheet" is the
/// document's style engine's, which the element registers with.
fn createSheet(element: *runtime.Instance, internal: *InternalState, document: *runtime.Instance, text: []const u8) !void {
    const allocator = element.ctx.allocator;
    const media = attributeValue(element, "media");
    defer if (media) |m| allocator.free(m);
    var root = instance_bridge.getNodeBase(element);
    while (root) |r| : (root = r.parent_node) if (r.parent_node == null) break;
    const in_document_tree = if (root) |r| r.node_type == NodeBase.DOCUMENT_NODE else false;
    const title = if (in_document_tree) attributeValue(element, "title") else null;
    defer if (title) |t| allocator.free(t);
    const base = interfaces.Node.get_baseURI(document) catch null;
    defer if (base) |b| document.ctx.allocator.free(b);
    const record = try dom_module.style.SheetRecord.create(allocator, text, .{
        .owner_node = element,
        .title = title orelse "",
        .media = media orelse "",
        .base_url = base orelse "",
        .mode = .{ .quirks = dom_module.document_internals.getMode(document) == .quirks },
    });
    internal.sheet = record;
    internal.sheet_document = document;
    internal.sheet_document_generation = runtime.SlabAllocator.generationOf(document);
    if (dom_module.style.engine.engineOf(document)) |engine| try engine.addOwner(element);
}

/// HTML step 2, "remove the CSS style sheet in question" (CSSOM "remove a
/// CSS style sheet"): out of the document's sheets, and freed.
fn removeSheet(element: *runtime.Instance, internal: *InternalState) void {
    const record = internal.sheet orelse return;
    internal.sheet = null;
    if (internal.sheet_document) |document| {
        if (runtime.SlabAllocator.generationOf(document) == internal.sheet_document_generation) {
            if (dom_module.style.engine.engineOf(document)) |engine| engine.removeOwner(element);
        }
    }
    internal.sheet_document = null;
    // CSSOM "remove a CSS style sheet" step 2: its owner node goes; the
    // element no longer keeps the sheet's object, which script may still
    // hold (and with it the sheet).
    record.detach();
    dom_module.style.objects.ownerReleased(element);
    record.unref();
}

/// dom.style's `style_sheet_of`.
fn sheetOf(element: *runtime.Instance) ?*dom_module.style.SheetRecord {
    const internal = getInternal(element) orelse return null;
    return internal.sheet;
}

/// The value of the element's attribute `name` (no namespace), owned by its
/// allocator; null when absent.
fn attributeValue(element: *runtime.Instance, name: []const u8) ?[]u8 {
    var value = (interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned(name)) catch null) orelse return null;
    defer value.deinit(element.ctx.allocator);
    return element.ctx.allocator.dupe(u8, value.asSlice()) catch null;
}

/// The element's private nonce slot: what CSP 6.7.3.3 step 2 matches
/// nonce-sources against. Borrowed until its next change, for this check.
fn nonceOf(element: *runtime.Instance) ?[]const u8 {
    const value = dom_module.attribute_change_steps.readForAttribute(element, "http://www.w3.org/1999/xhtml", "nonce") orelse return null;
    return if (value.len == 0) null else value;
}

/// DOM "child text content": the data of the element's Text node children,
/// in tree order.
fn childTextContent(element: *runtime.Instance) ![]u8 {
    const allocator = element.ctx.allocator;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var child = try interfaces.Node.get_firstChild(element);
    while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) {
        const node_type = try interfaces.Node.get_nodeType(c);
        if (node_type != interfaces.Node.get_TEXT_NODE() and node_type != interfaces.Node.get_CDATA_SECTION_NODE()) continue;
        var data = try interfaces.CharacterData.get_data(c);
        defer data.deinit(c.ctx.allocator);
        try out.appendSlice(allocator, data.asSlice());
    }
    return out.toOwnedSlice(allocator);
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
    updateStyleBlock(instance);
}

/// "... or disconnected". Called for every node removed.
fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.node_type != 1) return;
    const instance = styleOf(node) orelse return;
    const internal = getInternal(instance) orelse return;
    if (internal.parser_inserting) return;
    updateStyleBlock(instance);
}

/// "The element's children changed steps run." Called for every parent
/// whose children change.
fn childrenChangedSteps(parent: *NodeBase) void {
    if (parent.node_type != 1) return;
    const instance = styleOf(parent) orelse return;
    const internal = getInternal(instance) orelse return;
    if (internal.parser_inserting) return;
    updateStyleBlock(instance);
}

/// dom.style_sheet_owners: the HTML parser made `element`.
fn createdByParser(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    internal.parser_inserting = true;
    internal.parser_document = interfaces.Node.get_ownerDocument(element) catch null;
    internal.parser_document_generation = if (internal.parser_document) |document| runtime.SlabAllocator.generationOf(document) else 0;
}

/// dom.style_sheet_owners: "The element is popped off the stack of open
/// elements of an HTML parser".
fn poppedByParser(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    internal.parser_inserting = false;
    updateStyleBlock(element);
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
