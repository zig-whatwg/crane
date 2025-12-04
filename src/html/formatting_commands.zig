//! Formatting Command Integration
//!
//! Provides DOM-integrated implementations of formatting-related execCommand
//! operations (fontName, fontSize, foreColor, backColor, hiliteColor,
//! justifyLeft, justifyCenter, justifyRight, justifyFull).
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/
//!
//! ## Architecture Note
//!
//! This module lives in src/html/ (full.zig module) because it needs access to
//! runtime, interfaces, and impls modules. The stub implementations in
//! src/html/editing/formatting.zig are used by html_core which doesn't have
//! access to WebIDL modules.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const impls = @import("impls");

/// Result of executing a command
pub const CommandResult = struct {
    success: bool,
    error_message: ?[]const u8 = null,
};

/// Document handle - can be cast to runtime.Instance when valid
pub const DocumentHandle = ?*anyopaque;

/// Text alignment options
pub const Alignment = enum {
    left,
    center,
    right,
    full,

    pub fn toCssValue(self: Alignment) []const u8 {
        return switch (self) {
            .left => "left",
            .center => "center",
            .right => "right",
            .full => "justify",
        };
    }
};

/// Legacy font size to CSS size mapping
/// Sizes 1-7 per HTML spec
const FontSizeMap = struct {
    const sizes = [_][]const u8{
        "10px", // 1 = x-small
        "13px", // 2 = small
        "16px", // 3 = medium (default)
        "18px", // 4 = large
        "24px", // 5 = x-large
        "32px", // 6 = xx-large
        "48px", // 7 = xxx-large
    };

    pub fn toCss(size: u8) ?[]const u8 {
        if (size < 1 or size > 7) return null;
        return sizes[size - 1];
    }
};

/// Convert DocumentHandle to runtime.Instance
fn getDocumentInstance(handle: DocumentHandle) ?*runtime.Instance {
    const h = handle orelse return null;
    return @ptrCast(@alignCast(h));
}

// =============================================================================
// Font Commands with DOM Integration
// =============================================================================

/// Execute fontName command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-fontname-command
///
/// Wraps selection in <span style="font-family: [value]">
pub fn executeFontName(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const font_name = value orelse return .{
        .success = false,
        .error_message = "fontName requires a value",
    };

    if (font_name.len == 0) {
        return .{ .success = false, .error_message = "fontName cannot be empty" };
    }

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    // Get selection
    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    // Check if collapsed - if so, formatting applies to next typed character
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;

    if (is_collapsed) {
        // TODO: Set pending formatting state for next input
        return .{ .success = true };
    }

    // Get range count
    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count == 0) {
        return .{ .success = true };
    }

    // Get the first range
    const range = impls.Selection.call_getRangeAt(selection, 0) catch {
        return .{ .success = false, .error_message = "Failed to get range" };
    };

    if (range == null) {
        return .{ .success = true };
    }

    // Create span element with font-family style
    const span = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("span"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create span element" };
    };

    if (span == null) {
        return .{ .success = false, .error_message = "Failed to create span element" };
    }

    // Build style string
    var style_buf: [256]u8 = undefined;
    const style = std.fmt.bufPrint(&style_buf, "font-family: {s}", .{font_name}) catch {
        return .{ .success = false, .error_message = "Font name too long" };
    };

    // Set style attribute
    impls.Element.call_setAttribute(
        span.?,
        runtime.DOMString.initInterned("style"),
        runtime.DOMString.initFromSlice(allocator, style) catch {
            return .{ .success = false, .error_message = "Failed to create style string" };
        },
    ) catch {
        return .{ .success = false, .error_message = "Failed to set style attribute" };
    };

    // Surround range contents with span
    impls.Range.call_surroundContents(range.?, span.?) catch {
        return .{ .success = false, .error_message = "Failed to surround contents" };
    };

    return .{ .success = true };
}

