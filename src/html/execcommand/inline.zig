//! The Editing spec's inline formatting commands (specs/w3c/execCommand.md,
//! "Inline formatting commands"): backColor, bold, createLink, fontName,
//! fontSize, foreColor, hiliteColor, italic, removeFormat, strikethrough,
//! subscript, superscript, underline and unlink - their actions, states,
//! values and indeterminacy, on the spec's shared machinery: effective and
//! specified command values, (loosely) equivalent values, modifiable and
//! simple modifiable elements, clear the value, push down values, force the
//! value, reorder modifiable descendants and set the selection's value.
//!
//! No layout: every "resolved value" is the computed style's
//! (style_values.zig), and the DOM is read and changed through the
//! generated interfaces and the common definitions (common.zig).
//!
//! The values these algorithms pass around are strings or null (`Value`);
//! they live in the command's scratch arena (Edit.scratch).
//!
//! Mechanism references for where the spec is silent: the spec's reference
//! implementation (WPT editing/include/implementation.js, the spec
//! editor's), which the WPT expectations were generated from.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dom = @import("dom");
const common = @import("common.zig");
const wrap_mod = @import("wrap.zig");
const split_parent = @import("split_parent.zig");
const style_values = @import("style_values.zig");
const overrides = @import("overrides.zig");

const Edit = common.Edit;
const Instance = common.Instance;
const Point = common.Point;
const DOMString = runtime.DOMString;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.editing);

/// A command value: a string, or null.
pub const Value = ?[]const u8;

/// The inline formatting commands.
pub const Command = enum {
    back_color,
    bold,
    create_link,
    font_name,
    font_size,
    fore_color,
    hilite_color,
    italic,
    remove_format,
    strikethrough,
    subscript,
    superscript,
    underline,
    unlink,

    /// "relevant CSS property".
    pub fn relevantProperty(self: Command) ?[]const u8 {
        return switch (self) {
            .back_color, .hilite_color => "background-color",
            .bold => "font-weight",
            .font_name => "font-family",
            .font_size => "font-size",
            .fore_color => "color",
            .italic => "font-style",
            else => null,
        };
    }

    /// "inline command activated values".
    pub fn activatedValues(self: Command) ?[]const []const u8 {
        return switch (self) {
            .bold => &.{ "bold", "600", "700", "800", "900" },
            .italic => &.{ "italic", "oblique" },
            .strikethrough => &.{"line-through"},
            .subscript => &.{"subscript"},
            .superscript => &.{"superscript"},
            .underline => &.{"underline"},
            else => null,
        };
    }

    /// "standard inline value command".
    pub fn isStandardInlineValue(self: Command) bool {
        return switch (self) {
            .back_color, .font_name, .fore_color, .hilite_color => true,
            else => false,
        };
    }

    /// Whether the command has a state (those with inline command activated
    /// values).
    pub fn hasState(self: Command) bool {
        return self.activatedValues() != null;
    }

    /// Whether the command has a value (the standard inline value commands
    /// and fontSize).
    pub fn hasValue(self: Command) bool {
        return self.isStandardInlineValue() or self == .font_size;
    }

    /// Whether the command defines indeterminacy.
    pub fn hasIndeterm(self: Command) bool {
        return self.hasState() or self.hasValue();
    }
};

/// The order "record the values" and removeFormat's step 7 visit the
/// commands in (subscript first so it does not interfere with fontSize;
/// superscript omitted as redundant).
pub const recorded_commands = [_]Command{ .subscript, .bold, .font_name, .font_size, .fore_color, .hilite_color, .italic, .strikethrough, .underline };

// ============================================================================
// Small DOM helpers
// ============================================================================

fn scratch(edit: *Edit) Allocator {
    return edit.scratchAllocator();
}

fn isNamed(node: *Instance, name: []const u8) !bool {
    return try common.isHtmlElementNamed(node, name);
}

fn isNamedIn(node: *Instance, names: []const []const u8) !bool {
    return try common.isHtmlElementIn(node, names);
}

fn parentElement(node: *Instance) !?*Instance {
    const p = (try common.parent(node)) orelse return null;
    return if (common.isElement(p)) p else null;
}

/// The value of `element`'s attribute `name` in the scratch arena, or null.
fn attribute(edit: *Edit, element: *Instance, name: []const u8) !?[]const u8 {
    var value = (try interfaces.Element.call_getAttribute(element, DOMString.initInterned(name))) orelse return null;
    defer value.deinit(element.ctx.allocator);
    return try scratch(edit).dupe(u8, value.asSlice());
}

fn attributeCount(element: *Instance) !u32 {
    const attributes = try interfaces.Element.get_attributes(element);
    return try interfaces.NamedNodeMap.get_length(attributes);
}

/// Whether `node` is an "allowed child" of an element named `parent_name`
/// (a string parent: steps 3-5 and 9-14 of "allowed child").
pub fn isAllowedChildOfName(node: *Instance, parent_name: []const u8) !bool {
    if (common.isText(node)) return true;
    if (common.isDocument(node) or common.isDocumentFragment(node) or common.isDocumentType(node)) return false;
    if (!try common.isHtmlElement(node)) return true;
    var buffer: [64]u8 = undefined;
    const name = (try common.localNameInto(node, &buffer)) orelse return true;
    return common.allowedChildNames(parent_name, name);
}

fn splitText(edit: *Edit, node: *Instance, offset: u32) !*Instance {
    const result = try interfaces.Text.call_splitText(node, offset);
    edit.modified = true;
    return result;
}

// ============================================================================
// The active range and effective containment
// ============================================================================

/// The active range's boundary points.
pub const Bounds = struct {
    start: Point,
    end: Point,

    pub fn collapsed(self: Bounds) bool {
        return self.start.eql(self.end);
    }
};

pub fn activeBounds(edit: *Edit) !?Bounds {
    const start = (try edit.rangeStart()) orelse return null;
    const end = (try edit.rangeEnd()) orelse return null;
    return .{ .start = start, .end = end };
}

/// DOM "contained": (node, 0) after the range's start and (node, length)
/// before its end.
fn isContained(node: *Instance, bounds: Bounds) !bool {
    if ((try common.comparePoints(.{ .node = node, .offset = 0 }, bounds.start)) != .after) return false;
    const length = try common.nodeLength(node);
    return (try common.comparePoints(.{ .node = node, .offset = length }, bounds.end)) == .before;
}

