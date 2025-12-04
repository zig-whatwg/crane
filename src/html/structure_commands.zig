//! Structure Command Integration
//!
//! Provides DOM-integrated implementations of structure-related execCommand
//! operations (list commands, paragraph commands, link/media commands).
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/
//!
//! ## Architecture Note
//!
//! This module lives in src/html/ (full.zig module) because it needs access to
//! runtime, interfaces, and impls modules. The stub implementations in
//! src/html/editing/structure.zig are used by html_core which doesn't have
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

/// Convert DocumentHandle to runtime.Instance
fn getDocumentInstance(handle: DocumentHandle) ?*runtime.Instance {
    const h = handle orelse return null;
    return @ptrCast(@alignCast(h));
}

// =============================================================================
// List Commands with DOM Integration
// =============================================================================

/// Execute insertOrderedList command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-insertorderedlist-command
///
/// Creates an <ol> containing <li> elements from selection
pub fn executeInsertOrderedList(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeInsertList(allocator, document, true);
}

/// Execute insertUnorderedList command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-insertunorderedlist-command
///
/// Creates a <ul> containing <li> elements from selection
pub fn executeInsertUnorderedList(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeInsertList(allocator, document, false);
}

/// Common list insertion logic
fn executeInsertList(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    ordered: bool,
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

    // Get anchor node to check if already in list
    const anchor_node = impls.Selection.get_anchorNode(selection) catch null;
    if (anchor_node == null) {
        return .{ .success = true };
    }

    // Check if already in a list of the same type
    var current: ?*runtime.Instance = anchor_node;
    var existing_list: ?*runtime.Instance = null;
    var existing_list_type: ?[]const u8 = null;

    while (current != null) {
        const node_type = impls.Node.get_nodeType(current.?) catch 0;
        if (node_type == 1) { // ELEMENT_NODE
            const tag_name_opt = impls.Element.get_tagName(current.?) catch null;
            if (tag_name_opt) |tag_name| {
                const tag_str = tag_name.get() catch "";
                if (std.ascii.eqlIgnoreCase(tag_str, "OL") or std.ascii.eqlIgnoreCase(tag_str, "UL")) {
                    existing_list = current;
                    existing_list_type = tag_str;
                    break;
                }
            }
        }
        current = impls.Node.get_parentNode(current.?) catch null;
    }

    const list_tag = if (ordered) "ol" else "ul";
    const other_tag = if (ordered) "UL" else "OL";

    // Toggle behavior: if in same type list, unwrap; if in different type, convert
    if (existing_list != null) {
        if (existing_list_type) |elt| {
            if (std.ascii.eqlIgnoreCase(elt, list_tag)) {
                // Same type - would unwrap (toggle off)
                // TODO: Implement unwrap logic
                return .{ .success = true };
            } else if (std.ascii.eqlIgnoreCase(elt, other_tag)) {
                // Different type - would convert
                // TODO: Implement conversion logic
                return .{ .success = true };
            }
        }
    }

    // Not in a list - create new list
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

    // Create list element
    const list = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned(list_tag),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create list element" };
    };

    if (list == null) {
        return .{ .success = false, .error_message = "Failed to create list element" };
    }

    // Create list item
    const li = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("li"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create list item" };
    };

    if (li == null) {
        return .{ .success = false, .error_message = "Failed to create list item" };
    }

    // Extract selection contents
    const contents = impls.Range.call_extractContents(range.?) catch {
        return .{ .success = false, .error_message = "Failed to extract contents" };
    };

    if (contents != null) {
        // Append contents to li
        _ = impls.Node.call_appendChild(li.?, contents.?) catch {
            return .{ .success = false, .error_message = "Failed to append to list item" };
        };
    }

    // Append li to list
    _ = impls.Node.call_appendChild(list.?, li.?) catch {
        return .{ .success = false, .error_message = "Failed to append list item to list" };
    };

    // Insert list at range position
    impls.Range.call_insertNode(range.?, list.?) catch {
        return .{ .success = false, .error_message = "Failed to insert list" };
    };

    return .{ .success = true };
}

// =============================================================================
// Paragraph/Line Commands with DOM Integration
// =============================================================================

/// Execute insertParagraph command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-insertparagraph-command
///
/// Splits block at cursor and creates new paragraph
pub fn executeInsertParagraph(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
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

    // Delete selection if not collapsed
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (!is_collapsed) {
        impls.Selection.call_deleteFromDocument(selection) catch {};
    }

    // Create new paragraph
    const p = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("p"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create paragraph" };
    };

    if (p == null) {
        return .{ .success = false, .error_message = "Failed to create paragraph" };
    }

    // Add a br to make the paragraph visible/editable
    const br = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("br"),
    ) catch null;

    if (br != null) {
        _ = impls.Node.call_appendChild(p.?, br.?) catch {};
    }

    // Get range and insert
    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count > 0) {
        if (impls.Selection.call_getRangeAt(selection, 0)) |range| {
            if (range != null) {
                impls.Range.call_insertNode(range.?, p.?) catch {};
                // Collapse selection to new paragraph
                impls.Range.call_selectNodeContents(range.?, p.?) catch {};
                impls.Range.call_collapse(range.?, true) catch {};
            }
        } else |_| {}
    }

    return .{ .success = true };
}

