//! HTML 4.2.6 "update a style block", for a style element - HTML's, and
//! SVG's, whose "semantics and processing" SVG 2 15.3 makes HTML's: one
//! algorithm, which each element's own impl runs on the StyleBlock it keeps
//! (no impl is named here). Moved unchanged out of the HTMLStyleElement impl
//! (lane quick1 b4); the times it runs - insertion, removal, children
//! changed, the parser's pop - are the elements' own steps.
//!
//! Step 5, Content Security Policy's inline check, is
//! dom.csp_violations.shouldBlockInline; a blocked block fires `error`.
//! Step 6 creates the element's CSS style sheet (dom.style.SheetRecord,
//! which the element owns and the document's style engine applies); step 2
//! removes it. Its loading - critical subresources, the load or error
//! event, the delays - is style_sheet_loading's.
//!
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;
const style_sheet_loading = @import("style_sheet_loading.zig");

const log = std.log.scoped(.style);

/// A style element's style block: what "update a style block" keeps.
pub const StyleBlock = struct {
    /// The load of the element's style sheet (`style_sheet_loading`), by id,
    /// while it fetches its critical subresources or its event waits; 0 when
    /// there is none. It stands for the associated CSS style sheet.
    load: u64 = 0,
    /// The HTML parser made the element and has not yet popped it off its
    /// stack of open elements: until it does, the element is not updated.
    parser_inserting: bool = false,
    parser_document: ?*runtime.Instance = null,
    parser_document_generation: u64 = 0,
    /// Where its text starts in its document, when the parser made it: a
    /// CSP violation of its style block is located there when no script is
    /// running (Blink's StyleElement start_position_, passed to
    /// ContentSecurityPolicy::AllowInline; targeting-for-inline-style.html
    /// 20:20, all three browsers).
    start: ?dom_module.style_sheet_owners.Position = null,
    /// The element's associated CSS style sheet ("create a CSS style
    /// sheet", step 6), owned; null when it has none.
    sheet: ?*dom_module.style.SheetRecord = null,
    /// The document whose style engine applies it, and that document's
    /// generation when it was registered.
    sheet_document: ?*runtime.Instance = null,
    sheet_document_generation: u64 = 0,
};

/// HTML "update a style block", for `element` and its style block.
pub fn update(element: *runtime.Instance, internal: *StyleBlock) void {
    // 1. Let element be the style element.
    // 2. If element has an associated CSS style sheet, remove the CSS style
    // sheet in question. A load still fetching its critical subresources
    // ends; an event already queued for it still fires.
    const previous_load = internal.load;
    internal.load = 0;
    defer if (previous_load != 0) style_sheet_loading.abandon(element, previous_load);
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
    if (dom_module.csp_violations.shouldBlockInline(element, .style, text, .{ .nonce = nonceOf(element), .position = internal.start })) {
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
fn createSheet(element: *runtime.Instance, internal: *StyleBlock, document: *runtime.Instance, text: []const u8) !void {
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
pub fn removeSheet(element: *runtime.Instance, internal: *StyleBlock) void {
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