/// "effectively contained".
pub fn isEffectivelyContained(node: *Instance, bounds: Bounds) anyerror!bool {
    // "if range is not collapsed, and at least one of the following holds"
    if (bounds.collapsed()) return false;
    // "node is contained in range."
    if (try isContained(node, bounds)) return true;
    // "node is range's start node, it is a Text node, and its length is
    // different from range's start offset."
    if (node == bounds.start.node and common.isText(node) and (try common.nodeLength(node)) != bounds.start.offset) return true;
    // "node is range's end node, it is a Text node, and range's end offset
    // is not 0."
    if (node == bounds.end.node and common.isText(node) and bounds.end.offset != 0) return true;
    // "node has at least one child; and all its children are effectively
    // contained in range; and either range's start node is not a
    // descendant of node or is not a Text node or range's start offset is
    // zero; and either range's end node is not a descendant of node or is
    // not a Text node or range's end offset is its end node's length."
    if (!try common.hasChildren(node)) return false;
    if (common.isDescendantOf(bounds.start.node, node) and common.isText(bounds.start.node) and bounds.start.offset != 0) return false;
    if (common.isDescendantOf(bounds.end.node, node) and common.isText(bounds.end.node) and bounds.end.offset != try common.nodeLength(bounds.end.node)) return false;
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (!try isEffectivelyContained(c, bounds)) return false;
    }
    return true;
}

/// Which effectively contained nodes a list keeps.
pub const Filter = enum { any, editable, editable_element, formattable, remove_format_candidate };

fn passes(node: *Instance, filter: Filter) !bool {
    return switch (filter) {
        .any => true,
        .editable => try common.isEditable(node),
        .editable_element => common.isElement(node) and try common.isEditable(node),
        .formattable => try isFormattableNode(node),
        .remove_format_candidate => try isRemoveFormatCandidate(node),
    };
}

/// Every node effectively contained in `bounds` that passes `filter`, in
/// tree order, descendants of a listed node included. In the scratch arena.
pub fn effectivelyContainedNodes(edit: *Edit, bounds: Bounds, filter: Filter) ![]*Instance {
    var list: std.ArrayList(*Instance) = .empty;
    if (bounds.collapsed()) return list.items;
    // Start from the highest effectively contained ancestor of the start
    // node, so a fully selected wrapper is listed before its contents.
    var node = bounds.start.node;
    while (try common.parent(node)) |p| {
        if (!try isEffectivelyContained(p, bounds)) break;
        node = p;
    }
    // Stop at the first node after the end node's subtree.
    const stop = try common.nextSkippingChildren(bounds.end.node);
    var current: ?*Instance = node;
    while (current) |n| {
        if (stop != null and n == stop.?) break;
        if ((try isEffectivelyContained(n, bounds)) and try passes(n, filter)) try list.append(scratch(edit), n);
        current = try common.nextInTreeOrder(n);
    }
    return list.items;
}

/// The first formattable node effectively contained in the active range,
/// or null.
pub fn firstFormattableNode(edit: *Edit) !?*Instance {
    const bounds = (try activeBounds(edit)) orelse return null;
    const nodes = try effectivelyContainedNodes(edit, bounds, .formattable);
    return if (nodes.len > 0) nodes[0] else null;
}

/// "formattable node": an editable visible Text node, img or br.
pub fn isFormattableNode(node: *Instance) !bool {
    if (!(common.isText(node) or (try isNamed(node, "img")) or try isNamed(node, "br"))) return false;
    return (try common.isEditable(node)) and try common.isVisible(node);
}

// ============================================================================
// Modifiable elements
// ============================================================================

/// "modifiable element".
pub fn isModifiableElement(node: *Instance) !bool {
    if (!try common.isHtmlElement(node)) return false;
    const count = try attributeCount(node);
    const has_style = try common.hasAttribute(node, "style");
    if (try isNamedIn(node, &.{ "b", "em", "i", "s", "span", "strike", "strong", "sub", "sup", "u" })) {
        if (count == 0) return true;
        if (count == 1 and has_style) return true;
    }
    if (try isNamed(node, "font")) {
        var others = count;
        for ([_][]const u8{ "style", "color", "face", "size" }) |name| {
            if (try common.hasAttribute(node, name)) others -= 1;
        }
        return others == 0;
    }
    if (try isNamed(node, "a")) {
        var others = count;
        for ([_][]const u8{ "style", "href" }) |name| {
            if (try common.hasAttribute(node, name)) others -= 1;
        }
        return others == 0;
    }
    return false;
}

/// "simple modifiable element".
pub fn isSimpleModifiableElement(edit: *Edit, node: *Instance) !bool {
    if (!try common.isHtmlElement(node)) return false;
    if (!try isNamedIn(node, &.{ "a", "b", "em", "font", "i", "s", "span", "strike", "strong", "sub", "sup", "u" })) return false;
    const count = try attributeCount(node);
    // "with no attributes."
    if (count == 0) return true;
    if (count > 1) return false;
    const has_style = try common.hasAttribute(node, "style");
    // "exactly one attribute, which is style, which sets no CSS properties"
    if (has_style and (try style_values.inlineCount(node)) == 0) return true;
    // "an a element with exactly one attribute, which is href."
    if ((try isNamed(node, "a")) and try common.hasAttribute(node, "href")) return true;
    // "a font element with exactly one attribute, which is either color,
    // face, or size."
    if ((try isNamed(node, "font")) and ((try common.hasAttribute(node, "color")) or (try common.hasAttribute(node, "face")) or try common.hasAttribute(node, "size"))) return true;
    if (!has_style) return false;
    const style_count = try style_values.inlineCount(node);
    // "a b or strong element ... sets exactly one CSS property ... which
    // is font-weight."
    if ((try isNamedIn(node, &.{ "b", "strong" })) and style_count == 1 and try style_values.inlineSetsOnly(node, "font-weight")) return true;
    // "an i or em element ... font-style."
    if ((try isNamedIn(node, &.{ "i", "em" })) and style_count == 1 and try style_values.inlineSetsOnly(node, "font-style")) return true;
    // "an a, font, or span element ... exactly one CSS property, and that
    // property is not text-decoration."
    if ((try isNamedIn(node, &.{ "a", "font", "span" })) and style_count == 1 and !try style_values.inlineSetsOnly(node, "text-decoration")) return true;
    // "an a, font, s, span, strike, or u element ... exactly one CSS
    // property, which is text-decoration, which is set to line-through or
    // underline or overline or none." (The shorthand's longhands count as
    // the one property it is.)
    if ((try isNamedIn(node, &.{ "a", "font", "s", "span", "strike", "u" })) and try style_values.inlineSetsOnly(node, "text-decoration")) {
        const value = try style_values.inlineValue(scratch(edit), node, "text-decoration");
        for ([_][]const u8{ "line-through", "underline", "overline", "none" }) |allowed| {
            if (std.mem.eql(u8, value, allowed)) return true;
        }
    }
    return false;
}

// ============================================================================
// Equivalent values
// ============================================================================

/// "equivalent values" for `command`.
pub fn areEquivalent(edit: *Edit, command: Command, a: Value, b: Value) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    const x = a.?;
    const y = b.?;
    switch (command) {
        // bold: "Either the two strings are equal, or one is "bold" and the
        // other is "700", or one is "normal" and the other is "400"."
        .bold => return std.mem.eql(u8, x, y) or pairIs(x, y, "bold", "700") or pairIs(x, y, "normal", "400"),
        // The color commands: "Either both strings are valid CSS colors and
        // have the same red, green, blue, and alpha components, or neither
        // string is a valid CSS color."
        .back_color, .fore_color, .hilite_color => return style_values.colorsEquivalent(scratch(edit), x, y),
        else => return std.mem.eql(u8, x, y),
    }
}

