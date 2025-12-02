//! HTML Fragment Parsing Algorithm
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#html-fragment-parsing-algorithm
//! HTML Standard §13.5 "Parsing HTML fragments"
//!
//! This module implements the HTML fragment parsing algorithm, which is used by:
//! - `innerHTML` setter (Element and ShadowRoot)
//! - `outerHTML` setter
//! - `insertAdjacentHTML()`
//! - `DOMParser.parseFromString()` with "text/html"
//! - `Document.parseHTMLUnsafe()`
//! - `Element.setHTMLUnsafe()` / `ShadowRoot.setHTMLUnsafe()`
//! - `Range.createContextualFragment()`
//!
//! The algorithm takes a context element and input string, and returns a list
//! of nodes representing the parsed fragment.

const std = @import("std");
const Allocator = std.mem.Allocator;

const TreeBuilder = @import("tree_builder.zig").TreeBuilder;
const TreeNode = @import("tree_builder.zig").TreeNode;
const InsertionMode = @import("tree_builder.zig").InsertionMode;
const QuirksMode = @import("tree_builder.zig").QuirksMode;
const Namespace = @import("tree_builder.zig").Namespace;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const State = @import("tokenizer_states.zig").State;
const InputStream = @import("input_stream.zig").InputStream;
const TagToken = @import("tokens.zig").TagToken;

/// Result of fragment parsing - contains the parsed nodes and the temporary document.
/// The caller is responsible for freeing this result.
pub const FragmentParseResult = struct {
    /// The parsed child nodes (owned by the document).
    /// These are the children of the root <html> element.
    children: []*TreeNode,
    /// The temporary document created for parsing.
    /// Must be freed by calling deinit().
    document: *TreeNode,
    /// The tree builder (contains the document).
    tree_builder: *TreeBuilder,
    /// The tokenizer used for parsing.
    tokenizer: *Tokenizer,
    /// The input stream used for parsing.
    input_stream: *InputStream,
    /// Allocator used for allocations.
    allocator: Allocator,

    /// Free all resources associated with this parse result.
    /// After calling this, the children array and all nodes are invalid.
    pub fn deinit(self: *FragmentParseResult) void {
        // Free the children array (the nodes themselves are owned by the document)
        self.allocator.free(self.children);
        // Free the tree builder (which frees the document and all nodes)
        self.tree_builder.deinit();
        self.allocator.destroy(self.tree_builder);
        // Free tokenizer
        self.tokenizer.deinit();
        self.allocator.destroy(self.tokenizer);
        // Free input stream
        self.input_stream.deinit();
        self.allocator.destroy(self.input_stream);
    }
};

/// Options for fragment parsing.
pub const FragmentParseOptions = struct {
    /// Allow declarative shadow roots during parsing.
    /// Default: false
    allow_declarative_shadow_roots: bool = false,

    /// Whether scripting is enabled.
    /// Default: false (scripts don't execute in fragment parsing)
    scripting_enabled: bool = false,
};

