//! HTML Tree Construction Algorithm
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tree-construction
//! HTML Standard §13.2.6 "Tree construction"
//!
//! The tree construction stage takes tokens from the tokenizer and builds
//! the DOM tree. It uses an insertion mode state machine with 24 modes.
//!
//! Key data structures:
//! - Stack of open elements: Contains elements that have been opened but not closed
//! - List of active formatting elements: Handles mis-nested formatting tags
//! - Element pointers: head element pointer, form element pointer
//!
//! The tree builder maintains state about:
//! - Current insertion mode
//! - Original insertion mode (for text mode)
//! - Stack of template insertion modes
//! - Scripting flag, frameset-ok flag

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

const Token = @import("tokens.zig").Token;
const TagToken = @import("tokens.zig").TagToken;
const DoctypeToken = @import("tokens.zig").DoctypeToken;
const CommentToken = @import("tokens.zig").CommentToken;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const State = @import("tokenizer_states.zig").State;
const ParseErrorCode = @import("parse_errors.zig").ParseErrorCode;
const ParseErrorCallback = @import("parse_errors.zig").ParseErrorCallback;

/// The 24 insertion modes defined in HTML Standard §13.2.6.4
///
/// The insertion mode controls how tokens are processed and which
/// elements can be created.
pub const InsertionMode = enum {
    /// Initial mode - handles DOCTYPE and switches to before_html
    initial,
    /// Before <html> element
    before_html,
    /// Before <head> element
    before_head,
    /// Inside <head> element
    in_head,
    /// Inside <head><noscript>
    in_head_noscript,
    /// After </head> before <body>
    after_head,
    /// Main body content
    in_body,
    /// Handling text content (script, style, etc.)
    text,
    /// Inside <table> element
    in_table,
    /// Collecting text inside table
    in_table_text,
    /// Inside <caption> element
    in_caption,
    /// Inside <colgroup> element
    in_column_group,
    /// Inside <tbody>, <thead>, <tfoot>
    in_table_body,
    /// Inside <tr> element
    in_row,
    /// Inside <td> or <th>
    in_cell,
    /// Inside <select> element
    in_select,
    /// Inside <select> inside <table>
    in_select_in_table,
    /// Inside <template> element
    in_template,
    /// After </body>
    after_body,
    /// Inside <frameset> element
    in_frameset,
    /// After </frameset>
    after_frameset,
    /// After </html> (after body)
    after_after_body,
    /// After </html> (after frameset)
    after_after_frameset,
};

/// Quirks mode for the document.
///
/// HTML Standard: The document mode affects CSS layout and some DOM APIs.
pub const QuirksMode = enum {
    /// Standards mode (no quirks)
    no_quirks,
    /// Limited quirks mode (almost-standards)
    limited_quirks,
    /// Quirks mode (legacy compatibility)
    quirks,
};

/// An entry in the list of active formatting elements.
///
/// HTML Standard §13.2.4.3: The list contains elements in the formatting
/// category and markers.
pub const FormattingEntry = union(enum) {
    /// A marker (inserted when entering certain elements)
    marker,
    /// A formatting element with its associated token
    element: struct {
        /// The element node
        node: *TreeNode,
        /// Copy of the token that created this element
        token: TagToken,
    },
};

/// Categories of special elements that have specific parsing rules.
///
/// HTML Standard §13.2.4.2: Special elements have varying levels of
/// special parsing rules.
pub const ElementCategory = enum {
    /// Special elements (have specific parsing behavior)
    special,
    /// Formatting elements (go in active formatting list)
    formatting,
    /// Ordinary elements (generic handling)
    ordinary,
};

/// Namespaces used in the tree builder.
pub const Namespace = enum {
    /// HTML namespace (http://www.w3.org/1999/xhtml)
    html,
    /// MathML namespace (http://www.w3.org/1998/Math/MathML)
    mathml,
    /// SVG namespace (http://www.w3.org/2000/svg)
    svg,
};

/// A node in the DOM tree being constructed.
///
/// This is a simplified node representation for the parser.
/// The actual DOM nodes will be created using the webidl types.
pub const TreeNode = struct {
    /// Node type
    node_type: NodeType,
    /// Local name (for elements)
    local_name: ?[]const u8,
    /// Namespace (for elements)
    namespace: Namespace,
    /// Parent node
    parent: ?*TreeNode,
    /// First child
    first_child: ?*TreeNode,
    /// Last child
    last_child: ?*TreeNode,
    /// Previous sibling
    prev_sibling: ?*TreeNode,
    /// Next sibling
    next_sibling: ?*TreeNode,
    /// Attributes (for elements)
    attributes: infra.List(Attribute),
    /// Text content (for text/comment nodes)
    text_content: infra.List(u8),
    /// DOCTYPE name
    doctype_name: ?[]const u8,
    /// DOCTYPE public identifier
    doctype_public_id: ?[]const u8,
    /// DOCTYPE system identifier
    doctype_system_id: ?[]const u8,
    /// Force quirks flag (for DOCTYPE)
    force_quirks: bool,
    /// Allocator
    allocator: Allocator,

    pub const NodeType = enum {
        document,
        doctype,
        element,
        text,
        comment,
    };

    pub const Attribute = struct {
        name: []const u8,
        value: []const u8,
        namespace: ?Namespace,
    };

    /// Create a new document node.
    pub fn initDocument(allocator: Allocator) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .node_type = .document,
            .local_name = null,
            .namespace = .html,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = null,
            .doctype_public_id = null,
            .doctype_system_id = null,
            .force_quirks = false,
            .allocator = allocator,
        };
        return node;
    }

    /// Create a new element node.
    pub fn initElement(allocator: Allocator, local_name: []const u8, namespace: Namespace) !*TreeNode {
        const node = try allocator.create(TreeNode);
        const name_copy = try allocator.dupe(u8, local_name);
        node.* = TreeNode{
            .node_type = .element,
            .local_name = name_copy,
            .namespace = namespace,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = null,
            .doctype_public_id = null,
            .doctype_system_id = null,
            .force_quirks = false,
            .allocator = allocator,
        };
        return node;
    }

    /// Create a new text node.
    pub fn initText(allocator: Allocator) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .node_type = .text,
            .local_name = null,
            .namespace = .html,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = null,
            .doctype_public_id = null,
            .doctype_system_id = null,
            .force_quirks = false,
            .allocator = allocator,
        };
        return node;
    }

    /// Create a new comment node.
    pub fn initComment(allocator: Allocator) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .node_type = .comment,
            .local_name = null,
            .namespace = .html,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = null,
            .doctype_public_id = null,
            .doctype_system_id = null,
            .force_quirks = false,
            .allocator = allocator,
        };
        return node;
    }

    /// Create a new DOCTYPE node.
    pub fn initDoctype(allocator: Allocator, name: ?[]const u8, public_id: ?[]const u8, system_id: ?[]const u8, force_quirks: bool) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .node_type = .doctype,
            .local_name = null,
            .namespace = .html,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = if (name) |n| try allocator.dupe(u8, n) else null,
            .doctype_public_id = if (public_id) |p| try allocator.dupe(u8, p) else null,
            .doctype_system_id = if (system_id) |s| try allocator.dupe(u8, s) else null,
            .force_quirks = force_quirks,
            .allocator = allocator,
        };
        return node;
    }

    /// Free resources.
    pub fn deinit(self: *TreeNode) void {
        // Free local name
        if (self.local_name) |name| {
            self.allocator.free(name);
        }
        // Free attributes
        const attrs = self.attributes.toSlice();
        for (attrs) |attr| {
            self.allocator.free(attr.name);
            self.allocator.free(attr.value);
        }
        self.attributes.deinit();
        // Free text content
        self.text_content.deinit();
        // Free DOCTYPE fields
        if (self.doctype_name) |n| self.allocator.free(n);
        if (self.doctype_public_id) |p| self.allocator.free(p);
        if (self.doctype_system_id) |s| self.allocator.free(s);
        // Free node itself
        self.allocator.destroy(self);
    }

    /// Append a child node.
    pub fn appendChild(self: *TreeNode, child: *TreeNode) void {
        child.parent = self;
        child.prev_sibling = self.last_child;
        child.next_sibling = null;

        if (self.last_child) |last| {
            last.next_sibling = child;
        } else {
            self.first_child = child;
        }
        self.last_child = child;
    }

    /// Add an attribute.
    pub fn addAttribute(self: *TreeNode, name: []const u8, value: []const u8, namespace: ?Namespace) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        try self.attributes.append(.{
            .name = name_copy,
            .value = value_copy,
            .namespace = namespace,
        });
    }

    /// Append text to text content.
    pub fn appendText(self: *TreeNode, text: []const u8) !void {
        try self.text_content.appendSlice(text);
    }

    /// Append a single character to text content.
    pub fn appendChar(self: *TreeNode, char: u21) !void {
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(char, &buf) catch {
            // Invalid codepoint, use replacement character
            try self.text_content.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.text_content.appendSlice(buf[0..len]);
    }

    /// Check if this element has a specific tag name.
    pub fn hasTagName(self: *const TreeNode, name: []const u8) bool {
        if (self.local_name) |local| {
            return std.mem.eql(u8, local, name);
        }
        return false;
    }

    /// Check if this is an element in the HTML namespace.
    pub fn isHtmlElement(self: *const TreeNode) bool {
        return self.node_type == .element and self.namespace == .html;
    }
};

