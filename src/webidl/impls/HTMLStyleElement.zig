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
//! Not modelled, stated: the style sheet is not parsed into CSSOM, so
//! `sheet` is null and `disabled` has no sheet to disable; render-blocking
//! and the script-blocking style sheet set are not kept. HTML names the XML parser
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
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom_module.style_sheet_owners.installLoadDelay(&style_sheet_loading.delaysLoadEvent);
    dom_module.style_sheet_owners.installParserSteps(.{ .created = &createdByParser, .popped = &poppedByParser });
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
    const internal = try runtime.ArenaAllocator.get().create(InternalState);
    internal.* = .{};
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its style sheets' loads end with it.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        style_sheet_loading.elementGone(instance);
        if (runtime.ArenaAllocator.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
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
    if (internal.load != 0) {
        style_sheet_loading.abandon(internal.load);
        internal.load = 0;
    }
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
    internal.load = style_sheet_loading.startStyle(element, text) orelse 0;
}

/// The element's nonce attribute, when it has a non-empty one: what CSP
/// 6.7.3.3 step 2 matches nonce-sources against. Borrowed from the
/// attribute, for the check.
fn nonceOf(element: *runtime.Instance) ?[]const u8 {
    const nonce = (interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned("nonce")) catch null) orelse return null;
    const value = nonce.asSlice();
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
}

/// dom.style_sheet_owners: "The element is popped off the stack of open
/// elements of an HTML parser".
fn poppedByParser(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    internal.parser_inserting = false;
    updateStyleBlock(element);
}

// ============================================================================
// Attributes
// ============================================================================

/// Getter for disabled: "If this does not have an associated CSS style
/// sheet, return false." Style sheets are not parsed into CSSOM, so there is
/// none to be disabled.
pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return false;
}

/// Getter for sheet: the associated CSS style sheet - not parsed into CSSOM
/// (see the file comment).
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Setter for disabled: "If this does not have an associated CSS style
/// sheet, return."
pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
}