/// Parse an HTML fragment.
///
/// HTML Standard §13.5: The HTML fragment parsing algorithm takes a context element
/// and an input string, and returns a list of zero or more nodes.
///
/// This is used by innerHTML, DOMParser, and other DOM APIs.
///
/// # Arguments
/// - `allocator`: Memory allocator for all allocations
/// - `context_element`: The context element that provides parsing context
/// - `input`: The HTML string to parse
/// - `options`: Optional parsing options
///
/// # Returns
/// A FragmentParseResult containing the parsed nodes. The caller must call
/// deinit() on the result to free all resources.
///
/// # Example
/// ```zig
/// const context = try TreeNode.initElement(allocator, "div", .html);
/// defer context.deinit();
///
/// var result = try parseFragment(allocator, context, "<p>Hello</p>", .{});
/// defer result.deinit();
///
/// for (result.children) |child| {
///     // Process child nodes...
/// }
/// ```
pub fn parseFragment(
    allocator: Allocator,
    context_element: *const TreeNode,
    input: []const u8,
    options: FragmentParseOptions,
) !FragmentParseResult {
    // Step 1: Create a new Document node (type "html")
    // The document will be created by the TreeBuilder

    // Step 2-3: Set quirks mode based on context's document
    // For now, we default to no-quirks mode
    // TODO: Get quirks mode from context_element's owner document
    const quirks_mode = QuirksMode.no_quirks;
    _ = quirks_mode;

    // Step 4: Set allow declarative shadow roots
    _ = options.allow_declarative_shadow_roots;
    // TODO: Set this on the document when we have full DOM integration

    // Create input stream
    const input_stream = try allocator.create(InputStream);
    errdefer allocator.destroy(input_stream);
    input_stream.* = InputStream.init(allocator);
    try input_stream.setInput(input);

    // Step 5: Create a new HTML parser
    const tokenizer = try allocator.create(Tokenizer);
    errdefer allocator.destroy(tokenizer);
    tokenizer.* = Tokenizer.init(allocator, input_stream);

    // Step 6: Set tokenizer state based on context element
    const context_name = context_element.local_name orelse "";
    if (context_element.namespace == .html) {
        if (std.mem.eql(u8, context_name, "title") or std.mem.eql(u8, context_name, "textarea")) {
            // Switch to RCDATA state
            tokenizer.state = .rcdata;
        } else if (std.mem.eql(u8, context_name, "style") or
            std.mem.eql(u8, context_name, "xmp") or
            std.mem.eql(u8, context_name, "iframe") or
            std.mem.eql(u8, context_name, "noembed") or
            std.mem.eql(u8, context_name, "noframes"))
        {
            // Switch to RAWTEXT state
            tokenizer.state = .rawtext;
        } else if (std.mem.eql(u8, context_name, "script")) {
            // Switch to script data state
            tokenizer.state = .script_data;
        } else if (std.mem.eql(u8, context_name, "noscript")) {
            // If scripting is enabled, use RAWTEXT; otherwise data state
            if (options.scripting_enabled) {
                tokenizer.state = .rawtext;
            }
            // else: leave in data state (default)
        } else if (std.mem.eql(u8, context_name, "plaintext")) {
            // Switch to PLAINTEXT state
            tokenizer.state = .plaintext;
        }
        // Any other element: leave in data state (default)
    }

    // Create tree builder
    const tree_builder = try allocator.create(TreeBuilder);
    errdefer allocator.destroy(tree_builder);
    tree_builder.* = try TreeBuilder.init(allocator, tokenizer);
    errdefer tree_builder.deinit();

    // Set scripting flag
    tree_builder.scripting_enabled = options.scripting_enabled;

    // Step 7: Create root <html> element
    const root = try TreeNode.initElement(allocator, "html", .html);
    tree_builder.document.appendChild(root);

    // Step 9: Set up stack of open elements with just the root element
    try tree_builder.open_elements.append(root);

    // Step 10: If context is a template element, push "in template" mode
    if (std.mem.eql(u8, context_name, "template") and context_element.namespace == .html) {
        try tree_builder.template_insertion_modes.append(.in_template);
    }

    // Step 11: Create a start tag token for context element
    // This is used for determining HTML integration points
    // We store a reference but don't need the actual token for basic parsing

    // Step 12: Reset the parser's insertion mode appropriately
    // Pass ancestors for proper in_select_in_table detection
    tree_builder.insertion_mode = resetInsertionModeForContextWithAncestors(context_element, context_element.parent);

    // Step 13: Set form element pointer to nearest form ancestor
    // Walk up the context element's ancestors to find a form
    tree_builder.form_element = findAncestorForm(context_element);

    // Steps 14-15: Parse the input
    try tree_builder.parse();

    // Step 16: Return root's children in tree order
    const children = try collectChildren(allocator, root);

    return FragmentParseResult{
        .children = children,
        .document = tree_builder.document,
        .tree_builder = tree_builder,
        .tokenizer = tokenizer,
        .input_stream = input_stream,
        .allocator = allocator,
    };
}

/// Determine the initial insertion mode based on the context element.
/// This implements "reset the insertion mode appropriately" for fragment case.
///
/// HTML Standard §13.2.4.1: The algorithm checks ancestors in specific order.
fn resetInsertionModeForContext(context: *const TreeNode) InsertionMode {
    return resetInsertionModeForContextWithAncestors(context, null);
}