/// HTML Tree Builder.
///
/// Implements the tree construction stage of the HTML parsing algorithm.
/// Takes tokens from the tokenizer and builds the DOM tree.
pub const TreeBuilder = struct {
    /// Memory allocator.
    allocator: Allocator,

    /// The tokenizer.
    tokenizer: *Tokenizer,

    /// The document being built.
    document: *TreeNode,

    /// Current insertion mode.
    insertion_mode: InsertionMode,

    /// Original insertion mode (for returning from text mode).
    original_insertion_mode: InsertionMode,

    /// Stack of open elements.
    /// HTML Standard §13.2.4.2: The stack grows downwards; the topmost
    /// node is the first one added.
    open_elements: infra.List(*TreeNode),

    /// List of active formatting elements.
    /// HTML Standard §13.2.4.3: Contains elements in formatting category
    /// and markers.
    active_formatting_elements: infra.List(FormattingEntry),

    /// Stack of template insertion modes.
    template_insertion_modes: infra.List(InsertionMode),

    /// Head element pointer.
    head_element: ?*TreeNode,

    /// Form element pointer.
    form_element: ?*TreeNode,

    /// Scripting flag.
    scripting_enabled: bool,

    /// Frameset-ok flag.
    frameset_ok: bool,

    /// Parser cannot change the mode flag.
    parser_cannot_change_mode: bool,

    /// Document quirks mode.
    quirks_mode: QuirksMode,

    /// Foster parenting flag.
    foster_parenting: bool,

    /// Error callback.
    error_callback: ?ParseErrorCallback,

    /// Error context.
    error_context: ?*anyopaque,

    /// Pending table character tokens for "in table text" mode.
    pending_table_char_tokens: infra.List(u21),

    /// Initialize a new tree builder.
    pub fn init(allocator: Allocator, tokenizer: *Tokenizer) !TreeBuilder {
        const document = try TreeNode.initDocument(allocator);
        return TreeBuilder{
            .allocator = allocator,
            .tokenizer = tokenizer,
            .document = document,
            .insertion_mode = .initial,
            .original_insertion_mode = .initial,
            .open_elements = infra.List(*TreeNode).init(allocator),
            .active_formatting_elements = infra.List(FormattingEntry).init(allocator),
            .template_insertion_modes = infra.List(InsertionMode).init(allocator),
            .head_element = null,
            .form_element = null,
            .scripting_enabled = false,
            .frameset_ok = true,
            .parser_cannot_change_mode = false,
            .quirks_mode = .no_quirks,
            .foster_parenting = false,
            .error_callback = null,
            .error_context = null,
            .pending_table_char_tokens = infra.List(u21).init(allocator),
        };
    }

    /// Free all resources.
    pub fn deinit(self: *TreeBuilder) void {
        // Free all nodes (document tree)
        self.freeTree(self.document);
        self.open_elements.deinit();
        self.active_formatting_elements.deinit();
        self.template_insertion_modes.deinit();
        self.pending_table_char_tokens.deinit();
    }

    /// Recursively free a tree of nodes.
    fn freeTree(self: *TreeBuilder, node: *TreeNode) void {
        // Free children first
        var child = node.first_child;
        while (child) |c| {
            const next = c.next_sibling;
            self.freeTree(c);
            child = next;
        }
        // Free the node itself
        node.deinit();
    }

    /// Set error callback for parse error reporting.
    pub fn setErrorCallback(self: *TreeBuilder, callback: ParseErrorCallback, context: ?*anyopaque) void {
        self.error_callback = callback;
        self.error_context = context;
    }

    /// Report a parse error.
    fn reportError(self: *TreeBuilder, code: ParseErrorCode) void {
        if (self.error_callback) |callback| {
            callback(.{ .code = code, .line = 0, .column = 0, .offset = 0 }, self.error_context);
        }
    }

    /// Get the current node (bottommost in stack of open elements).
    pub fn currentNode(self: *TreeBuilder) ?*TreeNode {
        if (self.open_elements.len > 0) {
            return self.open_elements.get(self.open_elements.len - 1);
        }
        return null;
    }

    /// Get the adjusted current node.
    /// HTML Standard §13.2.6: The adjusted current node is the context
    /// element if parsing a fragment with only one element in stack.
    pub fn adjustedCurrentNode(self: *TreeBuilder) ?*TreeNode {
        // For now, just return current node (fragment parsing not implemented)
        return self.currentNode();
    }

    /// Parse the entire document.
    pub fn parse(self: *TreeBuilder) !void {
        while (true) {
            const token = try self.tokenizer.nextToken();
            if (token == null) break;

            try self.processToken(token.?);

            // Check for EOF
            if (token.? == .eof) break;
        }
    }

    /// Process a single token.
    pub fn processToken(self: *TreeBuilder, token: Token) Allocator.Error!void {
        // Tree construction dispatcher
        // HTML Standard §13.2.6: Check if we should use foreign content rules
        const use_foreign = self.shouldUseForeignContent(token);

        if (use_foreign) {
            try self.processTokenInForeignContent(token);
        } else {
            try self.processTokenInHtmlContent(token);
        }
    }

    /// Determine if foreign content rules should be used.
    fn shouldUseForeignContent(self: *TreeBuilder, token: Token) bool {
        // HTML Standard §13.2.6: Use foreign content rules when:
        // - Stack is not empty
        // - Adjusted current node is not in HTML namespace
        // - Adjusted current node is not a MathML text integration point (with certain tokens)
        // - Adjusted current node is not an HTML integration point (with certain tokens)
        // - Token is not EOF

        if (self.open_elements.len == 0) return false;

        const current = self.adjustedCurrentNode() orelse return false;

        // If in HTML namespace, use HTML content rules
        if (current.namespace == .html) return false;

        // Check for MathML text integration point
        if (self.isMathMLTextIntegrationPoint(current)) {
            switch (token) {
                .start_tag => |tag| {
                    const name = tag.getTagName();
                    if (!std.mem.eql(u8, name, "mglyph") and !std.mem.eql(u8, name, "malignmark")) {
                        return false;
                    }
                },
                .character => return false,
                else => {},
            }
        }

        // Check for HTML integration point
        if (self.isHtmlIntegrationPoint(current)) {
            switch (token) {
                .start_tag, .character => return false,
                else => {},
            }
        }

        // EOF always uses HTML content rules
        if (token == .eof) return false;

        return true;
    }

    /// Check if node is a MathML text integration point.
    fn isMathMLTextIntegrationPoint(self: *TreeBuilder, node: *TreeNode) bool {
        _ = self;
        if (node.namespace != .mathml) return false;
        if (node.local_name) |name| {
            return std.mem.eql(u8, name, "mi") or
                std.mem.eql(u8, name, "mo") or
                std.mem.eql(u8, name, "mn") or
                std.mem.eql(u8, name, "ms") or
                std.mem.eql(u8, name, "mtext");
        }
        return false;
    }

    /// Check if node is an HTML integration point.
    fn isHtmlIntegrationPoint(self: *TreeBuilder, node: *TreeNode) bool {
        _ = self;
        // MathML annotation-xml with text/html or application/xhtml+xml encoding
        if (node.namespace == .mathml and node.hasTagName("annotation-xml")) {
            // Check encoding attribute (simplified - would need to check actual attribute)
            return true;
        }
        // SVG foreignObject, desc, title
        if (node.namespace == .svg) {
            if (node.local_name) |name| {
                return std.mem.eql(u8, name, "foreignObject") or
                    std.mem.eql(u8, name, "desc") or
                    std.mem.eql(u8, name, "title");
            }
        }
        return false;
    }

    /// Process token using HTML content rules.
    fn processTokenInHtmlContent(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (self.insertion_mode) {
            .initial => try self.handleInitialMode(token),
            .before_html => try self.handleBeforeHtmlMode(token),
            .before_head => try self.handleBeforeHeadMode(token),
            .in_head => try self.handleInHeadMode(token),
            .in_head_noscript => try self.handleInHeadNoscriptMode(token),
            .after_head => try self.handleAfterHeadMode(token),
            .in_body => try self.handleInBodyMode(token),
            .text => try self.handleTextMode(token),
            .in_table => try self.handleInTableMode(token),
            .in_table_text => try self.handleInTableTextMode(token),
            .in_caption => try self.handleInCaptionMode(token),
            .in_column_group => try self.handleInColumnGroupMode(token),
            .in_table_body => try self.handleInTableBodyMode(token),
            .in_row => try self.handleInRowMode(token),
            .in_cell => try self.handleInCellMode(token),
            .in_select => try self.handleInSelectMode(token),
            .in_select_in_table => try self.handleInSelectInTableMode(token),
            .in_template => try self.handleInTemplateMode(token),
            .after_body => try self.handleAfterBodyMode(token),
            .in_frameset => try self.handleInFramesetMode(token),
            .after_frameset => try self.handleAfterFramesetMode(token),
            .after_after_body => try self.handleAfterAfterBodyMode(token),
            .after_after_frameset => try self.handleAfterAfterFramesetMode(token),
        }
    }

    /// Process token in foreign content.
    ///
    /// HTML Standard §13.2.6.5: The rules for parsing tokens in foreign content.
    fn processTokenInForeignContent(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (char == 0x0000) {
                    // NULL: Parse error, insert U+FFFD REPLACEMENT CHARACTER
                    self.reportError(.unexpected_null_character);
                    try self.insertCharacter(0xFFFD);
                } else if (isHtmlWhitespace(char)) {
                    // Whitespace: Insert the token's character
                    try self.insertCharacter(char);
                } else {
                    // Any other character: Insert and set frameset-ok to "not ok"
                    try self.insertCharacter(char);
                    self.frameset_ok = false;
                }
            },
            .comment => |comment| {
                // Insert a comment
                try self.insertComment(comment);
            },
            .doctype => {
                // Parse error, ignore the token
                self.reportError(.unexpected_token_in_foreign_content);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();

                // Check for HTML breakout tags
                if (isForeignContentHtmlBreakout(name) or
                    (std.mem.eql(u8, name, "font") and hasFontBreakoutAttribute(tag)))
                {
                    // Parse error
                    self.reportError(.unexpected_token_in_foreign_content);

                    // Pop elements until we're back in HTML namespace or at an integration point
                    while (self.open_elements.len > 0) {
                        const current = self.currentNode() orelse break;
                        if (current.namespace == .html or
                            self.isMathMLTextIntegrationPoint(current) or
                            self.isHtmlIntegrationPoint(current))
                        {
                            break;
                        }
                        _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
                    }

                    // Reprocess the token according to the current insertion mode
                    try self.processTokenInHtmlContent(token);
                } else {
                    // Any other start tag
                    const adjusted_current = self.adjustedCurrentNode() orelse {
                        try self.processTokenInHtmlContent(token);
                        return;
                    };

                    // Determine namespace for the new element
                    const element_namespace = adjusted_current.namespace;
                    var element_name = name;

                    // If in SVG namespace, adjust tag name
                    if (adjusted_current.namespace == .svg) {
                        element_name = adjustSvgTagName(name);
                    }

                    // Create and insert the foreign element
                    const element = try TreeNode.initElement(self.allocator, element_name, element_namespace);

                    // Copy attributes (with namespace adjustments)
                    const attrs = tag.attributes.toSlice();
                    for (attrs) |attr| {
                        var attr_name = attr.getName();
                        var attr_namespace: ?Namespace = null;

                        // Adjust foreign attributes
                        if (adjusted_current.namespace == .mathml) {
                            const adjusted = adjustMathMLAttribute(attr_name);
                            attr_name = adjusted.name;
                        } else if (adjusted_current.namespace == .svg) {
                            const adjusted = adjustSvgAttribute(attr_name);
                            attr_name = adjusted.name;
                        }

                        // Check for namespaced attributes (xlink:, xml:, xmlns:)
                        const foreign_adjusted = adjustForeignAttribute(attr_name);
                        attr_name = foreign_adjusted.name;
                        attr_namespace = foreign_adjusted.namespace;

                        try element.addAttribute(attr_name, attr.getValue(), attr_namespace);
                    }

                    self.insertAtAppropriatePlace(element);
                    try self.open_elements.append(element);

                    // If self-closing, pop the element
                    if (tag.self_closing) {
                        _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                        // Acknowledge the self-closing flag
                    }
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();

                // "br" or "p" end tags break out of foreign content
                if (std.mem.eql(u8, name, "br") or std.mem.eql(u8, name, "p")) {
                    // Parse error
                    self.reportError(.unexpected_token_in_foreign_content);

                    // Pop elements until we're back in HTML namespace
                    while (self.open_elements.len > 0) {
                        const current = self.currentNode() orelse break;
                        if (current.namespace == .html or
                            self.isMathMLTextIntegrationPoint(current) or
                            self.isHtmlIntegrationPoint(current))
                        {
                            break;
                        }
                        _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
                    }

                    // Reprocess the token
                    try self.processTokenInHtmlContent(token);
                } else if (std.mem.eql(u8, name, "script") and
                    self.currentNode() != null and
                    self.currentNode().?.namespace == .svg and
                    self.currentNode().?.hasTagName("script"))
                {
                    // SVG script end tag - pop the script element
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    // Script execution would happen here
                } else {
                    // Any other end tag
                    var node_index: usize = self.open_elements.len;
                    while (node_index > 0) {
                        node_index -= 1;
                        const node = self.open_elements.get(node_index) orelse break;

                        if (node.namespace == .html) {
                            // Process according to current insertion mode
                            try self.processTokenInHtmlContent(token);
                            return;
                        }

                        if (node.local_name != null and
                            std.ascii.eqlIgnoreCase(node.local_name.?, name))
                        {
                            // Pop elements up to and including this node
                            while (self.open_elements.len > node_index) {
                                _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
                            }
                            return;
                        }
                    }
                }
            },
            .eof => {
                // Should not happen - EOF uses HTML content rules
                try self.processTokenInHtmlContent(token);
            },
        }
    }

    /// Check if tag name is an HTML breakout tag for foreign content.
    fn isForeignContentHtmlBreakout(name: []const u8) bool {
        const breakout_tags = [_][]const u8{
            "b",       "big",  "blockquote", "body",  "br",   "center",
            "code",    "dd",   "div",        "dl",    "dt",   "em",
            "embed",   "h1",   "h2",         "h3",    "h4",   "h5",
            "h6",      "head", "hr",         "i",     "img",  "li",
            "listing", "menu", "meta",       "nobr",  "ol",   "p",
            "pre",     "ruby", "s",          "small", "span", "strong",
            "strike",  "sub",  "sup",        "table", "tt",   "u",
            "ul",      "var",
        };
        for (breakout_tags) |tag| {
            if (std.mem.eql(u8, name, tag)) return true;
        }
        return false;
    }

    /// Check if font tag has breakout attributes (color, face, size).
    fn hasFontBreakoutAttribute(tag: TagToken) bool {
        const attrs = tag.attributes.toSlice();
        for (attrs) |attr| {
            const attr_name = attr.getName();
            if (std.mem.eql(u8, attr_name, "color") or
                std.mem.eql(u8, attr_name, "face") or
                std.mem.eql(u8, attr_name, "size"))
            {
                return true;
            }
        }
        return false;
    }

    /// Adjust SVG tag name (case correction).
    fn adjustSvgTagName(name: []const u8) []const u8 {
        // Map lowercase to proper case for SVG elements
        const svg_tag_map = [_]struct { from: []const u8, to: []const u8 }{
            .{ .from = "altglyph", .to = "altGlyph" },
            .{ .from = "altglyphdef", .to = "altGlyphDef" },
            .{ .from = "altglyphitem", .to = "altGlyphItem" },
            .{ .from = "animatecolor", .to = "animateColor" },
            .{ .from = "animatemotion", .to = "animateMotion" },
            .{ .from = "animatetransform", .to = "animateTransform" },
            .{ .from = "clippath", .to = "clipPath" },
            .{ .from = "feblend", .to = "feBlend" },
            .{ .from = "fecolormatrix", .to = "feColorMatrix" },
            .{ .from = "fecomponenttransfer", .to = "feComponentTransfer" },
            .{ .from = "fecomposite", .to = "feComposite" },
            .{ .from = "feconvolvematrix", .to = "feConvolveMatrix" },
            .{ .from = "fediffuselighting", .to = "feDiffuseLighting" },
            .{ .from = "fedisplacementmap", .to = "feDisplacementMap" },
            .{ .from = "fedistantlight", .to = "feDistantLight" },
            .{ .from = "fedropshadow", .to = "feDropShadow" },
            .{ .from = "feflood", .to = "feFlood" },
            .{ .from = "fefunca", .to = "feFuncA" },
            .{ .from = "fefuncb", .to = "feFuncB" },
            .{ .from = "fefuncg", .to = "feFuncG" },
            .{ .from = "fefuncr", .to = "feFuncR" },
            .{ .from = "fegaussianblur", .to = "feGaussianBlur" },
            .{ .from = "feimage", .to = "feImage" },
            .{ .from = "femerge", .to = "feMerge" },
            .{ .from = "femergenode", .to = "feMergeNode" },
            .{ .from = "femorphology", .to = "feMorphology" },
            .{ .from = "feoffset", .to = "feOffset" },
            .{ .from = "fepointlight", .to = "fePointLight" },
            .{ .from = "fespecularlighting", .to = "feSpecularLighting" },
            .{ .from = "fespotlight", .to = "feSpotLight" },
            .{ .from = "fetile", .to = "feTile" },
            .{ .from = "feturbulence", .to = "feTurbulence" },
            .{ .from = "foreignobject", .to = "foreignObject" },
            .{ .from = "glyphref", .to = "glyphRef" },
            .{ .from = "lineargradient", .to = "linearGradient" },
            .{ .from = "radialgradient", .to = "radialGradient" },
            .{ .from = "textpath", .to = "textPath" },
        };

        for (svg_tag_map) |entry| {
            if (std.mem.eql(u8, name, entry.from)) {
                return entry.to;
            }
        }
        return name;
    }

    /// Adjust MathML attribute (case correction).
    fn adjustMathMLAttribute(name: []const u8) struct { name: []const u8 } {
        // MathML attribute adjustment (definitionurl -> definitionURL)
        if (std.mem.eql(u8, name, "definitionurl")) {
            return .{ .name = "definitionURL" };
        }
        return .{ .name = name };
    }

    /// Adjust SVG attribute (case correction).
    fn adjustSvgAttribute(name: []const u8) struct { name: []const u8 } {
        // SVG attribute case adjustments
        const svg_attr_map = [_]struct { from: []const u8, to: []const u8 }{
            .{ .from = "attributename", .to = "attributeName" },
            .{ .from = "attributetype", .to = "attributeType" },
            .{ .from = "basefrequency", .to = "baseFrequency" },
            .{ .from = "baseprofile", .to = "baseProfile" },
            .{ .from = "calcmode", .to = "calcMode" },
            .{ .from = "clippathunits", .to = "clipPathUnits" },
            .{ .from = "diffuseconstant", .to = "diffuseConstant" },
            .{ .from = "edgemode", .to = "edgeMode" },
            .{ .from = "filterunits", .to = "filterUnits" },
            .{ .from = "glyphref", .to = "glyphRef" },
            .{ .from = "gradienttransform", .to = "gradientTransform" },
            .{ .from = "gradientunits", .to = "gradientUnits" },
            .{ .from = "kernelmatrix", .to = "kernelMatrix" },
            .{ .from = "kernelunitlength", .to = "kernelUnitLength" },
            .{ .from = "keypoints", .to = "keyPoints" },
            .{ .from = "keysplines", .to = "keySplines" },
            .{ .from = "keytimes", .to = "keyTimes" },
            .{ .from = "lengthadjust", .to = "lengthAdjust" },
            .{ .from = "limitingconeangle", .to = "limitingConeAngle" },
            .{ .from = "markerheight", .to = "markerHeight" },
            .{ .from = "markerunits", .to = "markerUnits" },
            .{ .from = "markerwidth", .to = "markerWidth" },
            .{ .from = "maskcontentunits", .to = "maskContentUnits" },
            .{ .from = "maskunits", .to = "maskUnits" },
            .{ .from = "numoctaves", .to = "numOctaves" },
            .{ .from = "pathlength", .to = "pathLength" },
            .{ .from = "patterncontentunits", .to = "patternContentUnits" },
            .{ .from = "patterntransform", .to = "patternTransform" },
            .{ .from = "patternunits", .to = "patternUnits" },
            .{ .from = "pointsatx", .to = "pointsAtX" },
            .{ .from = "pointsaty", .to = "pointsAtY" },
            .{ .from = "pointsatz", .to = "pointsAtZ" },
            .{ .from = "preservealpha", .to = "preserveAlpha" },
            .{ .from = "preserveaspectratio", .to = "preserveAspectRatio" },
            .{ .from = "primitiveunits", .to = "primitiveUnits" },
            .{ .from = "refx", .to = "refX" },
            .{ .from = "refy", .to = "refY" },
            .{ .from = "repeatcount", .to = "repeatCount" },
            .{ .from = "repeatdur", .to = "repeatDur" },
            .{ .from = "requiredextensions", .to = "requiredExtensions" },
            .{ .from = "requiredfeatures", .to = "requiredFeatures" },
            .{ .from = "specularconstant", .to = "specularConstant" },
            .{ .from = "specularexponent", .to = "specularExponent" },
            .{ .from = "spreadmethod", .to = "spreadMethod" },
            .{ .from = "startoffset", .to = "startOffset" },
            .{ .from = "stddeviation", .to = "stdDeviation" },
            .{ .from = "stitchtiles", .to = "stitchTiles" },
            .{ .from = "surfacescale", .to = "surfaceScale" },
            .{ .from = "systemlanguage", .to = "systemLanguage" },
            .{ .from = "tablevalues", .to = "tableValues" },
            .{ .from = "targetx", .to = "targetX" },
            .{ .from = "targety", .to = "targetY" },
            .{ .from = "textlength", .to = "textLength" },
            .{ .from = "viewbox", .to = "viewBox" },
            .{ .from = "viewtarget", .to = "viewTarget" },
            .{ .from = "xchannelselector", .to = "xChannelSelector" },
            .{ .from = "ychannelselector", .to = "yChannelSelector" },
            .{ .from = "zoomandpan", .to = "zoomAndPan" },
        };

        for (svg_attr_map) |entry| {
            if (std.mem.eql(u8, name, entry.from)) {
                return .{ .name = entry.to };
            }
        }
        return .{ .name = name };
    }

    /// Adjust foreign attributes (xlink:, xml:, xmlns: namespace handling).
    fn adjustForeignAttribute(name: []const u8) struct { name: []const u8, namespace: ?Namespace } {
        // Check for namespaced attributes
        if (std.mem.startsWith(u8, name, "xlink:")) {
            return .{ .name = name[6..], .namespace = null }; // XLink namespace
        }
        if (std.mem.startsWith(u8, name, "xml:")) {
            return .{ .name = name[4..], .namespace = null }; // XML namespace
        }
        if (std.mem.eql(u8, name, "xmlns") or std.mem.startsWith(u8, name, "xmlns:")) {
            return .{ .name = name, .namespace = null }; // XMLNS namespace
        }
        return .{ .name = name, .namespace = null };
    }

    // =========================================================================
    // Insertion Mode Handlers
    // =========================================================================

    /// Handle token in "initial" insertion mode.
    /// HTML Standard §13.2.6.4.1
    fn handleInitialMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                // Ignore whitespace
                if (isHtmlWhitespace(char)) return;
                // Fall through to anything else
                self.handleInitialAnythingElse(token);
            },
            .comment => |comment| {
                // Insert comment as last child of Document
                const node = try TreeNode.initComment(self.allocator);
                try node.appendText(comment.getData());
                self.document.appendChild(node);
            },
            .doctype => |doctype| {
                // Handle DOCTYPE
                try self.handleInitialDoctype(doctype);
            },
            else => {
                self.handleInitialAnythingElse(token);
            },
        }
    }

    fn handleInitialDoctype(self: *TreeBuilder, doctype: DoctypeToken) !void {
        const name = doctype.getName();
        const public_id = doctype.getPublicIdentifier();
        const system_id = doctype.getSystemIdentifier();

        // Check for parse errors (non-conforming DOCTYPE)
        const is_html = if (name) |n| std.mem.eql(u8, n, "html") else false;
        if (!is_html or public_id != null or (system_id != null and !std.mem.eql(u8, system_id.?, "about:legacy-compat"))) {
            self.reportError(.invalid_character_sequence_after_doctype_name);
        }

        // Append DocumentType node
        const doctype_node = try TreeNode.initDoctype(
            self.allocator,
            name,
            public_id,
            system_id,
            doctype.force_quirks,
        );
        self.document.appendChild(doctype_node);

        // Set quirks mode based on DOCTYPE
        if (!self.parser_cannot_change_mode) {
            if (doctype.force_quirks) {
                self.quirks_mode = .quirks;
            } else if (self.shouldSetQuirksMode(name, public_id, system_id)) {
                self.quirks_mode = .quirks;
            } else if (self.shouldSetLimitedQuirksMode(public_id, system_id)) {
                self.quirks_mode = .limited_quirks;
            }
        }

        // Switch to "before html" mode
        self.insertion_mode = .before_html;
    }

    fn shouldSetQuirksMode(self: *TreeBuilder, name: ?[]const u8, public_id: ?[]const u8, system_id: ?[]const u8) bool {
        _ = self;
        // Check name
        if (name) |n| {
            if (!std.ascii.eqlIgnoreCase(n, "html")) return true;
        } else {
            return true;
        }

        // Check system identifier
        if (system_id) |sid| {
            if (std.ascii.eqlIgnoreCase(sid, "http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd")) {
                return true;
            }
        }

        // Check public identifier (simplified - full list is very long)
        if (public_id) |pid| {
            const quirks_prefixes = [_][]const u8{
                "-//W3O//DTD W3 HTML Strict 3.0//EN//",
                "HTML",
                "-//IETF//DTD HTML",
                "-//W3C//DTD HTML 3",
                "-//W3C//DTD HTML 4.0 Frameset//",
                "-//W3C//DTD HTML 4.0 Transitional//",
            };
            for (quirks_prefixes) |prefix| {
                if (std.ascii.startsWithIgnoreCase(pid, prefix)) {
                    return true;
                }
            }
        }

        return false;
    }

    fn shouldSetLimitedQuirksMode(self: *TreeBuilder, public_id: ?[]const u8, system_id: ?[]const u8) bool {
        _ = self;
        _ = system_id;
        if (public_id) |pid| {
            if (std.ascii.startsWithIgnoreCase(pid, "-//W3C//DTD XHTML 1.0 Frameset//") or
                std.ascii.startsWithIgnoreCase(pid, "-//W3C//DTD XHTML 1.0 Transitional//"))
            {
                return true;
            }
        }
        return false;
    }

    fn handleInitialAnythingElse(self: *TreeBuilder, token: Token) void {
        // Parse error if not iframe srcdoc
        self.reportError(.missing_doctype_name);
        // Set quirks mode
        if (!self.parser_cannot_change_mode) {
            self.quirks_mode = .quirks;
        }
        // Switch to "before html" and reprocess
        self.insertion_mode = .before_html;
        // Reprocess is handled by caller returning and re-calling processToken
        self.processToken(token) catch {};
    }

    /// Handle token in "before html" insertion mode.
    /// HTML Standard §13.2.6.4.2
    fn handleBeforeHtmlMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .doctype => {
                // Parse error, ignore
                self.reportError(.missing_doctype_name);
            },
            .comment => |comment| {
                // Insert comment as last child of Document
                const node = try TreeNode.initComment(self.allocator);
                try node.appendText(comment.getData());
                self.document.appendChild(node);
            },
            .character => |char| {
                // Ignore whitespace
                if (isHtmlWhitespace(char)) return;
                // Fall through to anything else
                try self.handleBeforeHtmlAnythingElse();
                try self.processToken(token);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    // Create html element and append to document
                    const html = try self.createElementForToken(tag, .html);
                    self.document.appendChild(html);
                    try self.open_elements.append(html);
                    self.insertion_mode = .before_head;
                } else {
                    try self.handleBeforeHtmlAnythingElse();
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "head") or
                    std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "br"))
                {
                    try self.handleBeforeHtmlAnythingElse();
                    try self.processToken(token);
                } else {
                    // Parse error, ignore
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleBeforeHtmlAnythingElse();
                try self.processToken(token);
            },
        }
    }

    fn handleBeforeHtmlAnythingElse(self: *TreeBuilder) !void {
        // Create html element and append to document
        const html = try TreeNode.initElement(self.allocator, "html", .html);
        self.document.appendChild(html);
        try self.open_elements.append(html);
        self.insertion_mode = .before_head;
    }

    /// Handle token in "before head" insertion mode.
    /// HTML Standard §13.2.6.4.3
    fn handleBeforeHeadMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) return;
                try self.handleBeforeHeadAnythingElse();
                try self.processToken(token);
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "head")) {
                    const head = try self.insertHtmlElement(tag);
                    self.head_element = head;
                    self.insertion_mode = .in_head;
                } else {
                    try self.handleBeforeHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "head") or
                    std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "br"))
                {
                    try self.handleBeforeHeadAnythingElse();
                    try self.processToken(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleBeforeHeadAnythingElse();
                try self.processToken(token);
            },
        }
    }

    fn handleBeforeHeadAnythingElse(self: *TreeBuilder) !void {
        // Insert implicit head element
        const dummy_tag = TagToken.init(self.allocator, false);
        // We need to set tag name - for now create element directly
        const head = try TreeNode.initElement(self.allocator, "head", .html);
        self.insertAtAppropriatePlace(head);
        try self.open_elements.append(head);
        self.head_element = head;
        _ = dummy_tag;
        self.insertion_mode = .in_head;
    }

    /// Handle token in "in head" insertion mode.
    /// HTML Standard §13.2.6.4.4
    fn handleInHeadMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    try self.handleInHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "base") or
                    std.mem.eql(u8, name, "basefont") or
                    std.mem.eql(u8, name, "bgsound") or
                    std.mem.eql(u8, name, "link"))
                {
                    _ = try self.insertHtmlElement(tag);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch unreachable;
                    // Acknowledge self-closing flag
                } else if (std.mem.eql(u8, name, "meta")) {
                    _ = try self.insertHtmlElement(tag);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch unreachable;

                    // Handle charset/encoding from meta element
                    // HTML Standard §4.2.5.4: Specifying the document's character encoding
                    // Check for charset attribute or http-equiv="Content-Type" with charset
                    if (tag.getAttribute("charset") != null) {
                        // charset attribute specifies encoding directly
                        // In a full implementation, this would trigger encoding change
                        // if parsing a byte stream with tentative encoding
                    } else if (tag.getAttribute("http-equiv")) |http_equiv| {
                        const http_equiv_val = http_equiv.getValue();
                        if (std.ascii.eqlIgnoreCase(http_equiv_val, "Content-Type")) {
                            // content attribute should contain charset parameter
                            if (tag.getAttribute("content")) |content| {
                                _ = extractCharsetFromContentType(content.getValue());
                                // Would trigger encoding change if needed
                            }
                        }
                    }
                } else if (std.mem.eql(u8, name, "title")) {
                    try self.parseGenericRCDATA(tag);
                } else if (std.mem.eql(u8, name, "noscript") and self.scripting_enabled) {
                    try self.parseGenericRawText(tag);
                } else if (std.mem.eql(u8, name, "noframes") or
                    std.mem.eql(u8, name, "style"))
                {
                    try self.parseGenericRawText(tag);
                } else if (std.mem.eql(u8, name, "noscript") and !self.scripting_enabled) {
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_head_noscript;
                } else if (std.mem.eql(u8, name, "script")) {
                    try self.handleScriptStartTag(tag);
                } else if (std.mem.eql(u8, name, "template")) {
                    _ = try self.insertHtmlElement(tag);
                    try self.active_formatting_elements.append(.marker);
                    self.frameset_ok = false;
                    self.insertion_mode = .in_template;
                    try self.template_insertion_modes.append(.in_template);
                } else if (std.mem.eql(u8, name, "head")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                } else {
                    try self.handleInHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "head")) {
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch unreachable;
                    self.insertion_mode = .after_head;
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "br"))
                {
                    try self.handleInHeadAnythingElse();
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleTemplateEndTag();
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleInHeadAnythingElse();
                try self.processToken(token);
            },
        }
    }

    fn handleInHeadAnythingElse(self: *TreeBuilder) !void {
        // Pop head and switch to after_head
        _ = self.open_elements.remove(self.open_elements.len - 1) catch unreachable;
        self.insertion_mode = .after_head;
    }

    fn handleScriptStartTag(self: *TreeBuilder, tag: TagToken) !void {
        // Insert script element
        _ = try self.insertHtmlElement(tag);
        self.tokenizer.state = .script_data;
        self.original_insertion_mode = self.insertion_mode;
        self.insertion_mode = .text;
    }

    fn handleTemplateEndTag(self: *TreeBuilder) !void {
        // Check if template is in stack
        var has_template = false;
        const elements = self.open_elements.toSlice();
        for (elements) |elem| {
            if (elem.hasTagName("template")) {
                has_template = true;
                break;
            }
        }
        if (!has_template) {
            self.reportError(.invalid_first_character_of_tag_name);
            return;
        }

        // Generate all implied end tags thoroughly
        try self.generateAllImpliedEndTagsThoroughly();

        // Check if current node is template
        if (self.currentNode()) |current| {
            if (!current.hasTagName("template")) {
                self.reportError(.invalid_first_character_of_tag_name);
            }
        }

        // Pop elements until template
        while (self.open_elements.len > 0) {
            const elem = self.open_elements.remove(self.open_elements.len - 1) catch break;
            if (elem.hasTagName("template")) break;
        }

        // Clear active formatting elements to last marker
        self.clearActiveFormattingToMarker();

        // Pop template insertion mode
        if (self.template_insertion_modes.len > 0) {
            _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
        }

        // Reset insertion mode appropriately
        self.resetInsertionModeAppropriately();
    }

    /// Handle token in "in head noscript" insertion mode.
    fn handleInHeadNoscriptMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "basefont") or
                    std.mem.eql(u8, name, "bgsound") or
                    std.mem.eql(u8, name, "link") or
                    std.mem.eql(u8, name, "meta") or
                    std.mem.eql(u8, name, "noframes") or
                    std.mem.eql(u8, name, "style"))
                {
                    try self.handleInHeadMode(token);
                } else if (std.mem.eql(u8, name, "head") or std.mem.eql(u8, name, "noscript")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_head;
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "noscript")) {
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_head;
                } else if (std.mem.eql(u8, name, "br")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_head;
                    try self.processToken(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_head;
                    try self.processToken(token);
                }
            },
            .comment => {
                try self.handleInHeadMode(token);
            },
            .eof => {
                self.reportError(.invalid_first_character_of_tag_name);
                _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                self.insertion_mode = .in_head;
                try self.processToken(token);
            },
        }
    }

    /// Handle token in "after head" insertion mode.
    fn handleAfterHeadMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    try self.handleAfterHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "body")) {
                    _ = try self.insertHtmlElement(tag);
                    self.frameset_ok = false;
                    self.insertion_mode = .in_body;
                } else if (std.mem.eql(u8, name, "frameset")) {
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_frameset;
                } else if (std.mem.eql(u8, name, "base") or
                    std.mem.eql(u8, name, "basefont") or
                    std.mem.eql(u8, name, "bgsound") or
                    std.mem.eql(u8, name, "link") or
                    std.mem.eql(u8, name, "meta") or
                    std.mem.eql(u8, name, "noframes") or
                    std.mem.eql(u8, name, "script") or
                    std.mem.eql(u8, name, "style") or
                    std.mem.eql(u8, name, "template") or
                    std.mem.eql(u8, name, "title"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Push head back onto stack
                    if (self.head_element) |head| {
                        try self.open_elements.append(head);
                        try self.handleInHeadMode(token);
                        // Remove head from stack
                        var i: usize = 0;
                        while (i < self.open_elements.len) : (i += 1) {
                            if (self.open_elements.get(i) == head) {
                                _ = self.open_elements.remove(i) catch {};
                                break;
                            }
                        }
                    }
                } else if (std.mem.eql(u8, name, "head")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                } else {
                    try self.handleAfterHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "br"))
                {
                    try self.handleAfterHeadAnythingElse();
                    try self.processToken(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleAfterHeadAnythingElse();
                try self.processToken(token);
            },
        }
    }

    fn handleAfterHeadAnythingElse(self: *TreeBuilder) !void {
        // Insert implicit body element
        const body = try TreeNode.initElement(self.allocator, "body", .html);
        self.insertAtAppropriatePlace(body);
        try self.open_elements.append(body);
        self.insertion_mode = .in_body;
    }

    /// Handle token in "in body" insertion mode.
    /// HTML Standard §13.2.6.4.7 (simplified)
    fn handleInBodyMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (char == 0) {
                    self.reportError(.unexpected_null_character);
                } else {
                    // Reconstruct active formatting elements
                    try self.reconstructActiveFormattingElements();
                    try self.insertCharacter(char);
                    if (!isHtmlWhitespace(char)) {
                        self.frameset_ok = false;
                    }
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                try self.handleInBodyStartTag(tag);
            },
            .end_tag => |tag| {
                try self.handleInBodyEndTag(tag);
            },
            .eof => {
                // Check for unclosed elements
                if (self.template_insertion_modes.len > 0) {
                    try self.handleInTemplateMode(token);
                } else {
                    // Stop parsing
                }
            },
        }
    }

    fn handleInBodyStartTag(self: *TreeBuilder, tag: TagToken) !void {
        const name = tag.getTagName();

        if (std.mem.eql(u8, name, "html")) {
            self.reportError(.invalid_first_character_of_tag_name);

            // Add attributes from the token to the html element if they don't exist
            // HTML Standard §13.2.6.4.7: "Otherwise, for each attribute on the token,
            // check to see if the attribute is already present on the top element of
            // the stack of open elements. If it is not, add the attribute and its
            // corresponding value to that element."
            if (self.open_elements.len > 0) {
                if (self.open_elements.get(0)) |html_element| {
                    try self.copyMissingAttributes(html_element, tag);
                }
            }
        } else if (std.mem.eql(u8, name, "base") or
            std.mem.eql(u8, name, "basefont") or
            std.mem.eql(u8, name, "bgsound") or
            std.mem.eql(u8, name, "link") or
            std.mem.eql(u8, name, "meta") or
            std.mem.eql(u8, name, "noframes") or
            std.mem.eql(u8, name, "script") or
            std.mem.eql(u8, name, "style") or
            std.mem.eql(u8, name, "template") or
            std.mem.eql(u8, name, "title"))
        {
            try self.handleInHeadMode(Token{ .start_tag = tag });
        } else if (std.mem.eql(u8, name, "body")) {
            self.reportError(.invalid_first_character_of_tag_name);

            // Add attributes to body element if not already present
            // HTML Standard §13.2.6.4.7: Similar to html element handling
            // Find the body element (second element on stack if present)
            if (self.open_elements.len >= 2) {
                if (self.open_elements.get(1)) |body_candidate| {
                    if (body_candidate.hasTagName("body")) {
                        try self.copyMissingAttributes(body_candidate, tag);
                        self.frameset_ok = false;
                    }
                }
            }
        } else if (std.mem.eql(u8, name, "frameset")) {
            self.reportError(.invalid_first_character_of_tag_name);
            // Ignore unless frameset_ok
        } else if (isSpecialBlockElement(name)) {
            try self.closePElementIfInButtonScope();
            _ = try self.insertHtmlElement(tag);
        } else if (std.mem.eql(u8, name, "a")) {
            // Check for active formatting element with same tag
            try self.reconstructActiveFormattingElements();
            const element = try self.insertHtmlElement(tag);
            try self.pushOntoActiveFormattingElements(element, tag);
        } else if (isFormattingElement(name)) {
            try self.reconstructActiveFormattingElements();
            const element = try self.insertHtmlElement(tag);
            try self.pushOntoActiveFormattingElements(element, tag);
        } else if (std.mem.eql(u8, name, "br")) {
            try self.reconstructActiveFormattingElements();
            _ = try self.insertHtmlElement(tag);
            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
            self.frameset_ok = false;
        } else if (isVoidElement(name)) {
            try self.reconstructActiveFormattingElements();
            _ = try self.insertHtmlElement(tag);
            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
        } else {
            // Generic handling for other start tags
            try self.reconstructActiveFormattingElements();
            _ = try self.insertHtmlElement(tag);
        }
    }

    fn handleInBodyEndTag(self: *TreeBuilder, tag: TagToken) !void {
        const name = tag.getTagName();

        if (std.mem.eql(u8, name, "template")) {
            try self.handleInHeadMode(Token{ .end_tag = tag });
        } else if (std.mem.eql(u8, name, "body")) {
            if (!self.hasElementInScope("body")) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            self.insertion_mode = .after_body;
        } else if (std.mem.eql(u8, name, "html")) {
            if (!self.hasElementInScope("body")) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            self.insertion_mode = .after_body;
            try self.processToken(Token{ .end_tag = tag });
        } else if (isSpecialBlockElement(name)) {
            if (!self.hasElementInScope(name)) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            self.generateImpliedEndTags(name);
            if (self.currentNode()) |current| {
                if (!current.hasTagName(name)) {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            }
            self.popUntilTagName(name);
        } else if (isFormattingElement(name)) {
            try self.adoptionAgencyAlgorithm(name);
        } else {
            // Any other end tag
            try self.handleAnyOtherEndTag(name);
        }
    }

    fn handleAnyOtherEndTag(self: *TreeBuilder, name: []const u8) !void {
        // Walk through stack from bottom to top
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;

            if (node.hasTagName(name)) {
                self.generateImpliedEndTags(name);
                if (self.currentNode()) |current| {
                    if (!current.hasTagName(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                    }
                }
                // Pop until and including this element
                while (self.open_elements.len > i) {
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
                }
                break;
            }

            if (self.isSpecialElement(node)) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
        }
    }

    /// Handle token in "text" insertion mode.
    fn handleTextMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                try self.insertCharacter(char);
            },
            .eof => {
                self.reportError(.eof_in_tag);
                _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                self.insertion_mode = self.original_insertion_mode;
                try self.processToken(token);
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "script")) {
                    // TODO: Execute script
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = self.original_insertion_mode;
                } else {
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = self.original_insertion_mode;
                }
            },
            else => {},
        }
    }

    /// Handle token in "in table" insertion mode.
    /// HTML Standard §13.2.6.4.9
    fn handleInTableMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => {
                // Character token, if current node is table/tbody/template/tfoot/thead/tr
                if (self.currentNode()) |current| {
                    if (current.hasTagName("table") or
                        current.hasTagName("tbody") or
                        current.hasTagName("template") or
                        current.hasTagName("tfoot") or
                        current.hasTagName("thead") or
                        current.hasTagName("tr"))
                    {
                        // Clear pending table character tokens
                        self.pending_table_char_tokens.clear();
                        self.original_insertion_mode = self.insertion_mode;
                        self.insertion_mode = .in_table_text;
                        try self.processToken(token);
                        return;
                    }
                }
                // Otherwise process as "anything else"
                self.reportError(.invalid_first_character_of_tag_name);
                self.foster_parenting = true;
                try self.handleInBodyMode(token);
                self.foster_parenting = false;
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption")) {
                    self.clearStackBackToTableContext();
                    try self.active_formatting_elements.append(.marker);
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_caption;
                } else if (std.mem.eql(u8, name, "colgroup")) {
                    self.clearStackBackToTableContext();
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_column_group;
                } else if (std.mem.eql(u8, name, "col")) {
                    self.clearStackBackToTableContext();
                    // Insert implicit colgroup
                    const colgroup = try TreeNode.initElement(self.allocator, "colgroup", .html);
                    self.insertAtAppropriatePlace(colgroup);
                    try self.open_elements.append(colgroup);
                    self.insertion_mode = .in_column_group;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    self.clearStackBackToTableContext();
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_table_body;
                } else if (std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "tr"))
                {
                    self.clearStackBackToTableContext();
                    // Insert implicit tbody
                    const tbody = try TreeNode.initElement(self.allocator, "tbody", .html);
                    self.insertAtAppropriatePlace(tbody);
                    try self.open_elements.append(tbody);
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "table")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (!self.hasElementInTableScope("table")) {
                        return; // Ignore
                    }
                    self.popUntilTagName("table");
                    self.resetInsertionModeAppropriately();
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "style") or
                    std.mem.eql(u8, name, "script") or
                    std.mem.eql(u8, name, "template"))
                {
                    try self.handleInHeadMode(token);
                } else if (std.mem.eql(u8, name, "input")) {
                    // Check for hidden type
                    if (self.hasTypeHiddenAttribute(tag)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        _ = try self.insertHtmlElement(tag);
                        _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    } else {
                        // Anything else
                        self.reportError(.invalid_first_character_of_tag_name);
                        self.foster_parenting = true;
                        try self.handleInBodyMode(token);
                        self.foster_parenting = false;
                    }
                } else if (std.mem.eql(u8, name, "form")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (self.hasTemplateInStack() or self.form_element != null) {
                        return; // Ignore
                    }
                    const form = try self.insertHtmlElement(tag);
                    self.form_element = form;
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                } else {
                    // Anything else
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.foster_parenting = true;
                    try self.handleInBodyMode(token);
                    self.foster_parenting = false;
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "table")) {
                    if (!self.hasElementInTableScope("table")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.popUntilTagName("table");
                    self.resetInsertionModeAppropriately();
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    // Anything else
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.foster_parenting = true;
                    try self.handleInBodyMode(token);
                    self.foster_parenting = false;
                }
            },
            .eof => {
                try self.handleInBodyMode(token);
            },
        }
    }

    /// Handle token in "in table text" insertion mode.
    /// HTML Standard §13.2.6.4.10
    fn handleInTableTextMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (char == 0) {
                    self.reportError(.unexpected_null_character);
                    return;
                }
                try self.pending_table_char_tokens.append(char);
            },
            else => {
                // Anything else - process pending characters
                var has_non_whitespace = false;
                for (0..self.pending_table_char_tokens.len) |i| {
                    const c = self.pending_table_char_tokens.get(i) orelse continue;
                    if (!isHtmlWhitespace(c)) {
                        has_non_whitespace = true;
                        break;
                    }
                }

                if (has_non_whitespace) {
                    // Parse error, process with foster parenting
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.foster_parenting = true;
                    for (0..self.pending_table_char_tokens.len) |i| {
                        const c = self.pending_table_char_tokens.get(i) orelse continue;
                        try self.insertCharacter(c);
                    }
                    self.foster_parenting = false;
                } else {
                    // Insert whitespace characters
                    for (0..self.pending_table_char_tokens.len) |i| {
                        const c = self.pending_table_char_tokens.get(i) orelse continue;
                        try self.insertCharacter(c);
                    }
                }

                self.pending_table_char_tokens.clear();
                self.insertion_mode = self.original_insertion_mode;
                try self.processToken(token);
            },
        }
    }

    /// Handle token in "in caption" insertion mode.
    /// HTML Standard §13.2.6.4.11
    fn handleInCaptionMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption")) {
                    if (!self.hasElementInTableScope("caption")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.generateImpliedEndTags(null);
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("caption")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                    self.popUntilTagName("caption");
                    self.clearActiveFormattingToMarker();
                    self.insertion_mode = .in_table;
                } else if (std.mem.eql(u8, name, "table")) {
                    if (!self.hasElementInTableScope("caption")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.generateImpliedEndTags(null);
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("caption")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                    self.popUntilTagName("caption");
                    self.clearActiveFormattingToMarker();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else {
                    try self.handleInBodyMode(token);
                }
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    if (!self.hasElementInTableScope("caption")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.generateImpliedEndTags(null);
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("caption")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                    self.popUntilTagName("caption");
                    self.clearActiveFormattingToMarker();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else {
                    try self.handleInBodyMode(token);
                }
            },
            else => {
                try self.handleInBodyMode(token);
            },
        }
    }

    /// Handle token in "in column group" insertion mode.
    /// HTML Standard §13.2.6.4.12
    fn handleInColumnGroupMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    // Anything else
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("colgroup")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "col")) {
                    _ = try self.insertHtmlElement(tag);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    // Anything else
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("colgroup")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "colgroup")) {
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("colgroup")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table;
                } else if (std.mem.eql(u8, name, "col")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    // Anything else
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("colgroup")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                }
            },
            .eof => {
                try self.handleInBodyMode(token);
            },
        }
    }

    /// Handle token in "in table body" insertion mode.
    /// HTML Standard §13.2.6.4.13
    fn handleInTableBodyMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "tr")) {
                    self.clearStackBackToTableBodyContext();
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_row;
                } else if (std.mem.eql(u8, name, "th") or std.mem.eql(u8, name, "td")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.clearStackBackToTableBodyContext();
                    // Insert implicit tr
                    const tr = try TreeNode.initElement(self.allocator, "tr", .html);
                    self.insertAtAppropriatePlace(tr);
                    try self.open_elements.append(tr);
                    self.insertion_mode = .in_row;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    if (!self.hasTableBodyElementInTableScope()) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableBodyContext();
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else {
                    try self.handleInTableMode(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    if (!self.hasElementInTableScope(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableBodyContext();
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table;
                } else if (std.mem.eql(u8, name, "table")) {
                    if (!self.hasTableBodyElementInTableScope()) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableBodyContext();
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "tr"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else {
                    try self.handleInTableMode(token);
                }
            },
            else => {
                try self.handleInTableMode(token);
            },
        }
    }

    /// Handle token in "in row" insertion mode.
    /// HTML Standard §13.2.6.4.14
    fn handleInRowMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "th") or std.mem.eql(u8, name, "td")) {
                    self.clearStackBackToTableRowContext();
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_cell;
                    try self.active_formatting_elements.append(.marker);
                } else if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    if (!self.hasElementInTableScope("tr")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableRowContext();
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else {
                    try self.handleInTableMode(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "tr")) {
                    if (!self.hasElementInTableScope("tr")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableRowContext();
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table_body;
                } else if (std.mem.eql(u8, name, "table")) {
                    if (!self.hasElementInTableScope("tr")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableRowContext();
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    if (!self.hasElementInTableScope(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    if (!self.hasElementInTableScope("tr")) {
                        return; // Ignore
                    }
                    self.clearStackBackToTableRowContext();
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else {
                    try self.handleInTableMode(token);
                }
            },
            else => {
                try self.handleInTableMode(token);
            },
        }
    }

    /// Handle token in "in cell" insertion mode.
    /// HTML Standard §13.2.6.4.15
    fn handleInCellMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "td") or std.mem.eql(u8, name, "th")) {
                    if (!self.hasElementInTableScope(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.generateImpliedEndTags(null);
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName(name)) {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                    self.popUntilTagName(name);
                    self.clearActiveFormattingToMarker();
                    self.insertion_mode = .in_row;
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else if (std.mem.eql(u8, name, "table") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    if (!self.hasElementInTableScope(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    try self.closeCell();
                    try self.processToken(token);
                } else {
                    try self.handleInBodyMode(token);
                }
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    // Assert: has td or th in table scope
                    try self.closeCell();
                    try self.processToken(token);
                } else {
                    try self.handleInBodyMode(token);
                }
            },
            else => {
                try self.handleInBodyMode(token);
            },
        }
    }

    /// Handle token in "in select" insertion mode.
    /// HTML Standard §13.2.6.4.16 (not in main parsing.md, simplified)
    fn handleInSelectMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (char == 0) {
                    self.reportError(.unexpected_null_character);
                } else {
                    try self.insertCharacter(char);
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "option")) {
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                        }
                    }
                    _ = try self.insertHtmlElement(tag);
                } else if (std.mem.eql(u8, name, "optgroup")) {
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                        }
                    }
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("optgroup")) {
                            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                        }
                    }
                    _ = try self.insertHtmlElement(tag);
                } else if (std.mem.eql(u8, name, "hr")) {
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                        }
                    }
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("optgroup")) {
                            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                        }
                    }
                    _ = try self.insertHtmlElement(tag);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                } else if (std.mem.eql(u8, name, "select")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (!self.hasElementInSelectScope("select")) {
                        return;
                    }
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                } else if (std.mem.eql(u8, name, "input") or
                    std.mem.eql(u8, name, "keygen") or
                    std.mem.eql(u8, name, "textarea"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (!self.hasElementInSelectScope("select")) {
                        return;
                    }
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "script") or std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "optgroup")) {
                    // Pop optgroup handling
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            if (self.open_elements.len > 1) {
                                const prev = self.open_elements.get(self.open_elements.len - 2);
                                if (prev) |p| {
                                    if (p.hasTagName("optgroup")) {
                                        _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                                    }
                                }
                            }
                        }
                    }
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("optgroup")) {
                            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                        } else {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                } else if (std.mem.eql(u8, name, "option")) {
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                        } else {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                } else if (std.mem.eql(u8, name, "select")) {
                    if (!self.hasElementInSelectScope("select")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleInBodyMode(token);
            },
        }
    }

    /// Handle token in "in select in table" insertion mode.
    fn handleInSelectInTableMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "table") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                    try self.processToken(token);
                } else {
                    try self.handleInSelectMode(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "table") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (!self.hasElementInTableScope(name)) {
                        return;
                    }
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                    try self.processToken(token);
                } else {
                    try self.handleInSelectMode(token);
                }
            },
            else => {
                try self.handleInSelectMode(token);
            },
        }
    }

    /// Handle token in "in template" insertion mode.
    /// HTML Standard §13.2.6.4.16
    fn handleInTemplateMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character, .comment, .doctype => {
                try self.handleInBodyMode(token);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "base") or
                    std.mem.eql(u8, name, "basefont") or
                    std.mem.eql(u8, name, "bgsound") or
                    std.mem.eql(u8, name, "link") or
                    std.mem.eql(u8, name, "meta") or
                    std.mem.eql(u8, name, "noframes") or
                    std.mem.eql(u8, name, "script") or
                    std.mem.eql(u8, name, "style") or
                    std.mem.eql(u8, name, "template") or
                    std.mem.eql(u8, name, "title"))
                {
                    try self.handleInHeadMode(token);
                } else if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
                    try self.template_insertion_modes.append(.in_table);
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "col")) {
                    _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
                    try self.template_insertion_modes.append(.in_column_group);
                    self.insertion_mode = .in_column_group;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "tr")) {
                    _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
                    try self.template_insertion_modes.append(.in_table_body);
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "td") or std.mem.eql(u8, name, "th")) {
                    _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
                    try self.template_insertion_modes.append(.in_row);
                    self.insertion_mode = .in_row;
                    try self.processToken(token);
                } else {
                    // Any other start tag
                    _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
                    try self.template_insertion_modes.append(.in_body);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .eof => {
                if (!self.hasTemplateInStack()) {
                    // Stop parsing
                    return;
                }
                self.reportError(.eof_in_tag);
                self.popUntilTagName("template");
                self.clearActiveFormattingToMarker();
                if (self.template_insertion_modes.len > 0) {
                    _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
                }
                self.resetInsertionModeAppropriately();
                try self.processToken(token);
            },
        }
    }

    fn handleAfterBodyMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .comment => |comment| {
                // Insert as last child of html element
                const html = self.open_elements.get(0);
                if (html) |h| {
                    const node = try TreeNode.initComment(self.allocator);
                    try node.appendText(comment.getData());
                    h.appendChild(node);
                }
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    self.insertion_mode = .after_after_body;
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .eof => {
                // Stop parsing
            },
        }
    }

    /// Handle token in "in frameset" insertion mode.
    /// HTML Standard §13.2.6.4.18
    fn handleInFramesetMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "frameset")) {
                    _ = try self.insertHtmlElement(tag);
                } else if (std.mem.eql(u8, name, "frame")) {
                    _ = try self.insertHtmlElement(tag);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                } else if (std.mem.eql(u8, name, "noframes")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "frameset")) {
                    // Check if root html element
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("html")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    // If not root and not frameset, switch mode
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("frameset")) {
                            self.insertion_mode = .after_frameset;
                        }
                    }
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .eof => {
                if (self.currentNode()) |current| {
                    if (!current.hasTagName("html")) {
                        self.reportError(.eof_in_tag);
                    }
                }
                // Stop parsing
            },
        }
    }

    /// Handle token in "after frameset" insertion mode.
    /// HTML Standard §13.2.6.4.19
    fn handleAfterFramesetMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "noframes")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    self.insertion_mode = .after_after_frameset;
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .eof => {
                // Stop parsing
            },
        }
    }

    fn handleAfterAfterBodyMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .comment => |comment| {
                const node = try TreeNode.initComment(self.allocator);
                try node.appendText(comment.getData());
                self.document.appendChild(node);
            },
            .doctype, .eof => {},
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .end_tag => {
                self.reportError(.invalid_first_character_of_tag_name);
                self.insertion_mode = .in_body;
                try self.processToken(token);
            },
        }
    }

    /// Handle token in "after after frameset" insertion mode.
    /// HTML Standard §13.2.6.4.21
    fn handleAfterAfterFramesetMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .comment => |comment| {
                const node = try TreeNode.initComment(self.allocator);
                try node.appendText(comment.getData());
                self.document.appendChild(node);
            },
            .doctype => {
                try self.handleInBodyMode(token);
            },
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "noframes")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .end_tag => {
                self.reportError(.invalid_first_character_of_tag_name);
                // Ignore
            },
            .eof => {
                // Stop parsing
            },
        }
    }

    // =========================================================================
    // Helper Functions
    // =========================================================================

    /// Create element for token.
    fn createElementForToken(self: *TreeBuilder, tag: TagToken, namespace: Namespace) !*TreeNode {
        const name = tag.getTagName();
        const element = try TreeNode.initElement(self.allocator, name, namespace);

        // Copy attributes
        const attrs = tag.attributes.toSlice();
        for (attrs) |attr| {
            try element.addAttribute(attr.getName(), attr.getValue(), null);
        }

        return element;
    }

    /// Insert HTML element for token.
    fn insertHtmlElement(self: *TreeBuilder, tag: TagToken) !*TreeNode {
        const element = try self.createElementForToken(tag, .html);
        self.insertAtAppropriatePlace(element);
        try self.open_elements.append(element);
        return element;
    }

    /// Insert at the appropriate place.
    fn insertAtAppropriatePlace(self: *TreeBuilder, node: *TreeNode) void {
        // For now, just append to current node
        if (self.currentNode()) |parent| {
            parent.appendChild(node);
        } else {
            self.document.appendChild(node);
        }
    }

    /// Insert a character.
    fn insertCharacter(self: *TreeBuilder, char: u21) !void {
        const parent = self.currentNode() orelse self.document;

        // Check if last child is a text node
        if (parent.last_child) |last| {
            if (last.node_type == .text) {
                try last.appendChar(char);
                return;
            }
        }

        // Create new text node
        const text = try TreeNode.initText(self.allocator);
        try text.appendChar(char);
        parent.appendChild(text);
    }

    /// Insert a comment.
    fn insertComment(self: *TreeBuilder, comment: CommentToken) !void {
        const node = try TreeNode.initComment(self.allocator);
        try node.appendText(comment.getData());
        if (self.currentNode()) |parent| {
            parent.appendChild(node);
        } else {
            self.document.appendChild(node);
        }
    }

    /// Generic raw text element parsing algorithm.
    fn parseGenericRawText(self: *TreeBuilder, tag: TagToken) !void {
        _ = try self.insertHtmlElement(tag);
        self.tokenizer.state = .rawtext;
        self.original_insertion_mode = self.insertion_mode;
        self.insertion_mode = .text;
    }

    /// Generic RCDATA element parsing algorithm.
    fn parseGenericRCDATA(self: *TreeBuilder, tag: TagToken) !void {
        _ = try self.insertHtmlElement(tag);
        self.tokenizer.state = .rcdata;
        self.original_insertion_mode = self.insertion_mode;
        self.insertion_mode = .text;
    }

    /// Generate implied end tags.
    fn generateImpliedEndTags(self: *TreeBuilder, exclude: ?[]const u8) void {
        const implied_tags = [_][]const u8{ "dd", "dt", "li", "optgroup", "option", "p", "rb", "rp", "rt", "rtc" };
        while (self.currentNode()) |current| {
            var should_pop = false;
            if (current.local_name) |name| {
                for (implied_tags) |implied| {
                    if (std.mem.eql(u8, name, implied)) {
                        if (exclude) |exc| {
                            if (!std.mem.eql(u8, name, exc)) {
                                should_pop = true;
                            }
                        } else {
                            should_pop = true;
                        }
                        break;
                    }
                }
            }
            if (should_pop) {
                _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
            } else {
                break;
            }
        }
    }

    /// Generate all implied end tags thoroughly.
    fn generateAllImpliedEndTagsThoroughly(self: *TreeBuilder) !void {
        const implied_tags = [_][]const u8{
            "caption", "colgroup", "dd",    "dt", "li",  "optgroup", "option",
            "p",       "rb",       "rp",    "rt", "rtc", "tbody",    "td",
            "tfoot",   "th",       "thead", "tr",
        };
        while (self.currentNode()) |current| {
            var should_pop = false;
            if (current.local_name) |name| {
                for (implied_tags) |implied| {
                    if (std.mem.eql(u8, name, implied)) {
                        should_pop = true;
                        break;
                    }
                }
            }
            if (should_pop) {
                _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
            } else {
                break;
            }
        }
    }

    /// Check if element is in scope.
    fn hasElementInScope(self: *TreeBuilder, tag_name: []const u8) bool {
        const scope_elements = [_][]const u8{
            "applet", "caption",  "html",    "table",
            "td",     "th",       "marquee", "object",
            "select", "template",
        };

        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node.hasTagName(tag_name)) return true;

            if (node.local_name) |name| {
                for (scope_elements) |scope_elem| {
                    if (std.mem.eql(u8, name, scope_elem)) {
                        return false;
                    }
                }
            }
        }
        return false;
    }

    /// Close p element if in button scope.
    fn closePElementIfInButtonScope(self: *TreeBuilder) !void {
        if (self.hasElementInButtonScope("p")) {
            self.generateImpliedEndTags("p");
            self.popUntilTagName("p");
        }
    }

    /// Check if element is in button scope.
    fn hasElementInButtonScope(self: *TreeBuilder, tag_name: []const u8) bool {
        const scope_elements = [_][]const u8{
            "applet", "caption", "html", "table", "td", "th", "marquee", "object", "select", "template", "button",
        };

        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node.hasTagName(tag_name)) return true;

            if (node.local_name) |name| {
                for (scope_elements) |scope_elem| {
                    if (std.mem.eql(u8, name, scope_elem)) {
                        return false;
                    }
                }
            }
        }
        return false;
    }

    /// Pop elements until tag name.
    fn popUntilTagName(self: *TreeBuilder, tag_name: []const u8) void {
        while (self.open_elements.len > 0) {
            const node = self.open_elements.remove(self.open_elements.len - 1) catch break;
            if (node.hasTagName(tag_name)) break;
        }
    }

    /// Push onto active formatting elements (Noah's Ark clause).
    fn pushOntoActiveFormattingElements(self: *TreeBuilder, element: *TreeNode, tag: TagToken) !void {
        // Count matching elements
        var count: usize = 0;
        var i = self.active_formatting_elements.len;
        while (i > 0) {
            i -= 1;
            const entry = self.active_formatting_elements.get(i) orelse continue;
            switch (entry) {
                .marker => break,
                .element => |elem| {
                    if (element.local_name != null and elem.node.local_name != null and
                        std.mem.eql(u8, element.local_name.?, elem.node.local_name.?))
                    {
                        count += 1;
                        if (count >= 3) {
                            // Remove earliest such element
                            _ = self.active_formatting_elements.remove(i) catch {};
                            break;
                        }
                    }
                },
            }
        }

        // Copy tag token
        var tag_copy = TagToken.init(self.allocator, false);
        const name = tag.getTagName();
        for (name) |c| {
            try tag_copy.appendToTagName(c);
        }

        try self.active_formatting_elements.append(.{ .element = .{
            .node = element,
            .token = tag_copy,
        } });
    }

    /// Clear active formatting elements to last marker.
    fn clearActiveFormattingToMarker(self: *TreeBuilder) void {
        while (self.active_formatting_elements.len > 0) {
            const entry = self.active_formatting_elements.remove(self.active_formatting_elements.len - 1) catch break;
            switch (entry) {
                .marker => break,
                .element => |elem| {
                    var e = elem;
                    e.token.deinit();
                },
            }
        }
    }

    /// Reconstruct active formatting elements.
    /// Reconstruct the active formatting elements.
    ///
    /// HTML Standard §13.2.4.3: When the steps below require the UA to
    /// reconstruct the active formatting elements, the UA must perform
    /// the following steps.
    fn reconstructActiveFormattingElements(self: *TreeBuilder) !void {
        // 1. If there are no entries in the list of active formatting elements,
        //    then there is nothing to reconstruct; stop this algorithm.
        if (self.active_formatting_elements.len == 0) return;

        // 2. If the last (most recently added) entry in the list of active
        //    formatting elements is a marker, or if it is an element that is
        //    in the stack of open elements, then there is nothing to reconstruct;
        //    stop this algorithm.
        const last_idx = self.active_formatting_elements.len - 1;
        const last = self.active_formatting_elements.get(last_idx) orelse return;
        switch (last) {
            .marker => return,
            .element => |elem| {
                // Check if element is in stack of open elements
                for (self.open_elements.toSlice()) |open| {
                    if (open == elem.node) return;
                }
            },
        }

        // 3. Let entry be the last (most recently added) element in the list
        //    of active formatting elements.
        var entry_idx: usize = last_idx;

        // 4. Rewind: If there are no entries before entry in the list of active
        //    formatting elements, then jump to the step labeled create.
        rewind: while (entry_idx > 0) {
            // 5. Let entry be the entry one earlier than entry in the list of
            //    active formatting elements.
            entry_idx -= 1;

            // 6. If entry is neither a marker nor an element that is also in
            //    the stack of open elements, go to the step labeled rewind.
            const entry = self.active_formatting_elements.get(entry_idx) orelse break :rewind;
            switch (entry) {
                .marker => break :rewind,
                .element => |elem| {
                    // Check if element is in stack of open elements
                    var in_stack = false;
                    for (self.open_elements.toSlice()) |open| {
                        if (open == elem.node) {
                            in_stack = true;
                            break;
                        }
                    }
                    if (in_stack) break :rewind;
                    // Otherwise continue rewinding
                },
            }
        }

        // 7. Advance: Let entry be the element one later than entry in the
        //    list of active formatting elements.
        // 8. Create: Insert an HTML element for the token for which the element
        //    entry was created, to obtain new element.
        // 9. Replace the entry for entry in the list with an entry for new element.
        // 10. If the entry for new element in the list of active formatting
        //     elements is not the last entry in the list, return to the step
        //     labeled advance.
        while (entry_idx < self.active_formatting_elements.len) {
            // Advance to next entry
            if (entry_idx < self.active_formatting_elements.len - 1) {
                entry_idx += 1;
            }

            const entry = self.active_formatting_elements.get(entry_idx) orelse break;
            switch (entry) {
                .marker => break,
                .element => |elem| {
                    // Create: Insert an HTML element for the token
                    const new_element = try self.createElementForToken(elem.token, .html);
                    self.insertAtAppropriatePlace(new_element);
                    try self.open_elements.append(new_element);

                    // Replace the entry in the list with the new element
                    // We need to update the node reference while keeping the same token
                    const updated_entry = FormattingEntry{
                        .element = .{
                            .node = new_element,
                            .token = elem.token,
                        },
                    };
                    // Replace entry at index
                    if (entry_idx < self.active_formatting_elements.len) {
                        const slice = self.active_formatting_elements.toSliceMut();
                        slice[entry_idx] = updated_entry;
                    }

                    // If this is the last entry, stop
                    if (entry_idx >= self.active_formatting_elements.len - 1) break;
                },
            }
        }
    }

    /// Adoption agency algorithm.
    ///
    /// HTML Standard §13.2.6.4.7: This complex algorithm handles mis-nested
    /// formatting elements like `<b><i></b></i>` by rearranging nodes.
    ///
    /// The algorithm has two main paths:
    /// 1. Simple case: No furthest block - just pop elements
    /// 2. Complex case: Rearrange nodes (the "adoption dance")
    fn adoptionAgencyAlgorithm(self: *TreeBuilder, tag_name: []const u8) !void {
        // Step 1: Outer loop counter
        var outer_loop_counter: usize = 0;

        // Step 2: Outer loop
        while (outer_loop_counter < 8) : (outer_loop_counter += 1) {
            // Step 3: Find formatting element - walk active formatting elements backwards
            var formatting_element: ?*TreeNode = null;
            var formatting_index: ?usize = null;

            var i = self.active_formatting_elements.len;
            while (i > 0) {
                i -= 1;
                const entry = self.active_formatting_elements.get(i) orelse continue;
                switch (entry) {
                    .marker => break, // Stop at marker
                    .element => |elem| {
                        if (elem.node.hasTagName(tag_name)) {
                            formatting_element = elem.node;
                            formatting_index = i;
                            break;
                        }
                    },
                }
            }

            // Step 4: If no formatting element found, process as "any other end tag"
            if (formatting_element == null) {
                try self.handleAnyOtherEndTag(tag_name);
                return;
            }

            // Step 5: Check if formatting element is in stack of open elements
            var stack_index: ?usize = null;
            const elements = self.open_elements.toSlice();
            for (elements, 0..) |elem, idx| {
                if (elem == formatting_element) {
                    stack_index = idx;
                    break;
                }
            }

            // Step 6: If formatting element not in stack, parse error & remove from list
            if (stack_index == null) {
                self.reportError(.invalid_first_character_of_tag_name);
                _ = self.active_formatting_elements.remove(formatting_index.?) catch {};
                return;
            }

            // Step 7: If formatting element not in scope, parse error & return
            if (!self.hasElementInScope(tag_name)) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }

            // Step 8: If formatting element is not current node, parse error
            if (formatting_element != self.currentNode()) {
                self.reportError(.invalid_first_character_of_tag_name);
            }

            // Step 9: Find furthest block - special element below formatting element
            var furthest_block: ?*TreeNode = null;
            var furthest_block_index: ?usize = null;

            const fe_stack_idx = stack_index.?;
            var fb_i = fe_stack_idx + 1;
            while (fb_i < self.open_elements.len) : (fb_i += 1) {
                const elem = self.open_elements.get(fb_i) orelse continue;
                if (self.isSpecialElement(elem)) {
                    furthest_block = elem;
                    furthest_block_index = fb_i;
                    break;
                }
            }

            // Step 10: If no furthest block, pop elements and remove from list (simple case)
            if (furthest_block == null) {
                // Pop until and including the formatting element
                while (self.open_elements.len > fe_stack_idx) {
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
                }
                _ = self.active_formatting_elements.remove(formatting_index.?) catch {};
                return;
            }

            // Steps 11-21: Complex case - perform the adoption dance
            // This handles mis-nested tags like <b><i></b></i>

            // Step 11: Let common ancestor be the element immediately above formatting element
            // (Used in full implementation for reparenting nodes)
            _ = if (fe_stack_idx > 0)
                self.open_elements.get(fe_stack_idx - 1)
            else
                null;

            // Step 12: Let bookmark be formatting element's position in active formatting list
            var bookmark = formatting_index.?;

            // Step 13: Let node and lastNode be furthest block
            var node_index = furthest_block_index.?;
            var last_node = furthest_block.?;

            // Step 14: Inner loop counter
            var inner_loop_counter: usize = 0;

            // Step 15: Inner loop
            while (inner_loop_counter < 3) : (inner_loop_counter += 1) {
                // Step 15.1: Decrement node index
                if (node_index == 0) break;
                node_index -= 1;

                // Step 15.2: Let node be element at node_index
                const node = self.open_elements.get(node_index) orelse break;

                // Step 15.3: If node is formatting element, break
                if (node == formatting_element) break;

                // Step 15.4: Check if node is in active formatting elements
                var node_in_list: ?usize = null;
                for (self.active_formatting_elements.toSlice(), 0..) |entry, idx| {
                    switch (entry) {
                        .element => |elem| {
                            if (elem.node == node) {
                                node_in_list = idx;
                                break;
                            }
                        },
                        .marker => {},
                    }
                }

                // Step 15.5: If node not in list, remove from stack and continue
                if (node_in_list == null) {
                    _ = self.open_elements.remove(node_index) catch {};
                    continue;
                }

                // Steps 15.6-15.7: Create replacement element and update references
                // For simplicity in this implementation, we update bookmark
                if (node_in_list.? < bookmark) {
                    bookmark = node_in_list.?;
                }

                // Step 15.8: If last node is furthest block, update bookmark
                if (last_node == furthest_block) {
                    bookmark = node_in_list.? + 1;
                    if (bookmark > self.active_formatting_elements.len) {
                        bookmark = self.active_formatting_elements.len;
                    }
                }

                // Step 15.9: Move last node into node (simplified - just update parent)
                // In full implementation, would detach and re-attach
                last_node = node;
            }

            // Steps 16-20: Insert last_node into common ancestor, create new element, etc.
            // For this simplified implementation, we do the minimum viable work:

            // Generate implied end tags excluding the formatting element
            self.generateImpliedEndTags(tag_name);

            // Pop until the formatting element (inclusive)
            while (self.open_elements.len > fe_stack_idx) {
                _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
            }

            // Remove from active formatting elements
            _ = self.active_formatting_elements.remove(formatting_index.?) catch {};

            return;
        }
    }

    /// Reset insertion mode appropriately.
    fn resetInsertionModeAppropriately(self: *TreeBuilder) void {
        var last = false;
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;

            if (i == 0) {
                last = true;
            }

            if (node.hasTagName("select")) {
                self.insertion_mode = .in_select;
                return;
            }
            if (node.hasTagName("td") or node.hasTagName("th")) {
                if (!last) {
                    self.insertion_mode = .in_cell;
                    return;
                }
            }
            if (node.hasTagName("tr")) {
                self.insertion_mode = .in_row;
                return;
            }
            if (node.hasTagName("tbody") or node.hasTagName("thead") or node.hasTagName("tfoot")) {
                self.insertion_mode = .in_table_body;
                return;
            }
            if (node.hasTagName("caption")) {
                self.insertion_mode = .in_caption;
                return;
            }
            if (node.hasTagName("colgroup")) {
                self.insertion_mode = .in_column_group;
                return;
            }
            if (node.hasTagName("table")) {
                self.insertion_mode = .in_table;
                return;
            }
            if (node.hasTagName("template")) {
                if (self.template_insertion_modes.len > 0) {
                    self.insertion_mode = self.template_insertion_modes.get(self.template_insertion_modes.len - 1) orelse .in_template;
                }
                return;
            }
            if (node.hasTagName("head") and !last) {
                self.insertion_mode = .in_head;
                return;
            }
            if (node.hasTagName("body")) {
                self.insertion_mode = .in_body;
                return;
            }
            if (node.hasTagName("frameset")) {
                self.insertion_mode = .in_frameset;
                return;
            }
            if (node.hasTagName("html")) {
                if (self.head_element == null) {
                    self.insertion_mode = .before_head;
                } else {
                    self.insertion_mode = .after_head;
                }
                return;
            }

            if (last) {
                self.insertion_mode = .in_body;
                return;
            }
        }
    }

    /// Check if element is special.
    fn isSpecialElement(self: *TreeBuilder, node: *TreeNode) bool {
        _ = self;
        if (node.local_name) |name| {
            return isSpecialBlockElement(name) or isVoidElement(name);
        }
        return false;
    }

    /// Clear the stack back to a table context.
    /// HTML Standard: Pop until table, template, or html.
    fn clearStackBackToTableContext(self: *TreeBuilder) void {
        while (self.open_elements.len > 0) {
            const node = self.currentNode() orelse break;
            if (node.hasTagName("table") or node.hasTagName("template") or node.hasTagName("html")) {
                break;
            }
            _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
        }
    }

    /// Clear the stack back to a table body context.
    /// HTML Standard: Pop until tbody, tfoot, thead, template, or html.
    fn clearStackBackToTableBodyContext(self: *TreeBuilder) void {
        while (self.open_elements.len > 0) {
            const node = self.currentNode() orelse break;
            if (node.hasTagName("tbody") or
                node.hasTagName("tfoot") or
                node.hasTagName("thead") or
                node.hasTagName("template") or
                node.hasTagName("html"))
            {
                break;
            }
            _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
        }
    }

    /// Clear the stack back to a table row context.
    /// HTML Standard: Pop until tr, template, or html.
    fn clearStackBackToTableRowContext(self: *TreeBuilder) void {
        while (self.open_elements.len > 0) {
            const node = self.currentNode() orelse break;
            if (node.hasTagName("tr") or node.hasTagName("template") or node.hasTagName("html")) {
                break;
            }
            _ = self.open_elements.remove(self.open_elements.len - 1) catch break;
        }
    }

    /// Check if element is in table scope.
    fn hasElementInTableScope(self: *TreeBuilder, tag_name: []const u8) bool {
        const scope_elements = [_][]const u8{ "html", "table", "template" };

        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node.hasTagName(tag_name)) return true;

            if (node.local_name) |name| {
                for (scope_elements) |scope_elem| {
                    if (std.mem.eql(u8, name, scope_elem)) {
                        return false;
                    }
                }
            }
        }
        return false;
    }

    /// Check if element is in select scope.
    fn hasElementInSelectScope(self: *TreeBuilder, tag_name: []const u8) bool {
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node.hasTagName(tag_name)) return true;

            // In select scope, only optgroup and option are transparent
            if (node.local_name) |name| {
                if (!std.mem.eql(u8, name, "optgroup") and !std.mem.eql(u8, name, "option")) {
                    return false;
                }
            }
        }
        return false;
    }

    /// Check if there is a tbody, thead, or tfoot in table scope.
    fn hasTableBodyElementInTableScope(self: *TreeBuilder) bool {
        return self.hasElementInTableScope("tbody") or
            self.hasElementInTableScope("thead") or
            self.hasElementInTableScope("tfoot");
    }

    /// Check if there's a template element in the stack.
    fn hasTemplateInStack(self: *TreeBuilder) bool {
        for (self.open_elements.toSlice()) |elem| {
            if (elem.hasTagName("template")) return true;
        }
        return false;
    }

    /// Check if a tag token has type="hidden" attribute.
    fn hasTypeHiddenAttribute(self: *TreeBuilder, tag: TagToken) bool {
        _ = self;
        const attrs = tag.attributes.toSlice();
        for (attrs) |attr| {
            if (std.ascii.eqlIgnoreCase(attr.getName(), "type")) {
                return std.ascii.eqlIgnoreCase(attr.getValue(), "hidden");
            }
        }
        return false;
    }

    /// Close the cell algorithm.
    fn closeCell(self: *TreeBuilder) !void {
        self.generateImpliedEndTags(null);
        if (self.currentNode()) |current| {
            if (!current.hasTagName("td") and !current.hasTagName("th")) {
                self.reportError(.invalid_first_character_of_tag_name);
            }
        }
        // Pop until td or th
        while (self.open_elements.len > 0) {
            const node = self.open_elements.remove(self.open_elements.len - 1) catch break;
            if (node.hasTagName("td") or node.hasTagName("th")) break;
        }
        self.clearActiveFormattingToMarker();
        self.insertion_mode = .in_row;
    }

    /// Copy attributes from a token to an element if they don't already exist.
    ///
    /// HTML Standard: For each attribute on the token, check if already present
    /// on the element. If not, add it.
    fn copyMissingAttributes(self: *TreeBuilder, element: *TreeNode, tag: TagToken) !void {
        _ = self; // Mark as used
        const token_attrs = tag.attributes.toSlice();
        for (token_attrs) |attr| {
            const attr_name = attr.getName();

            // Check if attribute already exists on element
            var exists = false;
            const elem_attrs = element.attributes.toSlice();
            for (elem_attrs) |existing| {
                if (std.mem.eql(u8, existing.name, attr_name)) {
                    exists = true;
                    break;
                }
            }

            // If not present, add it
            if (!exists) {
                try element.addAttribute(attr_name, attr.getValue(), null);
            }
        }
    }
};