fn pairIs(x: []const u8, y: []const u8, p: []const u8, q: []const u8) bool {
    return (std.mem.eql(u8, x, p) and std.mem.eql(u8, y, q)) or (std.mem.eql(u8, x, q) and std.mem.eql(u8, y, p));
}

/// "loosely equivalent values": equivalent, or for fontSize a keyword
/// x-small..xxx-large and the resolved font-size of the <font size>
/// that keyword's legacy size gives.
pub fn areLooselyEquivalent(edit: *Edit, command: Command, a: Value, b: Value) bool {
    if (areEquivalent(edit, command, a, b)) return true;
    if (command != .font_size or a == null or b == null) return false;
    return keywordMatchesPixels(a.?, b.?) or keywordMatchesPixels(b.?, a.?);
}

fn keywordMatchesPixels(keyword: []const u8, pixels: []const u8) bool {
    const size = style_values.legacySizeOfKeyword(keyword) orelse return false;
    const px = style_values.parsePx(pixels) orelse return false;
    return px == style_values.legacy_size_px[size - 1];
}

fn isActivated(command: Command, value: Value) bool {
    const v = value orelse return false;
    const activated = command.activatedValues() orelse return false;
    for (activated) |candidate| if (std.mem.eql(u8, v, candidate)) return true;
    return false;
}

// ============================================================================
// Effective and specified command values
// ============================================================================

/// "effective command value" of `node_in` for `command`.
pub fn effectiveValue(edit: *Edit, node_in: *Instance, command: Command) anyerror!Value {
    var node = node_in;
    // Step 1: "If neither node nor its parent is an Element, return null."
    // Step 2: "If node is not an Element, return the effective command
    // value of its parent for command."
    if (!common.isElement(node)) {
        node = (try parentElement(node)) orelse return null;
    }
    switch (command) {
        // Step 3: the nearest a with an href, its href.
        .create_link, .unlink => {
            var current: ?*Instance = node;
            while (current) |c| : (current = try common.parent(c)) {
                if ((try isNamed(c, "a")) and try common.hasAttribute(c, "href")) return try attribute(edit, c, "href");
            }
            return null;
        },
        // Step 4: up through fully transparent backgrounds, then the
        // resolved background-color.
        .back_color, .hilite_color => {
            while (try style_values.backgroundIsTransparent(scratch(edit), node)) {
                node = (try parentElement(node)) orelse break;
            }
            return try style_values.resolved(scratch(edit), node, "background-color");
        },
        // Step 5: sub and sup ancestors among the inline ones.
        .subscript, .superscript => {
            var affected_by_subscript = false;
            var affected_by_superscript = false;
            var current: ?*Instance = node;
            while (current) |c| {
                if (!common.isInlineNode(c)) break;
                if (try isNamed(c, "sub")) {
                    affected_by_subscript = true;
                } else if (try isNamed(c, "sup")) {
                    affected_by_superscript = true;
                }
                current = try common.parent(c);
            }
            if (affected_by_subscript and affected_by_superscript) return "mixed";
            if (affected_by_subscript) return "subscript";
            if (affected_by_superscript) return "superscript";
            return null;
        },
        // Steps 6-7: text-decoration on the node or an ancestor.
        .strikethrough, .underline => {
            const word: []const u8 = if (command == .strikethrough) "line-through" else "underline";
            var current: ?*Instance = node;
            while (current) |c| : (current = try parentElement(c)) {
                if (try style_values.textDecorationContains(scratch(edit), c, word)) return word;
            }
            return null;
        },
        else => {},
    }
    // Step 8: the resolved value of the relevant CSS property.
    const property = command.relevantProperty() orelse return null;
    return try style_values.resolved(scratch(edit), node, property);
}

/// "specified command value" of `element` for `command`.
pub fn specifiedValue(edit: *Edit, element: *Instance, command: Command) anyerror!Value {
    if (!common.isElement(element)) return null;
    // Step 1: backColor and hiliteColor only on a display: inline element.
    if ((command == .back_color or command == .hilite_color) and !style_values.displayIsInline(element)) return null;
    switch (command) {
        // Step 2: an a's href.
        .create_link, .unlink => {
            if ((try isNamed(element, "a")) and try common.hasAttribute(element, "href")) return try attribute(edit, element, "href");
            return null;
        },
        // Step 3: sup and sub.
        .subscript, .superscript => {
            if (try isNamed(element, "sup")) return "superscript";
            if (try isNamed(element, "sub")) return "subscript";
            return null;
        },
        // Steps 4-7: text-decoration in the style attribute, then s/strike
        // and u.
        .strikethrough, .underline => {
            const word: []const u8 = if (command == .strikethrough) "line-through" else "underline";
            const decoration = try style_values.inlineValue(scratch(edit), element, "text-decoration");
            if (decoration.len > 0) {
                return if (style_values.containsWord(decoration, word)) word else null;
            }
            if (command == .strikethrough and try isNamedIn(element, &.{ "s", "strike" })) return "line-through";
            if (command == .underline and try isNamed(element, "u")) return "underline";
            return null;
        },
        else => {},
    }
    // Steps 8-9: the relevant CSS property, or null.
    const property = command.relevantProperty() orelse return null;
    // Step 10: what the style attribute sets it to.
    const inline_value = try style_values.inlineValue(scratch(edit), element, property);
    if (inline_value.len > 0) return inline_value;
    // Step 11: a <font>'s presentational hint for it (size 7: the non-CSS
    // "xxx-large").
    if (try isNamed(element, "font")) {
        if (std.mem.eql(u8, property, "color")) {
            if (try attribute(edit, element, "color")) |color| {
                if (dom.style.font_hints.parseLegacyColor(color, dom.style.font_hints.cssNamedColor)) |rgb| {
                    return try std.fmt.allocPrint(scratch(edit), "rgb({d}, {d}, {d})", .{ rgb.r, rgb.g, rgb.b });
                }
            }
        } else if (std.mem.eql(u8, property, "font-family")) {
            if (try attribute(edit, element, "face")) |face| return face;
        } else if (std.mem.eql(u8, property, "font-size")) {
            if (try attribute(edit, element, "size")) |size| {
                if (dom.style.font_hints.parseLegacyFontSize(size)) |legacy| return style_values.legacy_keywords[legacy - 1];
            }
        }
    }
    // Step 12: b/strong font-weight bold, i/em font-style italic.
    if (std.mem.eql(u8, property, "font-weight") and try isNamedIn(element, &.{ "b", "strong" })) return "bold";
    if (std.mem.eql(u8, property, "font-style") and try isNamedIn(element, &.{ "i", "em" })) return "italic";
    // Step 13.
    return null;
}