/// Extended version that checks ancestors for select-in-table case.
fn resetInsertionModeForContextWithAncestors(context: *const TreeNode, ancestors: ?*const TreeNode) InsertionMode {
    const name = context.local_name orelse return .in_body;

    // Only consider HTML namespace elements for special handling
    if (context.namespace != .html) {
        // MathML/SVG: use in_body (foreign content rules apply during parsing)
        return .in_body;
    }

    // Check element name to determine insertion mode
    if (std.mem.eql(u8, name, "select")) {
        // HTML Standard: Check ancestors for table/template/tbody/tfoot/thead/tr
        // If any ancestor is table-related, use in_select_in_table
        if (ancestors != null) {
            var ancestor: ?*const TreeNode = ancestors;
            while (ancestor) |anc| {
                if (anc.namespace == .html) {
                    const anc_name = anc.local_name orelse "";
                    if (std.mem.eql(u8, anc_name, "table") or
                        std.mem.eql(u8, anc_name, "template") or
                        std.mem.eql(u8, anc_name, "tbody") or
                        std.mem.eql(u8, anc_name, "tfoot") or
                        std.mem.eql(u8, anc_name, "thead") or
                        std.mem.eql(u8, anc_name, "tr"))
                    {
                        return .in_select_in_table;
                    }
                }
                ancestor = anc.parent;
            }
        }
        return .in_select;
    } else if (std.mem.eql(u8, name, "td") or std.mem.eql(u8, name, "th")) {
        return .in_cell;
    } else if (std.mem.eql(u8, name, "tr")) {
        return .in_row;
    } else if (std.mem.eql(u8, name, "tbody") or std.mem.eql(u8, name, "thead") or std.mem.eql(u8, name, "tfoot")) {
        return .in_table_body;
    } else if (std.mem.eql(u8, name, "caption")) {
        return .in_caption;
    } else if (std.mem.eql(u8, name, "colgroup")) {
        return .in_column_group;
    } else if (std.mem.eql(u8, name, "table")) {
        return .in_table;
    } else if (std.mem.eql(u8, name, "template")) {
        // Should use current template insertion mode, default to in_template
        return .in_template;
    } else if (std.mem.eql(u8, name, "head")) {
        // Fragment case: use in_body, not in_head
        // (Different from regular parsing where we'd check if this is the last node)
        return .in_body;
    } else if (std.mem.eql(u8, name, "body")) {
        return .in_body;
    } else if (std.mem.eql(u8, name, "frameset")) {
        return .in_frameset;
    } else if (std.mem.eql(u8, name, "html")) {
        // Fragment case: use in_body
        // (Full spec checks for head element, but fragment always has one)
        return .in_body;
    }

    // Default: in_body
    return .in_body;
}

/// Find the nearest form element ancestor of the given element.
fn findAncestorForm(element: *const TreeNode) ?*TreeNode {
    var current: ?*const TreeNode = element;
    while (current) |node| {
        if (node.namespace == .html) {
            if (node.local_name) |name| {
                if (std.mem.eql(u8, name, "form")) {
                    // Cast away const since we need a mutable pointer
                    // This is safe because we're just storing a reference
                    return @constCast(node);
                }
            }
        }
        current = node.parent;
    }
    return null;
}

/// Collect all children of a node into an array.
fn collectChildren(allocator: Allocator, node: *TreeNode) ![]*TreeNode {
    // Count children
    var count: usize = 0;
    var child = node.first_child;
    while (child) |c| {
        count += 1;
        child = c.next_sibling;
    }

    // Allocate array
    const children = try allocator.alloc(*TreeNode, count);
    errdefer allocator.free(children);

    // Fill array
    var i: usize = 0;
    child = node.first_child;
    while (child) |c| {
        children[i] = c;
        i += 1;
        child = c.next_sibling;
    }

    return children;
}

/// Parse HTML from a string into a new Document.
/// This is used by DOMParser.parseFromString() with "text/html".
///
/// HTML Standard: "parse HTML from a string"
///
/// Unlike parseFragment, this creates a complete document, not just fragment nodes.
pub fn parseHTMLFromString(allocator: Allocator, html: []const u8) !*TreeBuilder {
    // Create input stream
    const input_stream = try allocator.create(InputStream);
    errdefer allocator.destroy(input_stream);
    input_stream.* = InputStream.init(allocator);
    try input_stream.setInput(html);

    // Create tokenizer
    const tokenizer = try allocator.create(Tokenizer);
    errdefer allocator.destroy(tokenizer);
    tokenizer.* = Tokenizer.init(allocator, input_stream);

    // Create tree builder
    const tree_builder = try allocator.create(TreeBuilder);
    errdefer allocator.destroy(tree_builder);
    tree_builder.* = try TreeBuilder.init(allocator, tokenizer);

    // Parse the document
    try tree_builder.parse();

    return tree_builder;
}

// ============================================================================
// Tests
// ============================================================================

test "fragment parser - simple paragraph" {
    const allocator = std.testing.allocator;

    // Create context element (div)
    const context = try TreeNode.initElement(allocator, "div", .html);
    defer context.deinit();

    // Parse a simple paragraph
    var result = try parseFragment(allocator, context, "<p>Hello, World!</p>", .{});
    defer result.deinit();

    // Should have one child (the <p> element)
    try std.testing.expectEqual(@as(usize, 1), result.children.len);

    const p = result.children[0];
    try std.testing.expectEqualStrings("p", p.local_name.?);
    try std.testing.expectEqual(TreeNode.NodeType.element, p.node_type);
}

