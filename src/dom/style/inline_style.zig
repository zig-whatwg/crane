//! An element's inline style as CSSOM 6.7 and HTML 3.2.6.5 define it: the
//! declaration block of the element's style attribute, which
//! `element.style` reads and writes.
//!
//! - Attribute to block: the attribute change steps (Element's, after their
//!   Content Security Policy check) mark the block to be parsed again; it is
//!   parsed when next read. A value CSP blocked leaves the block empty.
//! - Block to attribute: CSSOM "update style attribute for" - the block
//!   serialized, set as the attribute with the block's updating flag set, so
//!   that the attribute change steps do not parse it back (and the
//!   mutation records and custom element reactions are DOM's, as in the
//!   browsers).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#dom-elementcssinlinestyle-style
//! Spec: https://drafts.csswg.org/cssom-1/#update-style-attribute-for
//! Spec: https://html.spec.whatwg.org/multipage/dom.html#the-style-attribute

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const css = @import("css");
const element_data = @import("../element_data.zig");
const element_attributes = @import("../element_attributes.zig");
const document_internals = @import("../document_internals.zig");
const interfaces = @import("interfaces");
const element_style = @import("element_style.zig");
const engine = @import("engine.zig");

const DeclarationBlock = css.declarations.DeclarationBlock;

fn quirksOf(element: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    return document_internals.getMode(document) == .quirks;
}

/// The element's inline declaration block, parsed now if its attribute
/// changed; null for an instance with no style state.
pub fn blockOf(element: *runtime.Instance) Allocator.Error!?*DeclarationBlock {
    const state = element_style.of(element) orelse return null;
    switch (state.inline_state) {
        .parsed => {},
        .blocked => {},
        .unparsed => {
            const data = element_data.of(element) orelse return null;
            const value = if (data.findAttribute(null, "style")) |entry| entry.value else "";
            try engine.reparseInline(element, state, value, quirksOf(element));
        },
    }
    if (state.inline_block == null) state.inline_block = DeclarationBlock.init(state.allocator);
    return &state.inline_block.?;
}

/// The parse options for the element's inline block.
pub fn parseOptions(element: *runtime.Instance) css.properties.ParseOptions {
    const state = element_style.of(element);
    return .{ .allocator = if (state) |s| s.allocator else element.ctx.allocator, .quirks = quirksOf(element) };
}

/// CSSOM "update style attribute for": the block, serialized, becomes the
/// style attribute's value, with the updating flag set while it is set.
pub fn updateStyleAttribute(element: *runtime.Instance) (Allocator.Error || element_attributes.Error)!void {
    const state = element_style.of(element) orelse return;
    const block = if (state.inline_block) |*b| b else return;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(state.allocator);
    try block.serialize(&text);
    // "Set declaration block's updating flag. Set an attribute value for
    // owner node using "style" and the result of serializing declaration
    // block. Unset declaration block's updating flag."
    state.updating = true;
    defer state.updating = false;
    try element_attributes.set(element, "style", text.items, .{});
    // A CSP-blocked value's block is the CSSOM's again once CSSOM wrote it.
    if (state.inline_state == .blocked) state.inline_state = .parsed;
}

/// The serialized value of property `name` in the element's inline block,
/// or null when it has none. Owned by `allocator`.
pub fn inlineValue(element: *runtime.Instance, name: []const u8, allocator: Allocator) Allocator.Error!?[]u8 {
    const block = (try blockOf(element)) orelse return null;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var scratch: std.ArrayList(u8) = .empty;
    defer scratch.deinit(block.allocator);
    try block.getPropertyValue(name, &scratch);
    if (scratch.items.len == 0) return null;
    try out.appendSlice(allocator, scratch.items);
    return try out.toOwnedSlice(allocator);
}
