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
        // Free tokenizer (InputStream is stored inline, no separate cleanup needed)
        self.tokenizer.deinit();
        self.allocator.destroy(self.tokenizer);
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

    /// The quirks mode to use for parsing.
    /// Spec: "Let the Document's mode be the mode of context_element's node document."
    /// Default: no_quirks (standards mode)
    quirks_mode: QuirksMode = .no_quirks,
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
    // Spec: "Let the Document's mode be the mode of context_element's node document."
    // The quirks mode is passed via options from the caller who has access to the
    // context element's owner document. This allows proper quirks mode handling
    // for innerHTML, outerHTML, insertAdjacentHTML, etc.

    // Step 4: Set allow declarative shadow roots
    _ = options.allow_declarative_shadow_roots;
    // TODO: Set this on the document when we have full DOM integration

    // Step 5: Create a new HTML parser (tokenizer creates its own InputStream internally)
    const tokenizer = try allocator.create(Tokenizer);
    errdefer allocator.destroy(tokenizer);
    tokenizer.* = Tokenizer.init(allocator, input);
    errdefer tokenizer.deinit();

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
    // HTML fragment parsing step 9: the adjusted current node is this context
    // while only the synthetic html root is on the stack of open elements.
    tree_builder.fragment_context = @constCast(context_element);

    // Set scripting flag
    tree_builder.scripting_enabled = options.scripting_enabled;
    // HTML fragment parsing, step 9: later resets must still see context.
    tree_builder.fragment_context = @constCast(context_element);

    // Step 2-3: Set quirks mode on the document
    // Spec: "Let the Document's mode be the mode of context_element's node document."
    tree_builder.quirks_mode = options.quirks_mode;

    // Step 7: Create root <html> element
    const root = try TreeNode.initElement(allocator, "html", .html);
    tree_builder.document.appendChild(root);

    // Step 9: Set up stack of open elements with just the root element
    try tree_builder.pushOpenElement(root);

    // Step 10: If context is a template element, push "in template" mode
    if (std.mem.eql(u8, context_name, "template") and context_element.namespace == .html) {
        try tree_builder.template_insertion_modes.append(.in_template);
    }

    // Step 11: Create a start tag token for context element
    // This is used for determining HTML integration points
    // We store a reference but don't need the actual token for basic parsing

    // Step 12: Reset the parser's insertion mode appropriately
    tree_builder.resetInsertionModeAppropriately();

    // Step 13: Set form element pointer to nearest form ancestor
    // Walk up the context element's ancestors to find a form
    tree_builder.setFormElement(findAncestorForm(context_element));

    // Steps 14-15: Parse the input
    try tree_builder.parse();
    // The parse is over: the structures let go now, while the context's
    // tree (the caller's, where the form pointer may point) is alive.
    tree_builder.releaseStructureHolds();

    // Step 16: Return root's children in tree order
    const children = try collectChildren(allocator, root);

    return FragmentParseResult{
        .children = children,
        .document = tree_builder.document,
        .tree_builder = tree_builder,
        .tokenizer = tokenizer,
        .allocator = allocator,
    };
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