test "fragment parser - multiple elements" {
    const allocator = std.testing.allocator;

    // Create context element (div)
    const context = try TreeNode.initElement(allocator, "div", .html);
    defer context.deinit();

    // Parse multiple elements
    var result = try parseFragment(allocator, context, "<span>A</span><span>B</span>", .{});
    defer result.deinit();

    // Should have two children
    try std.testing.expectEqual(@as(usize, 2), result.children.len);

    try std.testing.expectEqualStrings("span", result.children[0].local_name.?);
    try std.testing.expectEqualStrings("span", result.children[1].local_name.?);
}

test "fragment parser - text only" {
    const allocator = std.testing.allocator;

    // Create context element (span)
    const context = try TreeNode.initElement(allocator, "span", .html);
    defer context.deinit();

    // Parse plain text
    var result = try parseFragment(allocator, context, "Hello, World!", .{});
    defer result.deinit();

    // Should have one child (text node)
    try std.testing.expectEqual(@as(usize, 1), result.children.len);

    const text = result.children[0];
    try std.testing.expectEqual(TreeNode.NodeType.text, text.node_type);
}

test "fragment parser - table context" {
    const allocator = std.testing.allocator;

    // Create context element (tbody)
    const context = try TreeNode.initElement(allocator, "tbody", .html);
    defer context.deinit();

    // Parse table row
    var result = try parseFragment(allocator, context, "<tr><td>Cell</td></tr>", .{});
    defer result.deinit();

    // Should have one child (tr element)
    try std.testing.expectEqual(@as(usize, 1), result.children.len);
    try std.testing.expectEqualStrings("tr", result.children[0].local_name.?);
}

test "fragment parser - script context uses script data state" {
    const allocator = std.testing.allocator;

    // Create context element (script)
    const context = try TreeNode.initElement(allocator, "script", .html);
    defer context.deinit();

    // Parse script content
    var result = try parseFragment(allocator, context, "var x = 1;", .{});
    defer result.deinit();

    // Script content should be preserved as text
    try std.testing.expectEqual(@as(usize, 1), result.children.len);
    try std.testing.expectEqual(TreeNode.NodeType.text, result.children[0].node_type);
}

test "fragment parser - textarea context uses RCDATA state" {
    const allocator = std.testing.allocator;

    // Create context element (textarea)
    const context = try TreeNode.initElement(allocator, "textarea", .html);
    defer context.deinit();

    // Parse content with angle brackets (should be treated as text in RCDATA)
    var result = try parseFragment(allocator, context, "Hello <world>", .{});
    defer result.deinit();

    // Content should be preserved as text
    try std.testing.expectEqual(@as(usize, 1), result.children.len);
    try std.testing.expectEqual(TreeNode.NodeType.text, result.children[0].node_type);
}

test "fragment parser - nested elements" {
    const allocator = std.testing.allocator;

    // Create context element (div)
    const context = try TreeNode.initElement(allocator, "div", .html);
    defer context.deinit();

    // Parse nested structure
    var result = try parseFragment(allocator, context, "<div><p><span>Text</span></p></div>", .{});
    defer result.deinit();

    // Should have one top-level child (outer div)
    try std.testing.expectEqual(@as(usize, 1), result.children.len);

    const outer_div = result.children[0];
    try std.testing.expectEqualStrings("div", outer_div.local_name.?);

    // Outer div should have one child (p)
    try std.testing.expect(outer_div.first_child != null);
    try std.testing.expectEqualStrings("p", outer_div.first_child.?.local_name.?);
}

test "resetInsertionModeForContext - various elements" {
    // Test select
    const select = TreeNode{
        .node_type = .element,
        .local_name = "select",
        .namespace = .html,
        .parent = null,
        .first_child = null,
        .last_child = null,
        .prev_sibling = null,
        .next_sibling = null,
        .attributes = undefined,
        .text_content = undefined,
        .doctype_name = null,
        .doctype_public_id = null,
        .doctype_system_id = null,
        .force_quirks = false,
        .allocator = undefined,
    };
    try std.testing.expectEqual(InsertionMode.in_select, resetInsertionModeForContext(&select));

    // Test td
    var td = select;
    td.local_name = "td";
    try std.testing.expectEqual(InsertionMode.in_cell, resetInsertionModeForContext(&td));

    // Test tr
    var tr = select;
    tr.local_name = "tr";
    try std.testing.expectEqual(InsertionMode.in_row, resetInsertionModeForContext(&tr));

    // Test tbody
    var tbody = select;
    tbody.local_name = "tbody";
    try std.testing.expectEqual(InsertionMode.in_table_body, resetInsertionModeForContext(&tbody));

    // Test table
    var table = select;
    table.local_name = "table";
    try std.testing.expectEqual(InsertionMode.in_table, resetInsertionModeForContext(&table));

    // Test div (ordinary element)
    var div = select;
    div.local_name = "div";
    try std.testing.expectEqual(InsertionMode.in_body, resetInsertionModeForContext(&div));
}