/// Execute fontSize command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-fontsize-command
///
/// Accepts sizes 1-7 (legacy) or CSS values
pub fn executeFontSize(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const size_str = value orelse return .{
        .success = false,
        .error_message = "fontSize requires a value",
    };

    // Determine CSS size
    var css_size: []const u8 = size_str;

    // Try parsing as legacy 1-7 size
    if (std.fmt.parseInt(u8, size_str, 10)) |size| {
        if (FontSizeMap.toCss(size)) |mapped| {
            css_size = mapped;
        } else {
            return .{ .success = false, .error_message = "fontSize must be 1-7" };
        }
    } else |_| {
        // Not a number - use as CSS value directly
    }

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (is_collapsed) {
        return .{ .success = true };
    }

    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count == 0) {
        return .{ .success = true };
    }

    const range = impls.Selection.call_getRangeAt(selection, 0) catch {
        return .{ .success = false, .error_message = "Failed to get range" };
    };

    if (range == null) {
        return .{ .success = true };
    }

    // Create span with font-size
    const span = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("span"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create span element" };
    };

    if (span == null) {
        return .{ .success = false, .error_message = "Failed to create span element" };
    }

    var style_buf: [256]u8 = undefined;
    const style = std.fmt.bufPrint(&style_buf, "font-size: {s}", .{css_size}) catch {
        return .{ .success = false, .error_message = "Size value too long" };
    };

    impls.Element.call_setAttribute(
        span.?,
        runtime.DOMString.initInterned("style"),
        runtime.DOMString.initFromSlice(allocator, style) catch {
            return .{ .success = false, .error_message = "Failed to create style string" };
        },
    ) catch {
        return .{ .success = false, .error_message = "Failed to set style attribute" };
    };

    impls.Range.call_surroundContents(range.?, span.?) catch {
        return .{ .success = false, .error_message = "Failed to surround contents" };
    };

    return .{ .success = true };
}

/// Execute foreColor command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-forecolor-command
///
/// Wraps selection in <span style="color: [value]">
pub fn executeForeColor(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const color = value orelse return .{
        .success = false,
        .error_message = "foreColor requires a value",
    };

    if (color.len == 0) {
        return .{ .success = false, .error_message = "foreColor cannot be empty" };
    }

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (is_collapsed) {
        return .{ .success = true };
    }

    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count == 0) {
        return .{ .success = true };
    }

    const range = impls.Selection.call_getRangeAt(selection, 0) catch {
        return .{ .success = false, .error_message = "Failed to get range" };
    };

    if (range == null) {
        return .{ .success = true };
    }

    const span = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("span"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create span element" };
    };

    if (span == null) {
        return .{ .success = false, .error_message = "Failed to create span element" };
    }

    var style_buf: [256]u8 = undefined;
    const style = std.fmt.bufPrint(&style_buf, "color: {s}", .{color}) catch {
        return .{ .success = false, .error_message = "Color value too long" };
    };

    impls.Element.call_setAttribute(
        span.?,
        runtime.DOMString.initInterned("style"),
        runtime.DOMString.initFromSlice(allocator, style) catch {
            return .{ .success = false, .error_message = "Failed to create style string" };
        },
    ) catch {
        return .{ .success = false, .error_message = "Failed to set style attribute" };
    };

    impls.Range.call_surroundContents(range.?, span.?) catch {
        return .{ .success = false, .error_message = "Failed to surround contents" };
    };

    return .{ .success = true };
}