// =========================================================================
// Helper Functions
// =========================================================================

/// Check if character is HTML whitespace.
fn isHtmlWhitespace(char: u21) bool {
    return char == 0x09 or char == 0x0A or char == 0x0C or char == 0x0D or char == 0x20;
}

/// Check if tag name is a special block element.
fn isSpecialBlockElement(name: []const u8) bool {
    const special = [_][]const u8{
        "address", "article", "aside",   "blockquote", "center",     "details", "dialog",
        "dir",     "div",     "dl",      "fieldset",   "figcaption", "figure",  "footer",
        "header",  "hgroup",  "main",    "menu",       "nav",        "ol",      "p",
        "search",  "section", "summary", "ul",         "h1",         "h2",      "h3",
        "h4",      "h5",      "h6",      "pre",        "listing",
    };
    for (special) |s| {
        if (std.mem.eql(u8, name, s)) return true;
    }
    return false;
}

/// Check if tag name is a formatting element.
fn isFormattingElement(name: []const u8) bool {
    const formatting = [_][]const u8{
        "a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u",
    };
    for (formatting) |f| {
        if (std.mem.eql(u8, name, f)) return true;
    }
    return false;
}

/// Check if tag name is a void element.
fn isVoidElement(name: []const u8) bool {
    const void_elements = [_][]const u8{
        "area",  "base", "br",   "col",   "embed",  "hr",    "img",
        "input", "link", "meta", "param", "source", "track", "wbr",
    };
    for (void_elements) |v| {
        if (std.mem.eql(u8, name, v)) return true;
    }
    return false;
}