// ============================================================================
// Clearing, pushing down and forcing values
// ============================================================================

/// "clear the value" of `element` for `command`: the nodes that took its
/// place (its children, or the span it became), or none.
pub fn clearValue(edit: *Edit, element: *Instance, command: Command) anyerror![]*Instance {
    var result: std.ArrayList(*Instance) = .empty;
    // Step 2: "If element is not editable, return the empty list."
    if (!try common.isEditable(element)) return result.items;
    // Step 3: no specified command value - nothing to clear.
    if ((try specifiedValue(edit, element, command)) == null) return result.items;
    // Step 4: a simple modifiable element goes, its children taking its
    // place, preserving ranges.
    if (try isSimpleModifiableElement(edit, element)) {
        var child = try common.firstChild(element);
        while (child) |c| : (child = try common.nextSibling(c)) try result.append(scratch(edit), c);
        const p = (try common.parent(element)).?;
        for (result.items) |c| {
            try edit.movePreservingRanges(c, p, try common.indexOf(element));
        }
        try edit.removeNode(element);
        return result.items;
    }
    // Steps 5-6: take line-through / underline out of the style
    // attribute's text-decoration.
    if (command == .strikethrough or command == .underline) {
        const word: []const u8 = if (command == .strikethrough) "line-through" else "underline";
        const decoration = try style_values.inlineValue(scratch(edit), element, "text-decoration");
        if (style_values.containsWord(decoration, word)) {
            if (std.mem.eql(u8, decoration, word)) {
                try style_values.removeInline(element, "text-decoration");
            } else {
                try style_values.setInline(element, "text-decoration", try withoutWord(edit, decoration, word));
                try style_values.dropEmptyStyleAttribute(element);
            }
            edit.modified = true;
        }
    }
    // Step 7: unset the relevant CSS property.
    if (command.relevantProperty()) |property| {
        const before = try style_values.inlineValue(scratch(edit), element, property);
        if (before.len > 0) {
            try style_values.removeInline(element, property);
            edit.modified = true;
        }
    }
    // Step 8: a font's color, face or size attribute.
    if (try isNamed(element, "font")) {
        const name: ?[]const u8 = switch (command) {
            .fore_color => "color",
            .font_name => "face",
            .font_size => "size",
            else => null,
        };
        if (name) |n| if (try common.hasAttribute(element, n)) {
            try common.removeAttribute(element, n);
            edit.modified = true;
        };
    }
    // Step 9: an a's href, for createLink and unlink.
    if ((try isNamed(element, "a")) and (command == .create_link or command == .unlink) and try common.hasAttribute(element, "href")) {
        try common.removeAttribute(element, "href");
        edit.modified = true;
    }
    // Step 10: nothing specified any more - keep the element.
    if ((try specifiedValue(edit, element, command)) == null) return result.items;
    // Step 11: an element like <b class=foo> keeps its other attributes
    // on a span.
    const span = try edit.setTagName(element, "span");
    try result.append(scratch(edit), span);
    return result.items;
}

fn withoutWord(edit: *Edit, value: []const u8, word: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var words = std.mem.tokenizeAny(u8, value, " \t\n\r\x0c");
    while (words.next()) |w| {
        if (std.ascii.eqlIgnoreCase(w, word)) continue;
        if (out.items.len > 0) try out.append(scratch(edit), ' ');
        try out.appendSlice(scratch(edit), w);
    }
    return out.items;
}

/// "push down values" to `node` for `command`, given `new_value`.
pub fn pushDownValues(edit: *Edit, node: *Instance, command: Command, new_value: Value) anyerror!void {
    // Step 2: "If node's parent is not an Element, abort this algorithm."
    const node_parent = (try common.parent(node)) orelse return;
    if (!common.isElement(node_parent)) return;
    // Step 3: already the value.
    if (areLooselyEquivalent(edit, command, try effectiveValue(edit, node, command), new_value)) return;
    // Steps 4-6: the editable element ancestors whose effective value is
    // not the new one.
    var ancestor_list: std.ArrayList(*Instance) = .empty;
    var current_ancestor: ?*Instance = node_parent;
    while (current_ancestor) |c| {
        if (!common.isElement(c) or !try common.isEditable(c)) break;
        if (areLooselyEquivalent(edit, command, try effectiveValue(edit, c, command), new_value)) break;
        try ancestor_list.append(scratch(edit), c);
        current_ancestor = try common.parent(c);
    }
    // Step 7.
    if (ancestor_list.items.len == 0) return;
    // Step 8: the value the topmost of them specifies.
    var propagated_value = try specifiedValue(edit, ancestor_list.items[ancestor_list.items.len - 1], command);
    // Step 9: "If propagated value is null and is not equal to new value,
    // abort this algorithm."
    if (propagated_value == null and new_value != null) return;
    // Step 10: pushing down only helps when the value above is the one we
    // want (or we only want to remove a value).
    if (new_value != null) {
        const top_parent = (try common.parent(ancestor_list.items[ancestor_list.items.len - 1])) orelse return;
        if (!areLooselyEquivalent(edit, command, try effectiveValue(edit, top_parent, command), new_value)) return;
    }
    // Step 11: from the top down, clear each ancestor's value and force the
    // propagated value onto its other children.
    while (ancestor_list.items.len > 0) {
        const ancestor = ancestor_list.pop().?;
        if (try specifiedValue(edit, ancestor, command)) |specified| propagated_value = specified;
        var children: std.ArrayList(*Instance) = .empty;
        var child = try common.firstChild(ancestor);
        while (child) |c| : (child = try common.nextSibling(c)) try children.append(scratch(edit), c);
        if ((try specifiedValue(edit, ancestor, command)) != null) _ = try clearValue(edit, ancestor, command);
        for (children.items) |c| {
            if (c == node) continue;
            if (common.isElement(c)) {
                const specified = try specifiedValue(edit, c, command);
                if (specified != null and !areEquivalent(edit, command, specified, propagated_value)) continue;
            }
            if (ancestor_list.items.len > 0 and c == ancestor_list.items[ancestor_list.items.len - 1]) continue;
            try forceValue(edit, c, command, propagated_value);
        }
    }
}