/// Execute insertLineBreak command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-insertlinebreak-command
///
/// Inserts a <br> element at cursor
pub fn executeInsertLineBreak(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
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

    // Delete selection if not collapsed
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (!is_collapsed) {
        impls.Selection.call_deleteFromDocument(selection) catch {};
    }

    // Create br element
    const br = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("br"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create br element" };
    };

    if (br == null) {
        return .{ .success = false, .error_message = "Failed to create br element" };
    }

    // Get range and insert
    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count > 0) {
        if (impls.Selection.call_getRangeAt(selection, 0)) |range| {
            if (range != null) {
                impls.Range.call_insertNode(range.?, br.?) catch {};
                // Move cursor after br
                impls.Range.call_setStartAfter(range.?, br.?) catch {};
                impls.Range.call_collapse(range.?, true) catch {};
            }
        } else |_| {}
    }

    return .{ .success = true };
}

/// Execute insertHorizontalRule command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-inserthorizontalrule-command
///
/// Inserts an <hr> element at cursor
pub fn executeInsertHorizontalRule(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
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

    // Delete selection if not collapsed
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (!is_collapsed) {
        impls.Selection.call_deleteFromDocument(selection) catch {};
    }

    // Create hr element
    const hr = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("hr"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create hr element" };
    };

    if (hr == null) {
        return .{ .success = false, .error_message = "Failed to create hr element" };
    }

    // Get range and insert
    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count > 0) {
        if (impls.Selection.call_getRangeAt(selection, 0)) |range| {
            if (range != null) {
                impls.Range.call_insertNode(range.?, hr.?) catch {};
                // Move cursor after hr
                impls.Range.call_setStartAfter(range.?, hr.?) catch {};
                impls.Range.call_collapse(range.?, true) catch {};
            }
        } else |_| {}
    }

    return .{ .success = true };
}