/// Extract charset from Content-Type header value.
///
/// HTML Standard §4.2.5.4: Extracting character encoding from meta element.
/// Looks for "charset=" parameter in the content-type value.
fn extractCharsetFromContentType(content: []const u8) ?[]const u8 {
    // Simple implementation: look for "charset=" case-insensitively
    var i: usize = 0;
    while (i + 8 <= content.len) {
        if (std.ascii.eqlIgnoreCase(content[i .. i + 8], "charset=")) {
            var start = i + 8;
            // Skip optional quotes
            if (start < content.len and (content[start] == '"' or content[start] == '\'')) {
                const quote = content[start];
                start += 1;
                // Find closing quote
                var end = start;
                while (end < content.len and content[end] != quote) {
                    end += 1;
                }
                return content[start..end];
            } else {
                // Find end of value (semicolon or end of string)
                var end = start;
                while (end < content.len and content[end] != ';' and content[end] != ' ') {
                    end += 1;
                }
                return content[start..end];
            }
        }
        i += 1;
    }
    return null;
}

// =========================================================================
// Tests
// =========================================================================

test "TreeNode - create document" {
    const allocator = std.testing.allocator;
    const doc = try TreeNode.initDocument(allocator);
    defer doc.deinit();

    try std.testing.expectEqual(TreeNode.NodeType.document, doc.node_type);
    try std.testing.expectEqual(@as(?*TreeNode, null), doc.parent);
}