/// Force-the-value's sibling criteria (step 4.3): a simple modifiable
/// element that specifies the new value and has it - and, as every browser
/// does, is the element this command would create for the value (steps
/// 10-15): bold merges `<b>foo</b>[bar]` into the <b> but not
/// `<strong>foo</strong>[bar]` (`<strong>foo</strong><b>bar</b>`), and in
/// CSS mode it makes a new span rather than joining a <b> sibling
/// (editing/run/bold.html "foo<strong>bar</strong>[baz]", "<strong>foo
/// </strong>[bar]<strong>baz</strong>", "<b>foo</b>[bar]<b>baz</b>" with
/// styleWithCSS true: Chrome 156, Firefox 158 and Safari 27 pass, wpt.fyi
/// f4febe305a / 5af3c135c9 / 1ec6aacb4e). Golden rule 2, no newer spec.
const ForceCriteria = struct {
    edit: *Edit,
    command: Command,
    new_value: []const u8,
    /// The local name force the value would create.
    name: []const u8,

    pub fn siblingCriteria(self: ForceCriteria, node: *Instance) anyerror!bool {
        if (!try isNamed(node, self.name)) return false;
        if (!try isSimpleModifiableElement(self.edit, node)) return false;
        if (!areEquivalent(self.edit, self.command, try specifiedValue(self.edit, node, self.command), self.new_value)) return false;
        return areLooselyEquivalent(self.edit, self.command, try effectiveValue(self.edit, node, self.command), self.new_value);
    }

    pub fn newParent(self: ForceCriteria, edit: *Edit) anyerror!?*Instance {
        _ = self;
        _ = edit;
        return null;
    }
};

/// The children of `node` that are not Elements specifying a value that is
/// neither null nor equivalent to `new_value`.
fn childrenToForce(edit: *Edit, node: *Instance, command: Command, new_value: []const u8) ![]*Instance {
    var children: std.ArrayList(*Instance) = .empty;
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (common.isElement(c)) {
            const specified = try specifiedValue(edit, c, command);
            if (specified != null and !areEquivalent(edit, command, specified, new_value)) continue;
        }
        try children.append(scratch(edit), c);
    }
    return children.items;
}

/// "force the value" of `node` for `command` to `new_value_in`.
pub fn forceValue(edit: *Edit, node: *Instance, command: Command, new_value_in: Value) anyerror!void {
    // Step 2: "If node's parent is null, abort this algorithm."
    if ((try common.parent(node)) == null) return;
    // Step 3: "If new value is null, abort this algorithm."
    const new_value = new_value_in orelse return;
    // Step 4: an allowed child of span joins a matching sibling.
    if (try isAllowedChildOfName(node, "span")) {
        if (try common.previousSibling(node)) |previous| try reorderModifiableDescendants(edit, previous, command, new_value);
        if (try common.nextSibling(node)) |next| try reorderModifiableDescendants(edit, next, command, new_value);
        const name = newParentName(command, new_value, try overrides.cssStylingFlag(edit), scratch(edit));
        _ = try wrap_mod.wrap(edit, &.{node}, ForceCriteria{ .edit = edit, .command = command, .new_value = new_value, .name = name });
    }
    // Step 5: "If node is invisible, abort this algorithm."
    if (try common.isInvisible(node)) return;
    // Step 6: already the value.
    if (areLooselyEquivalent(edit, command, try effectiveValue(edit, node, command), new_value)) return;
    // Step 7: not an allowed child of span - force its children instead.
    if (!try isAllowedChildOfName(node, "span")) {
        for (try childrenToForce(edit, node, command, new_value)) |child| try forceValue(edit, child, command, new_value);
        return;
    }
    // Step 8.
    if (areLooselyEquivalent(edit, command, try effectiveValue(edit, node, command), new_value)) return;
    // Steps 9-15: the new parent.
    var new_parent: ?*Instance = null;
    const css_styling = try overrides.cssStylingFlag(edit);
    if (!css_styling) {
        switch (command) {
            .bold => if (std.mem.eql(u8, new_value, "bold")) {
                new_parent = try edit.createElement("b");
            },
            .italic => if (std.mem.eql(u8, new_value, "italic")) {
                new_parent = try edit.createElement("i");
            },
            .strikethrough => if (std.mem.eql(u8, new_value, "line-through")) {
                new_parent = try edit.createElement("s");
            },
            .underline => if (std.mem.eql(u8, new_value, "underline")) {
                new_parent = try edit.createElement("u");
            },
            .fore_color => {
                var buffer: [7]u8 = undefined;
                if (style_values.simpleColor(scratch(edit), new_value, &buffer)) |hex| {
                    new_parent = try edit.createElement("font");
                    try common.setAttribute(new_parent.?, "color", hex);
                }
            },
            .font_name => {
                new_parent = try edit.createElement("font");
                try common.setAttribute(new_parent.?, "face", new_value);
            },
            else => {},
        }
    }
    // Step 11: createLink and unlink make an a, and no a may enclose it.
    if (command == .create_link or command == .unlink) {
        new_parent = try edit.createElement("a");
        try common.setAttribute(new_parent.?, "href", new_value);
        var ancestor = try common.parent(node);
        while (ancestor) |a| {
            var current = a;
            if (try isNamed(a, "a")) current = try edit.setTagName(a, "span");
            ancestor = try common.parent(current);
        }
    }
    // Step 12: fontSize keywords as <font size>, always for xxx-large.
    if (command == .font_size) {
        if (style_values.legacySizeOfKeyword(new_value)) |size| {
            if (!css_styling or size == 7) {
                new_parent = try edit.createElement("font");
                var digit = [1]u8{'0' + size};
                try common.setAttribute(new_parent.?, "size", &digit);
            }
        }
    }
    // Steps 13-14: sub and sup, in CSS mode too.
    if (command == .subscript or command == .superscript) {
        if (std.mem.eql(u8, new_value, "subscript")) new_parent = try edit.createElement("sub");
        if (std.mem.eql(u8, new_value, "superscript")) new_parent = try edit.createElement("sup");
    }
    // Step 15: otherwise a span.
    const wrapper = new_parent orelse try edit.createElement("span");
    // Step 16: "Insert new parent in node's parent before node."
    const node_parent = (try common.parent(node)) orelse return;
    try edit.insertBefore(node_parent, wrapper, node);
    // Step 17: the relevant CSS property, when the wrapper does not have
    // the value already (and the value is valid for it).
    if (command.relevantProperty()) |property| {
        if (!areLooselyEquivalent(edit, command, try effectiveValue(edit, wrapper, command), new_value)) {
            try style_values.setInline(wrapper, property, new_value);
        }
    }
    // Steps 18-19: text-decoration for strikethrough and underline.
    if (command == .strikethrough and std.mem.eql(u8, new_value, "line-through")) {
        const effective = try effectiveValue(edit, wrapper, .strikethrough);
        if (effective == null or !std.mem.eql(u8, effective.?, "line-through")) try style_values.setInline(wrapper, "text-decoration", "line-through");
    }
    if (command == .underline and std.mem.eql(u8, new_value, "underline")) {
        const effective = try effectiveValue(edit, wrapper, .underline);
        if (effective == null or !std.mem.eql(u8, effective.?, "underline")) try style_values.setInline(wrapper, "text-decoration", "underline");
    }
    // Step 20: "Append node to new parent as its last child, preserving
    // ranges."
    try edit.movePreservingRanges(node, wrapper, try common.childCount(wrapper));
    // Step 21: an element that still does not have the value (a
    // non-inline style rule, say) goes back out, and its children are
    // forced instead.
    if (common.isElement(node) and !areLooselyEquivalent(edit, command, try effectiveValue(edit, node, command), new_value)) {
        const wrapper_parent = (try common.parent(wrapper)) orelse return;
        try edit.movePreservingRanges(node, wrapper_parent, try common.indexOf(wrapper));
        try edit.removeNode(wrapper);
        for (try childrenToForce(edit, node, command, new_value)) |child| try forceValue(edit, child, command, new_value);
    }
}