/// Execute backColor command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-backcolor-command
///
/// Wraps selection in <span style="background-color: [value]">
pub fn executeBackColor(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const color = value orelse return .{
        .success = false,
        .error_message = "backColor requires a value",
    };

    if (color.len == 0) {
        return .{ .success = false, .error_message = "backColor cannot be empty" };
    }

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (is_collapsed) {
        return .{ .success = true };
    }

    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count == 0) {
        return .{ .success = true };
    }

    const range = impls.Selection.call_getRangeAt(selection, 0) catch {
        return .{ .success = false, .error_message = "Failed to get range" };
    };

    if (range == null) {
        return .{ .success = true };
    }

    const span = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("span"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create span element" };
    };

    if (span == null) {
        return .{ .success = false, .error_message = "Failed to create span element" };
    }

    var style_buf: [256]u8 = undefined;
    const style = std.fmt.bufPrint(&style_buf, "background-color: {s}", .{color}) catch {
        return .{ .success = false, .error_message = "Color value too long" };
    };

    impls.Element.call_setAttribute(
        span.?,
        runtime.DOMString.initInterned("style"),
        runtime.DOMString.initFromSlice(allocator, style) catch {
            return .{ .success = false, .error_message = "Failed to create style string" };
        },
    ) catch {
        return .{ .success = false, .error_message = "Failed to set style attribute" };
    };

    impls.Range.call_surroundContents(range.?, span.?) catch {
        return .{ .success = false, .error_message = "Failed to surround contents" };
    };

    return .{ .success = true };
}

/// Execute hiliteColor command - alias for backColor
pub fn executeHiliteColor(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    return executeBackColor(allocator, document, value);
}

// =============================================================================
// Alignment Commands with DOM Integration
// =============================================================================

/// Execute justify command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
///
/// Sets text-align style on block-level ancestor of selection
pub fn executeJustify(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    alignment: Alignment,
) !CommandResult {
    _ = allocator;

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    // Get anchor node (start of selection)
    const anchor_node = impls.Selection.get_anchorNode(selection) catch null;
    if (anchor_node == null) {
        return .{ .success = true };
    }

    // Find block-level ancestor
    var current: ?*runtime.Instance = anchor_node;
    var block_element: ?*runtime.Instance = null;

    while (current != null) {
        // Check if this is a block-level element
        const node_type = impls.Node.get_nodeType(current.?) catch 0;
        if (node_type == 1) { // ELEMENT_NODE
            // Check tag name for block elements
            const tag_name_opt = impls.Element.get_tagName(current.?) catch null;
            if (tag_name_opt) |tag_name| {
                const tag_str = tag_name.get() catch "";
                if (isBlockElement(tag_str)) {
                    block_element = current;
                    break;
                }
            }
        }

        // Move to parent
        current = impls.Node.get_parentNode(current.?) catch null;
    }

    // If no block element found, try document body
    if (block_element == null) {
        block_element = impls.Document.get_body(doc_instance) catch null;
    }

    if (block_element == null) {
        return .{ .success = true };
    }

    // Set text-align style
    const css_value = alignment.toCssValue();

    // Get or create style attribute
    var style_buf: [256]u8 = undefined;
    const new_style = std.fmt.bufPrint(&style_buf, "text-align: {s}", .{css_value}) catch {
        return .{ .success = false, .error_message = "Style value too long" };
    };

    impls.Element.call_setAttribute(
        block_element.?,
        runtime.DOMString.initInterned("style"),
        runtime.DOMString.initFromSlice(std.heap.page_allocator, new_style) catch {
            return .{ .success = false, .error_message = "Failed to create style string" };
        },
    ) catch {
        return .{ .success = false, .error_message = "Failed to set style attribute" };
    };

    return .{ .success = true };
}

/// Check if tag name represents a block-level element
fn isBlockElement(tag_name: []const u8) bool {
    const block_tags = [_][]const u8{
        "P",    "DIV",      "H1",      "H2",         "H3",
        "H4",   "H5",       "H6",      "BLOCKQUOTE", "PRE",
        "UL",   "OL",       "LI",      "TABLE",      "TR",
        "TD",   "TH",       "ARTICLE", "SECTION",    "ASIDE",
        "NAV",  "HEADER",   "FOOTER",  "MAIN",       "FIGURE",
        "FORM", "FIELDSET", "ADDRESS",
    };

    for (block_tags) |tag| {
        if (std.ascii.eqlIgnoreCase(tag_name, tag)) {
            return true;
        }
    }
    return false;
}

/// Execute justifyLeft command
pub fn executeJustifyLeft(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .left);
}