test "TreeNode - create element" {
    const allocator = std.testing.allocator;
    const elem = try TreeNode.initElement(allocator, "div", .html);
    defer elem.deinit();

    try std.testing.expectEqual(TreeNode.NodeType.element, elem.node_type);
    try std.testing.expectEqualStrings("div", elem.local_name.?);
    try std.testing.expectEqual(Namespace.html, elem.namespace);
}

test "TreeNode - append child" {
    const allocator = std.testing.allocator;
    const parent = try TreeNode.initElement(allocator, "div", .html);
    defer parent.deinit();

    const child = try TreeNode.initElement(allocator, "span", .html);
    // Don't defer child - parent owns it

    parent.appendChild(child);

    try std.testing.expectEqual(parent, child.parent);
    try std.testing.expectEqual(child, parent.first_child);
    try std.testing.expectEqual(child, parent.last_child);
}

test "TreeBuilder - init" {
    const allocator = std.testing.allocator;
    const input = "<!DOCTYPE html><html><head></head><body></body></html>";

    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    try std.testing.expectEqual(InsertionMode.initial, builder.insertion_mode);
    try std.testing.expectEqual(@as(?*TreeNode, null), builder.head_element);
}

test "InsertionMode - all modes defined" {
    // Verify all 24 insertion modes are defined
    const modes = [_]InsertionMode{
        .initial,
        .before_html,
        .before_head,
        .in_head,
        .in_head_noscript,
        .after_head,
        .in_body,
        .text,
        .in_table,
        .in_table_text,
        .in_caption,
        .in_column_group,
        .in_table_body,
        .in_row,
        .in_cell,
        .in_select,
        .in_select_in_table,
        .in_template,
        .after_body,
        .in_frameset,
        .after_frameset,
        .after_after_body,
        .after_after_frameset,
    };
    try std.testing.expectEqual(@as(usize, 23), modes.len);
}