/// The local name force the value's steps 9-15 give its new parent for
/// `command`, `new_value` and the CSS styling flag.
fn newParentName(command: Command, new_value: []const u8, css_styling: bool, allocator: Allocator) []const u8 {
    switch (command) {
        .create_link, .unlink => return "a",
        .subscript, .superscript => {
            if (std.mem.eql(u8, new_value, "subscript")) return "sub";
            if (std.mem.eql(u8, new_value, "superscript")) return "sup";
            return "span";
        },
        .font_size => {
            if (style_values.legacySizeOfKeyword(new_value)) |size| {
                if (!css_styling or size == 7) return "font";
            }
            return "span";
        },
        else => {},
    }
    if (css_styling) return "span";
    return switch (command) {
        .bold => if (std.mem.eql(u8, new_value, "bold")) "b" else "span",
        .italic => if (std.mem.eql(u8, new_value, "italic")) "i" else "span",
        .strikethrough => if (std.mem.eql(u8, new_value, "line-through")) "s" else "span",
        .underline => if (std.mem.eql(u8, new_value, "underline")) "u" else "span",
        .fore_color => blk: {
            var buffer: [7]u8 = undefined;
            break :blk if (style_values.simpleColor(allocator, new_value, &buffer) != null) "font" else "span";
        },
        .font_name => "font",
        else => "span",
    };
}

/// "reorder modifiable descendants" of `node` for `command` and
/// `new_value`.
pub fn reorderModifiableDescendants(edit: *Edit, node: *Instance, command: Command, new_value: []const u8) anyerror!void {
    // Steps 1-2: down through single modifiable children.
    var candidate = node;
    while (try isModifiableElement(candidate)) {
        if ((try common.childCount(candidate)) != 1) break;
        const only = (try common.firstChild(candidate)).?;
        if (!try isModifiableElement(only)) break;
        if ((try isSimpleModifiableElement(edit, candidate)) and areEquivalent(edit, command, try specifiedValue(edit, candidate, command), new_value)) break;
        candidate = only;
    }
    // Step 3.
    if (candidate == node) return;
    if (!try isSimpleModifiableElement(edit, candidate)) return;
    if (!areEquivalent(edit, command, try specifiedValue(edit, candidate, command), new_value)) return;
    if (!areLooselyEquivalent(edit, command, try effectiveValue(edit, candidate, command), new_value)) return;
    // Step 4: candidate's children take its place, preserving ranges.
    const candidate_parent = (try common.parent(candidate)) orelse return;
    while (try common.firstChild(candidate)) |child| {
        try edit.movePreservingRanges(child, candidate_parent, try common.indexOf(candidate));
    }
    // Step 5: "Insert candidate into node's parent immediately after
    // node." (plain insertion, not preserving ranges)
    const node_parent = (try common.parent(node)) orelse return;
    try edit.insertBefore(node_parent, candidate, try common.nextSibling(node));
    // Step 6: "Append the node as the last child of candidate, preserving
    // ranges."
    try edit.movePreservingRanges(node, candidate, try common.childCount(candidate));
}

// ============================================================================
// Setting the selection's value
// ============================================================================

/// "set the selection's value" to `new_value` for `command`.
pub fn setSelectionValue(edit: *Edit, command: Command, new_value: Value) anyerror!void {
    // Step 2: nothing formattable - the change waits in the overrides for
    // the next typed text.
    if ((try firstFormattableNode(edit)) == null) {
        if (command.hasState()) try overrides.setStateOverride(edit, command, isActivated(command, new_value));
        if (command == .subscript) try overrides.unsetStateOverride(edit, .superscript);
        if (command == .superscript) try overrides.unsetStateOverride(edit, .subscript);
        if (new_value == null) {
            try overrides.unsetValueOverride(edit, command);
        } else if (command == .create_link or command.hasValue()) {
            try overrides.setValueOverride(edit, command, new_value.?);
        }
        return;
    }
    const range = (try edit.activeRange()) orelse return;
    // Step 3: split the start Text node; the range starts at the second
    // half.
    if (try edit.rangeStart()) |start| {
        if (common.isText(start.node) and (try common.isEditable(start.node)) and start.offset != 0 and start.offset != try common.nodeLength(start.node)) {
            const second = try splitText(edit, start.node, start.offset);
            try interfaces.Range.call_setStart(range, second, 0);
        }
    }
    // Step 4: split the end Text node.
    if (try edit.rangeEnd()) |end| {
        if (common.isText(end.node) and (try common.isEditable(end.node)) and end.offset != 0 and end.offset != try common.nodeLength(end.node)) {
            _ = try splitText(edit, end.node, end.offset);
        }
    }
    // Steps 5-6: clear the value of every editable element effectively
    // contained in the active range.
    {
        const bounds = (try activeBounds(edit)) orelse return;
        const elements = try effectivelyContainedNodes(edit, bounds, .editable_element);
        for (elements) |element| _ = try clearValue(edit, element, command);
    }
    // Steps 7-8: push down values on, then force the value of, every
    // editable node effectively contained.
    const bounds = (try activeBounds(edit)) orelse return;
    const nodes = try effectivelyContainedNodes(edit, bounds, .editable);
    for (nodes) |node| {
        try pushDownValues(edit, node, command, new_value);
        // An element the whole range lies inside (an inclusive ancestor of
        // both its start and end node) is not wrapped: its contents are,
        // so `abc<i>[def]</i>ghi` bolds to `abc<i><b>def</b></i>ghi` in
        // every browser, where the spec's effectively contained <i> gets
        // the <b> around it (editing/run/bold.html ?3001-last "abc<i>[def]
        // </i>ghi" and "abc<i>{def}</i>ghi" with styleWithCSS false:
        // Chrome 156, Firefox 158 and Safari 27 pass, wpt.fyi f4febe305a /
        // 5af3c135c9 / 1ec6aacb4e). Golden rule 2, no newer spec.
        if (common.isElement(node) and common.isInclusiveDescendantOf(bounds.start.node, node) and common.isInclusiveDescendantOf(bounds.end.node, node)) continue;
        if (try isAllowedChildOfName(node, "span")) try forceValue(edit, node, command, new_value);
    }
}

// ============================================================================
// State, value and indeterminacy
// ============================================================================

/// The formattable nodes effectively contained in the active range.
fn formattableNodes(edit: *Edit) ![]*Instance {
    const bounds = (try activeBounds(edit)) orelse return &.{};
    return try effectivelyContainedNodes(edit, bounds, .formattable);
}