/// Execute justifyCenter command
pub fn executeJustifyCenter(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .center);
}

/// Execute justifyRight command
pub fn executeJustifyRight(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .right);
}

/// Execute justifyFull command
pub fn executeJustifyFull(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .full);
}

// =============================================================================
// Remove Format Command
// =============================================================================

/// Elements that should be removed by removeFormat
/// These are inline formatting elements that apply visual styling
const formatting_elements = [_][]const u8{
    "B",
    "STRONG",
    "I",
    "EM",
    "U",
    "S",
    "STRIKE",
    "SUB",
    "SUP",
    "FONT",
    "TT",
    "BIG",
    "SMALL",
    "MARK",
};

/// CSS properties that should be removed from spans
const formatting_css_properties = [_][]const u8{
    "font-family",
    "font-size",
    "font-weight",
    "font-style",
    "text-decoration",
    "color",
    "background-color",
    "background",
};

/// Check if a tag is a formatting element that should be unwrapped
fn isFormattingElement(tag_name: []const u8) bool {
    for (formatting_elements) |tag| {
        if (std.ascii.eqlIgnoreCase(tag_name, tag)) {
            return true;
        }
    }
    return false;
}

/// Execute removeFormat command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-removeformat-command
///
/// Removes formatting from the selection by:
/// 1. Unwrapping inline formatting elements (b, i, u, font, etc.)
/// 2. Removing formatting-related CSS properties from spans
/// 3. Removing empty spans after style removal
pub fn executeRemoveFormat(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
) !CommandResult {
    _ = allocator;

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    // Get selection
    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    // Check if collapsed - nothing to remove
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (is_collapsed) {
        return .{ .success = true };
    }

    // Get range count
    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count == 0) {
        return .{ .success = true };
    }

    // Get the first range
    const range = impls.Selection.call_getRangeAt(selection, 0) catch {
        return .{ .success = false, .error_message = "Failed to get range" };
    };

    if (range == null) {
        return .{ .success = true };
    }

    // Get common ancestor container
    const common_ancestor = impls.Range.get_commonAncestorContainer(range.?) catch null;
    if (common_ancestor == null) {
        return .{ .success = true };
    }

    // Walk through nodes in the range and collect formatting elements
    // We need to collect first, then modify (to avoid iterator invalidation)
    var nodes_to_unwrap = std.ArrayList(*runtime.Instance).init(std.heap.page_allocator);
    defer nodes_to_unwrap.deinit();

    var spans_to_clean = std.ArrayList(*runtime.Instance).init(std.heap.page_allocator);
    defer spans_to_clean.deinit();

    // Simple tree walk from common ancestor
    try collectFormattingNodes(common_ancestor.?, &nodes_to_unwrap, &spans_to_clean);

    // Unwrap formatting elements (move children out, remove element)
    for (nodes_to_unwrap.items) |node| {
        unwrapElement(node) catch continue;
    }

    // Clean spans (remove style attribute or remove span if empty)
    for (spans_to_clean.items) |span| {
        cleanSpanFormatting(span) catch continue;
    }

    return .{ .success = true };
}

/// Recursively collect formatting elements and styled spans
fn collectFormattingNodes(
    node: *runtime.Instance,
    nodes_to_unwrap: *std.ArrayList(*runtime.Instance),
    spans_to_clean: *std.ArrayList(*runtime.Instance),
) !void {
    const node_type = impls.Node.get_nodeType(node) catch 0;

    if (node_type == 1) { // ELEMENT_NODE
        const tag_name_opt = impls.Element.get_tagName(node) catch null;
        if (tag_name_opt) |tag_name| {
            const tag_str = tag_name.get() catch "";

            if (isFormattingElement(tag_str)) {
                try nodes_to_unwrap.append(node);
            } else if (std.ascii.eqlIgnoreCase(tag_str, "SPAN")) {
                // Check if span has formatting styles
                const style_opt = impls.Element.call_getAttribute(
                    node,
                    runtime.DOMString.initInterned("style"),
                ) catch null;

                if (style_opt != null) {
                    try spans_to_clean.append(node);
                }
            }
        }
    }

    // Recurse to children
    const first_child = impls.Node.get_firstChild(node) catch null;
    var child = first_child;
    while (child != null) {
        const next = impls.Node.get_nextSibling(child.?) catch null;
        try collectFormattingNodes(child.?, nodes_to_unwrap, spans_to_clean);
        child = next;
    }
}