test "isHtmlWhitespace" {
    try std.testing.expect(isHtmlWhitespace(0x09)); // tab
    try std.testing.expect(isHtmlWhitespace(0x0A)); // LF
    try std.testing.expect(isHtmlWhitespace(0x0C)); // FF
    try std.testing.expect(isHtmlWhitespace(0x0D)); // CR
    try std.testing.expect(isHtmlWhitespace(0x20)); // space
    try std.testing.expect(!isHtmlWhitespace('a'));
    try std.testing.expect(!isHtmlWhitespace('<'));
}

test "isSpecialBlockElement" {
    try std.testing.expect(isSpecialBlockElement("div"));
    try std.testing.expect(isSpecialBlockElement("p"));
    try std.testing.expect(isSpecialBlockElement("h1"));
    try std.testing.expect(!isSpecialBlockElement("span"));
    try std.testing.expect(!isSpecialBlockElement("a"));
}

test "isFormattingElement" {
    try std.testing.expect(isFormattingElement("b"));
    try std.testing.expect(isFormattingElement("i"));
    try std.testing.expect(isFormattingElement("a"));
    try std.testing.expect(!isFormattingElement("div"));
    try std.testing.expect(!isFormattingElement("p"));
}

test "isVoidElement" {
    try std.testing.expect(isVoidElement("br"));
    try std.testing.expect(isVoidElement("hr"));
    try std.testing.expect(isVoidElement("img"));
    try std.testing.expect(!isVoidElement("div"));
    try std.testing.expect(!isVoidElement("span"));
}