/// The command's state (no override): for the commands with inline command
/// activated values.
pub fn commandState(edit: *Edit, command: Command) !bool {
    const nodes = try formattableNodes(edit);
    if (nodes.len == 0) {
        // "no formattable node is effectively contained in the active range,
        // and the active range's start node's effective command value is one
        // of the given values"
        const start = (try edit.rangeStart()) orelse return false;
        return isActivated(command, try effectiveValue(edit, start.node, command));
    }
    // "all of them have an effective command value equal to one of the
    // given values"
    for (nodes) |node| {
        if (!isActivated(command, try effectiveValue(edit, node, command))) return false;
    }
    return true;
}

/// The command's value (no override): the standard inline value commands
/// and fontSize; "" when none applies.
pub fn commandValue(edit: *Edit, command: Command) ![]const u8 {
    const nodes = try formattableNodes(edit);
    if (command == .font_size) {
        // fontSize step 1: no active range, the empty string.
        const start = (try edit.rangeStart()) orelse return "";
        // Step 2: the pixel size of the first formattable node, or of the
        // start node.
        const node = if (nodes.len > 0) nodes[0] else start.node;
        const pixel_size = (try effectiveValue(edit, node, .font_size)) orelse return "";
        const px = style_values.parsePx(pixel_size) orelse return "";
        // Step 3: its legacy font size.
        return legacyDigit(style_values.legacyFontSizeFor(px));
    }
    // Standard inline value command: the first formattable node's effective
    // value, else the start node's, else "".
    if (nodes.len > 0) return (try effectiveValue(edit, nodes[0], command)) orelse "";
    const start = (try edit.rangeStart()) orelse return "";
    return (try effectiveValue(edit, start.node, command)) orelse "";
}

fn legacyDigit(size: u8) []const u8 {
    const digits = [_][]const u8{ "1", "2", "3", "4", "5", "6", "7" };
    return digits[size - 1];
}

/// Whether the command is indeterminate.
pub fn commandIndeterm(edit: *Edit, command: Command) !bool {
    const nodes = try formattableNodes(edit);
    switch (command) {
        // subscript / superscript: one with the value and one without, or
        // one "mixed".
        .subscript, .superscript => {
            const own: []const u8 = if (command == .subscript) "subscript" else "superscript";
            var with = false;
            var without = false;
            for (nodes) |node| {
                const v = try effectiveValue(edit, node, command);
                if (v != null and std.mem.eql(u8, v.?, "mixed")) return true;
                if (v != null and std.mem.eql(u8, v.?, own)) with = true else without = true;
            }
            return with and without;
        },
        else => {},
    }
    if (command.hasState()) {
        // Inline command activated values: one node with an activated value
        // and one without.
        var with = false;
        var without = false;
        for (nodes) |node| {
            if (isActivated(command, try effectiveValue(edit, node, command))) with = true else without = true;
        }
        return with and without;
    }
    if (command.hasValue()) {
        // The standard inline value commands and fontSize: two nodes with
        // distinct effective command values.
        var first: ?Value = null;
        for (nodes) |node| {
            const v = try effectiveValue(edit, node, command);
            if (first) |f| {
                if (!distinctSame(f, v)) return true;
            } else first = v;
        }
        return false;
    }
    return false;
}

fn distinctSame(a: Value, b: Value) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

/// queryCommandState() steps 1-3 for an inline command: false without a
/// state, the state override when set, else the state.
pub fn queryState(edit: *Edit, command: Command) !bool {
    if (!command.hasState()) return false;
    if (try overrides.stateOverride(edit, command)) |override| return override;
    return try commandState(edit, command);
}

/// queryCommandValue() steps 1-4 for an inline command: "" without a
/// value; fontSize's value override as a legacy size; the value override;
/// else the value.
pub fn queryValue(edit: *Edit, command: Command) ![]const u8 {
    if (!command.hasValue()) return "";
    if (try overrides.valueOverride(edit, command)) |override| {
        if (command == .font_size) {
            // Step 2: "convert the value override to an integer number of
            // pixels and return the legacy font size for the result".
            return legacyDigit(style_values.legacyFontSizeFor(overrideToPixels(override)));
        }
        return try scratch(edit).dupe(u8, override);
    }
    return try commandValue(edit, command);
}

/// A fontSize value override (a keyword from the action, or a resolved
/// pixel size from record current states and values) as pixels.
pub fn overrideToPixels(override: []const u8) f64 {
    if (style_values.legacySizeOfKeyword(override)) |size| return style_values.legacy_size_px[size - 1];
    if (style_values.parsePx(override)) |px| return px;
    return style_values.legacy_size_px[2];
}

// ============================================================================
// The actions
// ============================================================================

/// Take the action for `command` with `value_in`; its return value.
pub fn action(edit: *Edit, command: Command, value_in: []const u8) anyerror!bool {
    switch (command) {
        .bold, .italic => {
            // "If queryCommandState(...) returns true, set the selection's
            // value to "normal". Otherwise set the selection's value to
            // "bold"/"italic". Either way, return true."
            const on: []const u8 = if (command == .bold) "bold" else "italic";
            try setSelectionValue(edit, command, if (try queryState(edit, command)) "normal" else on);
            return true;
        },
        .strikethrough, .underline => {
            // "If queryCommandState(...) returns true, set the selection's
            // value to null. Otherwise set it to "line-through"/"underline"."
            const on: []const u8 = if (command == .strikethrough) "line-through" else "underline";
            try setSelectionValue(edit, command, if (try queryState(edit, command)) null else on);
            return true;
        },
        .subscript, .superscript => {
            // Steps 1-3: the state first, then null, then the value if the
            // state was false.
            const was = try queryState(edit, command);
            try setSelectionValue(edit, command, null);
            if (!was) try setSelectionValue(edit, command, if (command == .subscript) "subscript" else "superscript");
            return true;
        },
        .back_color, .fore_color, .hilite_color => {
            // Step 1: "#" prepended to an invalid color.
            var color = value_in;
            if (!style_values.isValidColor(scratch(edit), color)) color = try std.fmt.allocPrint(scratch(edit), "#{s}", .{value_in});
            // Step 2 says "return false" for a value still invalid, or
            // currentColor. All three browsers return TRUE for those and
            // leave the text alone (editing/run/forecolor.html ?1-1000:
            // "f", "#f", "000000fff", "potato quiche", "currentColor"
            // return values - Chrome 156, Firefox 158 and Safari 27 at
            // wpt.fyi f4febe305a / 5af3c135c9 / 1ec6aacb4e; the unchanged
            // innerHTML is Chrome's and Safari's). Golden rule 2, no newer
            // spec: return true, change nothing.
            if (!style_values.isValidColor(scratch(edit), color) or style_values.isCurrentColor(color)) return true;
            // Step 3.
            try setSelectionValue(edit, command, color);
            return true;
        },
        .font_name => {
            // "Set the selection's value to value, then return true."
            try setSelectionValue(edit, .font_name, value_in);
            return true;
        },
        .font_size => {
            const keyword = fontSizeKeyword(value_in) orelse return false;
            try setSelectionValue(edit, .font_size, keyword);
            return true;
        },
        .create_link => return try createLink(edit, value_in),
        .unlink => return try unlink(edit),
        .remove_format => return try removeFormat(edit),
    }
}