/// Unwrap an element by moving its children to its parent and removing it
fn unwrapElement(element: *runtime.Instance) !void {
    const parent = impls.Node.get_parentNode(element) catch null;
    if (parent == null) return;

    // Move all children before this element
    var child = impls.Node.get_firstChild(element) catch null;
    while (child != null) {
        const next = impls.Node.get_nextSibling(child.?) catch null;
        _ = impls.Node.call_insertBefore(parent.?, child.?, element) catch null;
        child = next;
    }

    // Remove the now-empty element
    _ = impls.Node.call_removeChild(parent.?, element) catch null;
}

/// Remove formatting CSS properties from a span
fn cleanSpanFormatting(span: *runtime.Instance) !void {
    // For now, just remove the style attribute entirely
    // A more sophisticated implementation would parse and filter CSS properties
    impls.Element.call_removeAttribute(
        span,
        runtime.DOMString.initInterned("style"),
    ) catch return;

    // Check if span is now empty (no attributes, no class)
    // If so, unwrap it too
    const class_opt = impls.Element.call_getAttribute(
        span,
        runtime.DOMString.initInterned("class"),
    ) catch null;

    const id_opt = impls.Element.call_getAttribute(
        span,
        runtime.DOMString.initInterned("id"),
    ) catch null;

    if (class_opt == null and id_opt == null) {
        // Span has no meaningful attributes, unwrap it
        unwrapElement(span) catch return;
    }
}

// =============================================================================
// Tests
// =============================================================================

test "formatting_commands module compiles" {
    try std.testing.expect(true);
}

test "FontSizeMap converts correctly" {
    try std.testing.expectEqualStrings("10px", FontSizeMap.toCss(1).?);
    try std.testing.expectEqualStrings("16px", FontSizeMap.toCss(3).?);
    try std.testing.expectEqualStrings("48px", FontSizeMap.toCss(7).?);
    try std.testing.expect(FontSizeMap.toCss(0) == null);
    try std.testing.expect(FontSizeMap.toCss(8) == null);
}

test "Alignment.toCssValue" {
    try std.testing.expectEqualStrings("left", Alignment.left.toCssValue());
    try std.testing.expectEqualStrings("center", Alignment.center.toCssValue());
    try std.testing.expectEqualStrings("right", Alignment.right.toCssValue());
    try std.testing.expectEqualStrings("justify", Alignment.full.toCssValue());
}

test "isBlockElement" {
    try std.testing.expect(isBlockElement("P"));
    try std.testing.expect(isBlockElement("DIV"));
    try std.testing.expect(isBlockElement("H1"));
    try std.testing.expect(isBlockElement("p")); // case insensitive
    try std.testing.expect(!isBlockElement("SPAN"));
    try std.testing.expect(!isBlockElement("A"));
}

test "isFormattingElement" {
    try std.testing.expect(isFormattingElement("B"));
    try std.testing.expect(isFormattingElement("STRONG"));
    try std.testing.expect(isFormattingElement("I"));
    try std.testing.expect(isFormattingElement("EM"));
    try std.testing.expect(isFormattingElement("U"));
    try std.testing.expect(isFormattingElement("FONT"));
    try std.testing.expect(isFormattingElement("b")); // case insensitive
    try std.testing.expect(isFormattingElement("strong"));
    try std.testing.expect(!isFormattingElement("SPAN"));
    try std.testing.expect(!isFormattingElement("DIV"));
    try std.testing.expect(!isFormattingElement("A"));
    try std.testing.expect(!isFormattingElement("P"));
}