test "TreeBuilder - clearStackBackToTableContext" {
    const allocator = std.testing.allocator;
    const input = "<table><div><p>";

    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    // Manually set up the stack
    const html = try TreeNode.initElement(allocator, "html", .html);
    const table = try TreeNode.initElement(allocator, "table", .html);
    const div = try TreeNode.initElement(allocator, "div", .html);
    const p = try TreeNode.initElement(allocator, "p", .html);

    try builder.open_elements.append(html);
    try builder.open_elements.append(table);
    try builder.open_elements.append(div);
    try builder.open_elements.append(p);

    // Clear back to table context
    builder.clearStackBackToTableContext();

    // Should stop at table
    try std.testing.expectEqual(@as(usize, 2), builder.open_elements.len);
    const current = builder.currentNode().?;
    try std.testing.expectEqualStrings("table", current.local_name.?);
}

test "TreeBuilder - hasElementInTableScope" {
    const allocator = std.testing.allocator;
    const input = "<table>";

    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    // Manually set up the stack: html > table > tbody > tr > td
    const html = try TreeNode.initElement(allocator, "html", .html);
    const table = try TreeNode.initElement(allocator, "table", .html);
    const tbody = try TreeNode.initElement(allocator, "tbody", .html);
    const tr = try TreeNode.initElement(allocator, "tr", .html);
    const td = try TreeNode.initElement(allocator, "td", .html);

    try builder.open_elements.append(html);
    try builder.open_elements.append(table);
    try builder.open_elements.append(tbody);
    try builder.open_elements.append(tr);
    try builder.open_elements.append(td);

    // td is in table scope
    try std.testing.expect(builder.hasElementInTableScope("td"));
    // tr is in table scope
    try std.testing.expect(builder.hasElementInTableScope("tr"));
    // table is in table scope
    try std.testing.expect(builder.hasElementInTableScope("table"));
    // div is NOT in scope (not present)
    try std.testing.expect(!builder.hasElementInTableScope("div"));
}

test "TreeBuilder - hasTableBodyElementInTableScope" {
    const allocator = std.testing.allocator;
    const input = "<table>";

    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    // Stack without tbody
    const html = try TreeNode.initElement(allocator, "html", .html);
    const table = try TreeNode.initElement(allocator, "table", .html);

    try builder.open_elements.append(html);
    try builder.open_elements.append(table);

    // No tbody/thead/tfoot in scope
    try std.testing.expect(!builder.hasTableBodyElementInTableScope());

    // Add tbody
    const tbody = try TreeNode.initElement(allocator, "tbody", .html);
    try builder.open_elements.append(tbody);

    // Now has tbody in scope
    try std.testing.expect(builder.hasTableBodyElementInTableScope());
}