/// fontSize action steps 1-11: the keyword for `value`, or null (return
/// false). The spec parses a valid floating-point number (steps 1-10);
/// every browser parses the value as HTML's legacy font size instead:
/// "2em" is size 2 (`<font size="2">`) and returns true in Chrome 156,
/// Firefox 158 and Safari 27, where the spec returns false; "xx-large" and
/// "" have no digits and return false in all three (editing/run/
/// fontsize.html ?1-1000, wpt.fyi f4febe305a / 5af3c135c9 / 1ec6aacb4e).
/// Golden rule 2, no newer spec: HTML's rules for parsing a legacy font
/// size (dom.style.font_hints), then step 11's keyword.
pub fn fontSizeKeyword(value_in: []const u8) ?[]const u8 {
    const size = dom.style.font_hints.parseLegacyFontSize(value_in) orelse return null;
    // Step 11.
    return style_values.legacy_keywords[size - 1];
}

/// The createLink action.
fn createLink(edit: *Edit, value_in: []const u8) !bool {
    // Step 1: "If value is the empty string, return false."
    if (value_in.len == 0) return false;
    // Step 2: every editable a with an href that is an ancestor of some
    // effectively contained node gets the new href.
    if (try activeBounds(edit)) |bounds| {
        const nodes = try effectivelyContainedNodes(edit, bounds, .any);
        var links: std.ArrayList(*Instance) = .empty;
        for (nodes) |node| {
            var ancestor = try common.parent(node);
            while (ancestor) |a| : (ancestor = try common.parent(a)) {
                if (!(try isNamed(a, "a")) or !(try common.hasAttribute(a, "href")) or !(try common.isEditable(a))) continue;
                for (links.items) |seen| {
                    if (seen == a) break;
                } else try links.append(scratch(edit), a);
            }
        }
        for (links.items) |link| {
            try common.setAttribute(link, "href", value_in);
            edit.modified = true;
        }
    }
    // Step 3.
    try setSelectionValue(edit, .create_link, value_in);
    return true;
}

/// The unlink action.
fn unlink(edit: *Edit) !bool {
    const bounds = (try activeBounds(edit)) orelse return true;
    // Step 1: every a with an href contained in the active range or an
    // ancestor of one of its boundary points.
    var hyperlinks: std.ArrayList(*Instance) = .empty;
    const root = rootOf(bounds.start.node);
    var current: ?*Instance = root;
    while (current) |n| : (current = try common.nextInTreeOrder(n)) {
        if (!(try isNamed(n, "a")) or !try common.hasAttribute(n, "href")) continue;
        if ((try isContained(n, bounds)) or common.isAncestorOf(n, bounds.start.node) or common.isAncestorOf(n, bounds.end.node)) {
            try hyperlinks.append(scratch(edit), n);
        }
    }
    // Step 2: clear the value of each.
    for (hyperlinks.items) |link| _ = try clearValue(edit, link, .unlink);
    // Step 3.
    return true;
}

fn rootOf(node: *Instance) *Instance {
    var current = node;
    while (common.parent(current) catch null) |p| current = p;
    return current;
}

/// "removeFormat candidate".
fn isRemoveFormatCandidate(node: *Instance) !bool {
    if (!try isNamedIn(node, &.{ "abbr", "acronym", "b", "bdi", "bdo", "big", "blink", "cite", "code", "dfn", "em", "font", "i", "ins", "kbd", "mark", "nobr", "q", "s", "samp", "small", "span", "strike", "strong", "sub", "sup", "tt", "u", "var" })) return false;
    return try common.isEditable(node);
}

/// The removeFormat action.
fn removeFormat(edit: *Edit) !bool {
    // Steps 1-2: every removeFormat candidate effectively contained goes,
    // its children taking its place.
    if (try activeBounds(edit)) |bounds| {
        const elements = try effectivelyContainedNodes(edit, bounds, .remove_format_candidate);
        for (elements) |element| {
            const p = (try common.parent(element)) orelse continue;
            while (try common.firstChild(element)) |child| {
                try edit.movePreservingRanges(child, p, try common.indexOf(element));
            }
            try edit.removeNode(element);
        }
    }
    const range = (try edit.activeRange()) orelse return true;
    // Steps 3-4: split the boundary Text nodes, as set the selection's
    // value does.
    if (try edit.rangeStart()) |start| {
        if (common.isText(start.node) and (try common.isEditable(start.node)) and start.offset != 0 and start.offset != try common.nodeLength(start.node)) {
            const second = try splitText(edit, start.node, start.offset);
            try interfaces.Range.call_setStart(range, second, 0);
        }
    }
    if (try edit.rangeEnd()) |end| {
        if (common.isText(end.node) and (try common.isEditable(end.node)) and end.offset != 0 and end.offset != try common.nodeLength(end.node)) {
            _ = try splitText(edit, end.node, end.offset);
        }
    }
    // Steps 5-6: split each editable node out of removeFormat candidate
    // parents in its editing host.
    if (try activeBounds(edit)) |bounds| {
        const nodes = try effectivelyContainedNodes(edit, bounds, .editable);
        for (nodes) |node| {
            while (true) {
                const p = (try common.parent(node)) orelse break;
                if (!try isRemoveFormatCandidate(p)) break;
                if (!try common.inSameEditingHost(p, node)) break;
                try split_parent.splitParent(edit, &.{node});
            }
        }
    }
    // Step 7: set the selection's value to null for each command.
    for (recorded_commands) |command| try setSelectionValue(edit, command, null);
    // Step 8.
    return true;
}

test "fontSize keywords from legacy sizes" {
    try std.testing.expectEqualStrings("medium", fontSizeKeyword("3").?);
    try std.testing.expectEqualStrings("large", fontSizeKeyword("+1").?);
    try std.testing.expectEqualStrings("small", fontSizeKeyword("-1").?);
    try std.testing.expectEqualStrings("xxx-large", fontSizeKeyword("9").?);
    try std.testing.expectEqualStrings("x-small", fontSizeKeyword("0").?);
    try std.testing.expectEqualStrings("medium", fontSizeKeyword(" 3.5 ").?);
    try std.testing.expectEqualStrings("small", fontSizeKeyword("2em").?);
    try std.testing.expectEqual(@as(?[]const u8, null), fontSizeKeyword(""));
    try std.testing.expectEqual(@as(?[]const u8, null), fontSizeKeyword("+"));
    try std.testing.expectEqual(@as(?[]const u8, null), fontSizeKeyword("xx-small"));
}