/// Execute formatBlock command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-formatblock-command
///
/// Changes block element type (p, h1-h6, pre, blockquote, etc.)
pub fn executeFormatBlock(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    var tag_name = value orelse return .{
        .success = false,
        .error_message = "formatBlock requires a tag name",
    };

    // Strip optional < > around tag name
    if (std.mem.startsWith(u8, tag_name, "<")) {
        tag_name = tag_name[1..];
    }
    if (std.mem.endsWith(u8, tag_name, ">")) {
        tag_name = tag_name[0 .. tag_name.len - 1];
    }

    // Validate tag name
    const valid_tags = [_][]const u8{
        "p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "blockquote", "address",
    };

    var is_valid = false;
    for (valid_tags) |valid| {
        if (std.ascii.eqlIgnoreCase(tag_name, valid)) {
            is_valid = true;
            break;
        }
    }

    if (!is_valid) {
        return .{ .success = false, .error_message = "Invalid block tag" };
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

    // Find block-level ancestor
    const anchor_node = impls.Selection.get_anchorNode(selection) catch null;
    if (anchor_node == null) {
        return .{ .success = true };
    }

    var current: ?*runtime.Instance = anchor_node;
    var block_element: ?*runtime.Instance = null;

    while (current != null) {
        const node_type = impls.Node.get_nodeType(current.?) catch 0;
        if (node_type == 1) { // ELEMENT_NODE
            const current_tag_opt = impls.Element.get_tagName(current.?) catch null;
            if (current_tag_opt) |current_tag| {
                const current_tag_str = current_tag.get() catch "";
                if (isBlockElement(current_tag_str)) {
                    block_element = current;
                    break;
                }
            }
        }
        current = impls.Node.get_parentNode(current.?) catch null;
    }

    if (block_element == null) {
        // No block element found - wrap selection in new block
        const range_count = impls.Selection.get_rangeCount(selection) catch 0;
        if (range_count > 0) {
            if (impls.Selection.call_getRangeAt(selection, 0)) |range| {
                if (range != null) {
                    const new_block = impls.Document.call_createElement(
                        doc_instance,
                        runtime.DOMString.initFromSlice(allocator, tag_name) catch {
                            return .{ .success = false, .error_message = "Failed to create tag name" };
                        },
                    ) catch {
                        return .{ .success = false, .error_message = "Failed to create block element" };
                    };

                    if (new_block != null) {
                        impls.Range.call_surroundContents(range.?, new_block.?) catch {};
                    }
                }
            } else |_| {}
        }
    }
    // TODO: If block element exists, replace it with new type

    return .{ .success = true };
}

// =============================================================================
// Link and Media Commands with DOM Integration
// =============================================================================

/// Execute unlink command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-unlink-command
///
/// Removes <a> elements from selection, preserving their content
pub fn executeUnlink(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
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

    // Find <a> element in/around selection
    const anchor_node = impls.Selection.get_anchorNode(selection) catch null;
    if (anchor_node == null) {
        return .{ .success = true };
    }

    var current: ?*runtime.Instance = anchor_node;
    var link_element: ?*runtime.Instance = null;

    while (current != null) {
        const node_type = impls.Node.get_nodeType(current.?) catch 0;
        if (node_type == 1) { // ELEMENT_NODE
            const tag_name_opt = impls.Element.get_tagName(current.?) catch null;
            if (tag_name_opt) |tag_name| {
                const tag_str = tag_name.get() catch "";
                if (std.ascii.eqlIgnoreCase(tag_str, "A")) {
                    link_element = current;
                    break;
                }
            }
        }
        current = impls.Node.get_parentNode(current.?) catch null;
    }

    if (link_element != null) {
        // Get parent and unwrap link
        const parent = impls.Node.get_parentNode(link_element.?) catch null;
        if (parent != null) {
            // Move all children of <a> to parent
            var child = impls.Node.get_firstChild(link_element.?) catch null;
            while (child != null) {
                const next = impls.Node.get_nextSibling(child.?) catch null;
                _ = impls.Node.call_insertBefore(parent.?, child.?, link_element) catch {};
                child = next;
            }
            // Remove empty <a>
            _ = impls.Node.call_removeChild(parent.?, link_element.?) catch {};
        }
    }

    return .{ .success = true };
}

/// Execute insertImage command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-insertimage-command
///
/// Inserts an <img> element with specified src
pub fn executeInsertImage(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const src = value orelse return .{
        .success = false,
        .error_message = "insertImage requires a URL",
    };

    if (src.len == 0) {
        return .{ .success = false, .error_message = "Image URL cannot be empty" };
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

    // Delete selection if not collapsed
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (!is_collapsed) {
        impls.Selection.call_deleteFromDocument(selection) catch {};
    }

    // Create img element
    const img = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("img"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create img element" };
    };

    if (img == null) {
        return .{ .success = false, .error_message = "Failed to create img element" };
    }

    // Set src attribute
    impls.Element.call_setAttribute(
        img.?,
        runtime.DOMString.initInterned("src"),
        runtime.DOMString.initFromSlice(allocator, src) catch {
            return .{ .success = false, .error_message = "Failed to create src string" };
        },
    ) catch {
        return .{ .success = false, .error_message = "Failed to set src attribute" };
    };

    // Get range and insert
    const range_count = impls.Selection.get_rangeCount(selection) catch 0;
    if (range_count > 0) {
        if (impls.Selection.call_getRangeAt(selection, 0)) |range| {
            if (range != null) {
                impls.Range.call_insertNode(range.?, img.?) catch {};
            }
        } else |_| {}
    }

    return .{ .success = true };
}

/// Execute insertHTML command with DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-inserthtml-command
///
/// Parses HTML string and inserts at cursor
pub fn executeInsertHTML(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const html = value orelse return .{
        .success = false,
        .error_message = "insertHTML requires HTML content",
    };

    if (html.len == 0) {
        return .{ .success = true };
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

    // Delete selection if not collapsed
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (!is_collapsed) {
        impls.Selection.call_deleteFromDocument(selection) catch {};
    }

    // Create a template element to parse HTML
    const template = impls.Document.call_createElement(
        doc_instance,
        runtime.DOMString.initInterned("template"),
    ) catch {
        return .{ .success = false, .error_message = "Failed to create template element" };
    };

    if (template == null) {
        return .{ .success = false, .error_message = "Failed to create template element" };
    }

    // Set innerHTML (this parses the HTML)
    impls.Element.set_innerHTML(
        template.?,
        runtime.DOMString.initFromSlice(allocator, html) catch {
            return .{ .success = false, .error_message = "Failed to create HTML string" };
        },
    ) catch {
        return .{ .success = false, .error_message = "Failed to parse HTML" };
    };

    // Get template content (document fragment)
    const content = impls.HTMLTemplateElement.get_content(template.?) catch null;

    if (content != null) {
        // Clone content
        const fragment = impls.Node.call_cloneNode(content.?, true) catch null;

        if (fragment != null) {
            // Insert fragment at range
            const range_count = impls.Selection.get_rangeCount(selection) catch 0;
            if (range_count > 0) {
                if (impls.Selection.call_getRangeAt(selection, 0)) |range| {
                    if (range != null) {
                        impls.Range.call_insertNode(range.?, fragment.?) catch {};
                    }
                } else |_| {}
            }
        }
    }

    return .{ .success = true };
}

// =============================================================================
// Helper Functions
// =============================================================================

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

// =============================================================================
// Tests
// =============================================================================

test "structure_commands module compiles" {
    try std.testing.expect(true);
}

test "isBlockElement" {
    try std.testing.expect(isBlockElement("P"));
    try std.testing.expect(isBlockElement("DIV"));
    try std.testing.expect(isBlockElement("H1"));
    try std.testing.expect(isBlockElement("BLOCKQUOTE"));
    try std.testing.expect(isBlockElement("p")); // case insensitive
    try std.testing.expect(!isBlockElement("SPAN"));
    try std.testing.expect(!isBlockElement("A"));
    try std.testing.expect(!isBlockElement("B"));
}
